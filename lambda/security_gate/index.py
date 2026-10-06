import json
import logging
import os
import time
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ecr_client = boto3.client("ecr")
codepipeline_client = boto3.client("codepipeline")

DEV_PIPELINE_NAME = os.environ.get("DEV_PIPELINE_NAME", "nt548-dev-pipeline")
STAGE_NAME = os.environ.get("APPROVAL_STAGE_NAME", "SecurityGate")
ACTION_NAME = os.environ.get("APPROVAL_ACTION_NAME", "SecurityGateApproval")
MAX_ALLOWED_CRITICAL = int(os.environ.get("MAX_ALLOWED_CRITICAL", "0"))
MAX_ALLOWED_HIGH = int(os.environ.get("MAX_ALLOWED_HIGH", "0"))
DEV_REPOSITORIES = (
    "nt548-dev-user",
    "nt548-dev-product",
    "nt548-dev-order",
    "nt548-dev-frontend",
)


def lambda_handler(event, context):
    """EventBridge handler for ECR image scan completion event on DEV repositories.

    Evaluates vulnerability thresholds for all services that were built with the
    target image tag (supports selective change detection) and automatically
    approves or rejects the DEV pipeline's manual approval action.
    """
    logger.info("Received event: %s", json.dumps(event))

    detail = event.get("detail", {})
    repo_name = detail.get("repository-name", "")
    image_tags = detail.get("image-tags", [])

    if repo_name and not repo_name.startswith("nt548-dev-"):
        logger.info("Ignoring repository %s (not an nt548-dev repository)", repo_name)
        return {"status": "SKIPPED", "reason": "Not a DEV repository"}

    if not image_tags:
        logger.warning("Ignoring scan event without an immutable image tag")
        return {"status": "SKIPPED", "reason": "No image tag"}

    image_tag = image_tags[0]
    results = {}
    pending = []

    # Polling loop: evaluate only repositories where image_tag actually exists
    # (services that were changed and built for this commit).
    for attempt in range(8):
        pending = []
        results = {}

        for dev_repo in DEV_REPOSITORIES:
            try:
                response = ecr_client.describe_image_scan_findings(
                    repositoryName=dev_repo,
                    imageId={"imageTag": image_tag},
                    maxResults=100,
                )
                status = response.get("imageScanStatus", {}).get("status")
                if status != "COMPLETE":
                    pending.append(dev_repo)
                    continue

                counts = response.get("imageScanFindings", {}).get(
                    "findingSeverityCounts", {}
                )
                results[dev_repo] = {
                    "CRITICAL": int(counts.get("CRITICAL", 0)),
                    "HIGH": int(counts.get("HIGH", 0)),
                    "MEDIUM": int(counts.get("MEDIUM", 0)),
                    "LOW": int(counts.get("LOW", 0)),
                }
            except ecr_client.exceptions.ImageNotFoundException:
                # Service was unchanged and not built in this run
                logger.info("Tag %s not found in %s (unchanged component)", image_tag, dev_repo)
                continue
            except ecr_client.exceptions.ScanNotFoundException:
                # Tag exists but scan not yet indexed
                pending.append(dev_repo)
            except Exception as e:
                logger.warning("Error checking scan for %s: %s", dev_repo, e)

        if not pending and results:
            break

        logger.info(
            "Waiting for tag %s scans in %s (attempt %d/8)",
            image_tag,
            pending or "<discovering>",
            attempt + 1,
        )
        time.sleep(3)

    if pending or not results:
        logger.info("Still pending scans or no repositories discovered with tag %s", image_tag)
        return {
            "status": "WAITING",
            "image_tag": image_tag,
            "pending_repositories": pending,
            "evaluated_repositories": list(results.keys()),
        }

    # Evaluate pass/fail for all repositories that were built
    passed = all(
        counts["CRITICAL"] <= MAX_ALLOWED_CRITICAL
        and counts["HIGH"] <= MAX_ALLOWED_HIGH
        for counts in results.values()
    )
    approval_status = "Approved" if passed else "Rejected"
    repository_summary = "; ".join(
        f"{name}: C={counts['CRITICAL']}, H={counts['HIGH']}"
        for name, counts in results.items()
    )
    summary = (
        f"Automated Security Gate {approval_status} for tag {image_tag}. "
        f"Evaluated components: {repository_summary}"
    )
    logger.info("Security Gate Evaluation: %s", summary)

    # Poll for active approval token in CodePipeline
    token = None
    for attempt in range(12):
        try:
            pipeline_state = codepipeline_client.get_pipeline_state(name=DEV_PIPELINE_NAME)
            for stage in pipeline_state.get("stageStates", []):
                if stage.get("stageName") == STAGE_NAME:
                    for action in stage.get("actionStates", []):
                        if action.get("actionName") == ACTION_NAME:
                            latest_execution = action.get("latestExecution", {})
                            token = latest_execution.get("token")
                            if token:
                                break
        except Exception as e:
            logger.error("Error querying pipeline state: %s", e)

        if token:
            logger.info("Found pending approval token on attempt %d: %s", attempt + 1, token)
            break

        logger.info(
            "Waiting for pipeline %s to enter %s stage (attempt %d/12)...",
            DEV_PIPELINE_NAME,
            STAGE_NAME,
            attempt + 1,
        )
        time.sleep(3)

    if not token:
        logger.warning(
            "No pending approval token found for %s in stage %s / action %s after polling",
            DEV_PIPELINE_NAME,
            STAGE_NAME,
            ACTION_NAME,
        )
        return {
            "status": "NO_TOKEN",
            "evaluation": approval_status,
            "summary": summary,
        }

    logger.info("Submitting PutApprovalResult '%s' to pipeline %s", approval_status, DEV_PIPELINE_NAME)
    try:
        codepipeline_client.put_approval_result(
            pipelineName=DEV_PIPELINE_NAME,
            stageName=STAGE_NAME,
            actionName=ACTION_NAME,
            result={"summary": summary, "status": approval_status},
            token=token,
        )
        logger.info("Successfully submitted approval result: %s", approval_status)
    except Exception as e:
        logger.error("Failed to put approval result: %s", e)
        return {"status": "ERROR", "message": str(e)}

    return {
        "status": "SUCCESS",
        "approval": approval_status,
        "summary": summary,
    }
