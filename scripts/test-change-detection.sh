#!/bin/bash
# ==============================================================================
# test-change-detection.sh — Verification test suite for Scenarios A to F
# ==============================================================================
set -euo pipefail

echo "=================================================="
echo "🧪 RUNNING CHANGE DETECTION SIMULATION TEST SUITE"
echo "=================================================="

simulate_app_detection() {
    local scenario="$1"
    local files="$2"
    
    local FRONTEND_CHANGED=false
    local USER_CHANGED=false
    local PRODUCT_CHANGED=false
    local ORDER_CHANGED=false
    local DATABASE_CHANGED=false
    local SHARED_CHANGED=false
    local DOCS_ONLY=true

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        case "$file" in
            frontend/*) FRONTEND_CHANGED=true; DOCS_ONLY=false ;;
            be-user-service/*) USER_CHANGED=true; DOCS_ONLY=false ;;
            be-product-service/*) PRODUCT_CHANGED=true; DOCS_ONLY=false ;;
            be-order-service/*) ORDER_CHANGED=true; DOCS_ONLY=false ;;
            database/*) DATABASE_CHANGED=true; DOCS_ONLY=false ;;
            buildspec/*|scripts/*|docker-compose.yml|.env.example) SHARED_CHANGED=true; DOCS_ONLY=false ;;
            README.md|*.md|docs/*) ;;
            *) SHARED_CHANGED=true; DOCS_ONLY=false ;;
        esac
    done <<< "$files"

    if [ "$SHARED_CHANGED" = "true" ]; then
        FRONTEND_CHANGED=true
        USER_CHANGED=true
        PRODUCT_CHANGED=true
        ORDER_CHANGED=true
        DATABASE_CHANGED=true
    fi

    echo "--- Scenario $scenario ---"
    echo "Files: $files"
    echo "Actual: frontend=$FRONTEND_CHANGED user=$USER_CHANGED product=$PRODUCT_CHANGED order=$ORDER_CHANGED database=$DATABASE_CHANGED docsOnly=$DOCS_ONLY"
}

simulate_infra_detection() {
    local scenario="$1"
    local files="$2"

    local INFRA_CHANGED=false
    local PROD_CHANGED=false
    local DEV_CHANGED=false
    local SHARED_CHANGED=false
    local MODULES_CHANGED=false
    local LAMBDA_CHANGED=false
    local DOCS_ONLY=true

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        case "$file" in
            README.md|*.md|docs/*) ;;
            terraform/environments/prod/*) PROD_CHANGED=true; INFRA_CHANGED=true; DOCS_ONLY=false ;;
            terraform/environments/dev/*) DEV_CHANGED=true; INFRA_CHANGED=true; DOCS_ONLY=false ;;
            terraform/environments/shared/*) SHARED_CHANGED=true; PROD_CHANGED=true; DEV_CHANGED=true; INFRA_CHANGED=true; DOCS_ONLY=false ;;
            terraform/modules/*) MODULES_CHANGED=true; PROD_CHANGED=true; DEV_CHANGED=true; INFRA_CHANGED=true; DOCS_ONLY=false ;;
            lambda/security_gate/*) LAMBDA_CHANGED=true; DEV_CHANGED=true; INFRA_CHANGED=true; DOCS_ONLY=false ;;
            .checkov.yml|buildspec/*|scripts/*) PROD_CHANGED=true; DEV_CHANGED=true; INFRA_CHANGED=true; DOCS_ONLY=false ;;
            *) INFRA_CHANGED=true; PROD_CHANGED=true; DEV_CHANGED=true; DOCS_ONLY=false ;;
        esac
    done <<< "$files"

    echo "--- Scenario $scenario ---"
    echo "Files: $files"
    echo "Actual: infraChanged=$INFRA_CHANGED prodChanged=$PROD_CHANGED devChanged=$DEV_CHANGED modulesChanged=$MODULES_CHANGED docsOnly=$DOCS_ONLY"
}

echo "Testing Scenario A: be-product-service/app.py"
simulate_app_detection "A" "be-product-service/app.py"

echo "Testing Scenario B: frontend/src/app.js"
simulate_app_detection "B" "frontend/src/app.js"

echo "Testing Scenario C: README.md"
simulate_app_detection "C (App)" "README.md"
simulate_infra_detection "C (Infra)" "README.md"

echo "Testing Scenario D: terraform/modules/alb/main.tf"
simulate_infra_detection "D" "terraform/modules/alb/main.tf"

echo "Testing Scenario E: terraform/environments/prod/main.tf"
simulate_infra_detection "E" "terraform/environments/prod/main.tf"

echo "Testing Scenario F: shared CI/CD script"
simulate_app_detection "F (App)" "scripts/test-service.sh"
simulate_infra_detection "F (Infra)" "scripts/detect-infra-changes.sh"

echo "=================================================="
echo "🎉 ALL SIMULATIONS COMPLETED"
echo "=================================================="
