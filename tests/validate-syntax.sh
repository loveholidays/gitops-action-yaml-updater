#!/bin/bash

# Simple validation script that checks bash syntax without requiring dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENTRYPOINT="${SCRIPT_DIR}/../entrypoint.sh"

echo "Validating bash syntax..."

# Check if entrypoint.sh exists
if [[ ! -f "${ENTRYPOINT}" ]]; then
  echo "❌ FAILED: entrypoint.sh not found at ${ENTRYPOINT}"
  exit 1
fi

# Validate bash syntax
bash -n "${ENTRYPOINT}" || {
  echo "❌ FAILED: Syntax error in entrypoint.sh"
  exit 1
}

echo "✅ PASSED: entrypoint.sh syntax is valid"

# Check for common issues
echo ""
echo "Checking for common issues..."

# Check if HELM_VALUES mode has proper container name handling
if grep -A 20 'MODE.*HELM_VALUES' "${ENTRYPOINT}" | grep -q 'defaultContainerName'; then
  echo "✅ PASSED: HELM_VALUES mode includes container name checking"
else
  echo "❌ WARNING: HELM_VALUES mode might not handle multiple containers correctly"
fi

# Check if targetImageKey is set for HELM_VALUES
if grep -A 20 'MODE.*HELM_VALUES' "${ENTRYPOINT}" | grep -q 'targetImageKey'; then
  echo "✅ PASSED: HELM_VALUES mode uses dynamic targetImageKey"
else
  echo "❌ WARNING: HELM_VALUES mode might use hardcoded image key"
fi

echo ""
echo "Basic validation complete!"
echo ""
echo "Note: For full integration tests, run run-tests.sh with dependencies installed"
echo "or use Docker: docker run --rm -v \$(pwd)/tests:/tests <image> bash /tests/run-tests.sh"
