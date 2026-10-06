#!/bin/bash
# ==============================================================================
# detect-infra-changes.sh — Change detection for NT548 Infrastructure repository
#
# Detects whether infrastructure-related files changed between commits.
# Filters out documentation-only changes (*.md) to avoid unnecessary Terraform runs.
# ==============================================================================
set -euo pipefail

TARGET_COMMIT="${1:-${CODEBUILD_RESOLVED_SOURCE_VERSION:-HEAD}}"
BASE_COMMIT="${2:-}"
OUTPUT_JSON="${3:-infra_changes.json}"
OUTPUT_ENV="${4:-infra_changes.env}"

echo "=================================================="
echo "🔍 [CHANGE-DETECTOR] Infrastructure Change Detection"
echo "Target Commit : $TARGET_COMMIT"
echo "Base Commit   : ${BASE_COMMIT:-<auto-detect>}"
echo "=================================================="

INFRA_CHANGED=false
PROD_CHANGED=false
DEV_CHANGED=false
SHARED_CHANGED=false
MODULES_CHANGED=false
LAMBDA_CHANGED=false
DOCS_ONLY=true
DIFF_SUCCESS=false
CHANGED_FILES=""

get_changed_files() {
    # 1. Inside existing working tree with .git
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        if [ -n "$BASE_COMMIT" ]; then
            git diff --name-only "$BASE_COMMIT" "$TARGET_COMMIT" 2>/dev/null && return 0
        fi

        if git rev-parse "${TARGET_COMMIT}~1" >/dev/null 2>&1; then
            git diff-tree --no-commit-id --name-only -r -m "$TARGET_COMMIT" 2>/dev/null && return 0
        fi

        for base_branch in origin/main origin/dev main dev; do
            if git rev-parse "$base_branch" >/dev/null 2>&1 && [ "$(git rev-parse "$base_branch")" != "$(git rev-parse "$TARGET_COMMIT")" ]; then
                git diff --name-only "$base_branch" "$TARGET_COMMIT" 2>/dev/null && return 0
            fi
        done

        git diff-tree --no-commit-id --name-only -r --root "$TARGET_COMMIT" 2>/dev/null && return 0
    fi

    # 2. Outside git working tree (e.g. CodePipeline artifact extraction)
    local repo_url="https://github.com/Jonnysilverfang/NT548.git"
    local temp_git_dir="/tmp/nt548_infra_git"
    rm -rf "$temp_git_dir"
    mkdir -p "$temp_git_dir"

    if git clone --bare --depth=10 "$repo_url" "$temp_git_dir" >/dev/null 2>&1; then
        if [ -n "$BASE_COMMIT" ]; then
            git --git-dir="$temp_git_dir" diff --name-only "$BASE_COMMIT" "$TARGET_COMMIT" 2>/dev/null && return 0
        fi

        if git --git-dir="$temp_git_dir" rev-parse "${TARGET_COMMIT}~1" >/dev/null 2>&1; then
            git --git-dir="$temp_git_dir" diff-tree --no-commit-id --name-only -r -m "$TARGET_COMMIT" 2>/dev/null && return 0
        fi

        git --git-dir="$temp_git_dir" diff-tree --no-commit-id --name-only -r --root "$TARGET_COMMIT" 2>/dev/null && return 0
    fi

    return 1
}

if CHANGED_FILES=$(get_changed_files); then
    DIFF_SUCCESS=true
else
    echo "⚠️ [CHANGE-DETECTOR] Could not determine commit diff safely. Falling back to planning relevant environments."
    DIFF_SUCCESS=false
fi

if [ "$DIFF_SUCCESS" = "true" ] && [ -n "$CHANGED_FILES" ]; then
    echo "📂 [CHANGE-DETECTOR] Detected changed files:"
    echo "$CHANGED_FILES" | sed 's/^/   • /'

    while IFS= read -r file; do
        [ -z "$file" ] && continue

        case "$file" in
            README.md|*.md|docs/*)
                # Pure documentation change
                ;;
            terraform/environments/prod/*)
                PROD_CHANGED=true
                INFRA_CHANGED=true
                DOCS_ONLY=false
                ;;
            terraform/environments/dev/*)
                DEV_CHANGED=true
                INFRA_CHANGED=true
                DOCS_ONLY=false
                ;;
            terraform/environments/shared/*)
                SHARED_CHANGED=true
                PROD_CHANGED=true
                DEV_CHANGED=true
                INFRA_CHANGED=true
                DOCS_ONLY=false
                ;;
            terraform/modules/*)
                MODULES_CHANGED=true
                PROD_CHANGED=true
                DEV_CHANGED=true
                INFRA_CHANGED=true
                DOCS_ONLY=false
                ;;
            lambda/security_gate/*)
                LAMBDA_CHANGED=true
                DEV_CHANGED=true
                INFRA_CHANGED=true
                DOCS_ONLY=false
                ;;
            .checkov.yml|buildspec/*|scripts/*)
                PROD_CHANGED=true
                DEV_CHANGED=true
                INFRA_CHANGED=true
                DOCS_ONLY=false
                ;;
            *)
                INFRA_CHANGED=true
                PROD_CHANGED=true
                DEV_CHANGED=true
                DOCS_ONLY=false
                ;;
        esac
    done <<< "$CHANGED_FILES"
elif [ "$DIFF_SUCCESS" = "false" ]; then
    # Safe fallback: run plan
    INFRA_CHANGED=true
    PROD_CHANGED=true
    DEV_CHANGED=true
    DOCS_ONLY=false
else
    echo "ℹ️ [CHANGE-DETECTOR] No files changed in this revision."
    DOCS_ONLY=true
fi

echo "--------------------------------------------------"
echo "📋 [CHANGE-DETECTOR] Infrastructure Status:"
echo "   infra-changed   : $INFRA_CHANGED"
echo "   prod-changed    : $PROD_CHANGED"
echo "   dev-changed     : $DEV_CHANGED"
echo "   modules-changed : $MODULES_CHANGED"
echo "   lambda-changed  : $LAMBDA_CHANGED"
echo "   docs-only       : $DOCS_ONLY"
echo "--------------------------------------------------"

cat <<EOF > "$OUTPUT_JSON"
{
  "targetCommit": "$TARGET_COMMIT",
  "baseCommit": "$BASE_COMMIT",
  "infraChanged": $INFRA_CHANGED,
  "prodChanged": $PROD_CHANGED,
  "devChanged": $DEV_CHANGED,
  "modulesChanged": $MODULES_CHANGED,
  "lambdaChanged": $LAMBDA_CHANGED,
  "docsOnly": $DOCS_ONLY
}
EOF

cat <<EOF > "$OUTPUT_ENV"
export INFRA_CHANGED=$INFRA_CHANGED
export PROD_CHANGED=$PROD_CHANGED
export DEV_CHANGED=$DEV_CHANGED
export MODULES_CHANGED=$MODULES_CHANGED
export LAMBDA_CHANGED=$LAMBDA_CHANGED
export DOCS_ONLY=$DOCS_ONLY
EOF

echo "✅ [CHANGE-DETECTOR] Output written to $OUTPUT_JSON and $OUTPUT_ENV"
