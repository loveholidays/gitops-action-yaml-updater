#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
ENTRYPOINT="${SCRIPT_DIR}/../entrypoint.sh"
TEMP_DIR=$(mktemp -d)

echo "========================================="
echo "Running gitops-action-yaml-updater tests"
echo "========================================="
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
  local test_name="$1"
  local mode="$2"
  local container_name="$3"
  local fixture_file="$4"
  local new_value="$5"
  local expected_pattern="$6"
  local env_name="${7:-}"

  echo "Running test: ${test_name}"

  # Copy fixture to temp directory
  local temp_file="${TEMP_DIR}/$(basename ${fixture_file})"
  cp "${fixture_file}" "${temp_file}"

  # Run the updater
  if [[ -n "${env_name}" ]]; then
    bash "${ENTRYPOINT}" "${mode}" "${container_name}" "${temp_file}" "" "${env_name}" "${new_value}" > /dev/null 2>&1 || {
      echo "  ❌ FAILED: Script execution failed"
      ((TESTS_FAILED++))
      return 1
    }
  else
    bash "${ENTRYPOINT}" "${mode}" "${container_name}" "${temp_file}" "${new_value}" "" "" > /dev/null 2>&1 || {
      echo "  ❌ FAILED: Script execution failed"
      ((TESTS_FAILED++))
      return 1
    }
  fi

  # Verify the result
  if grep -q "${expected_pattern}" "${temp_file}"; then
    echo "  ✅ PASSED"
    ((TESTS_PASSED++))
  else
    echo "  ❌ FAILED: Expected pattern '${expected_pattern}' not found"
    echo "  File contents:"
    cat "${temp_file}"
    ((TESTS_FAILED++))
    return 1
  fi
}

# Test 1: IMAGE_TAG mode - Deployment with single container
run_test \
  "IMAGE_TAG: Update Deployment single container" \
  "IMAGE_TAG" \
  "test-app" \
  "${FIXTURES_DIR}/deployment-single-container.yaml" \
  "v2.0.0" \
  "image: eu.gcr.io/test/test-app:v2.0.0"

# Test 2: IMAGE_TAG mode - Deployment with multiple containers (first container)
run_test \
  "IMAGE_TAG: Update Deployment multi-container (api)" \
  "IMAGE_TAG" \
  "api" \
  "${FIXTURES_DIR}/deployment-multi-container.yaml" \
  "v2.0.0" \
  "image: eu.gcr.io/test/api:v2.0.0"

# Test 3: IMAGE_TAG mode - Deployment with multiple containers (second container)
run_test \
  "IMAGE_TAG: Update Deployment multi-container (ui)" \
  "IMAGE_TAG" \
  "ui" \
  "${FIXTURES_DIR}/deployment-multi-container.yaml" \
  "v3.0.0" \
  "image: eu.gcr.io/test/ui:v3.0.0"

# Test 4: IMAGE_TAG mode - CronJob
run_test \
  "IMAGE_TAG: Update CronJob" \
  "IMAGE_TAG" \
  "test-cronjob" \
  "${FIXTURES_DIR}/cronjob.yaml" \
  "v2.0.0" \
  "image: eu.gcr.io/test/cronjob:v2.0.0"

# Test 5: IMAGE_TAG mode - StatefulSet
run_test \
  "IMAGE_TAG: Update StatefulSet" \
  "IMAGE_TAG" \
  "test-app" \
  "${FIXTURES_DIR}/statefulset.yaml" \
  "v2.0.0" \
  "image: eu.gcr.io/test/test-app:v2.0.0"

# Test 6: ENV_VAR mode - StatefulSet
run_test \
  "ENV_VAR: Update environment variable" \
  "ENV_VAR" \
  "test-app" \
  "${FIXTURES_DIR}/statefulset.yaml" \
  "staging" \
  "value: staging" \
  "ENVIRONMENT"

# Test 7: HELM_VALUES mode - Single container (default)
run_test \
  "HELM_VALUES: Update default container" \
  "HELM_VALUES" \
  "test-app" \
  "${FIXTURES_DIR}/helm-values-single-container.yaml" \
  "v2.0.0" \
  "tag: v2.0.0"

# Test 8: HELM_VALUES mode - Multi-container (default container)
run_test \
  "HELM_VALUES: Update multi-container default (api)" \
  "HELM_VALUES" \
  "api" \
  "${FIXTURES_DIR}/helm-values-multi-container.yaml" \
  "v2.0.0" \
  "tag: v2.0.0"

# Test 9: HELM_VALUES mode - Multi-container (additional container) - THE BUG FIX TEST
run_test \
  "HELM_VALUES: Update multi-container additional (ui)" \
  "HELM_VALUES" \
  "ui" \
  "${FIXTURES_DIR}/helm-values-multi-container.yaml" \
  "v3.0.0" \
  "tag: v3.0.0"

echo ""
echo "========================================="
echo "Test Results"
echo "========================================="
echo "Passed: ${TESTS_PASSED}"
echo "Failed: ${TESTS_FAILED}"
echo ""

# Cleanup
rm -rf "${TEMP_DIR}"

if [[ ${TESTS_FAILED} -gt 0 ]]; then
  exit 1
fi

echo "All tests passed! ✅"
