# Tests for gitops-action-yaml-updater

This directory contains automated tests for the gitops-action-yaml-updater action.

## Prerequisites

The tests require the following tools to be installed:
- `bash` (version 4.0 or higher)
- `yq` (mikefarah/yq version 2.x or 3.x) - Used for IMAGE_TAG mode operations
- `yq4` (mikefarah/yq version 4.x) - Used for HELM_VALUES mode operations
- `grep`
- `sed`
- `kustomize` (for Kustomization tests)

**Important:** The script requires [mikefarah/yq](https://github.com/mikefarah/yq), not the python-yq or jq-wrapper versions. Check with `yq --version` - it should show "mikefarah/yq".

### Installing Dependencies

**Note:** Due to the specific dependency requirements, running tests in Docker is strongly recommended.

**Using Docker (Recommended):**
```bash
# Build the Docker image (includes all dependencies)
docker buildx build --platform linux/arm64 --load -t gitops-updater .

# Run tests inside the container
docker run --rm --platform linux/arm64 --entrypoint /bin/bash \
  -v "$PWD:/workspace:ro" gitops-updater /workspace/tests/run-tests.sh
```

**Local installation (Advanced):**
Only if you need to run tests locally outside Docker:
```bash
# Install mikefarah/yq v3 as 'yq'
wget https://github.com/mikefarah/yq/releases/download/3.4.1/yq_linux_amd64
chmod +x yq_linux_amd64
sudo mv yq_linux_amd64 /usr/local/bin/yq

# Install mikefarah/yq v4 as 'yq4'
wget https://github.com/mikefarah/yq/releases/download/v4.35.1/yq_linux_amd64
chmod +x yq_linux_amd64
sudo mv yq_linux_amd64 /usr/local/bin/yq4

# Install kustomize
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/
```

## Running the Tests

**Locally (requires dependencies installed):**
```bash
cd tests
./run-tests.sh
```

**Using Docker (recommended):**
```bash
docker build -t gitops-updater .
docker run --rm --entrypoint /bin/bash -v "$PWD:/workspace:ro" \
  gitops-updater /workspace/tests/run-tests.sh
```

Run these commands from the repository root. Repeat the Buildx example with
`linux/amd64` to check the other platform. CI runs both platforms, including
tool execution, all update modes, preservation of unrelated fields, and
Kustomization image updates. Tests write only temporary fixture copies.

## Test Coverage

The test suite covers the following scenarios:

### IMAGE_TAG Mode
- Single container Deployment
- Multi-container Deployment (first container)
- Multi-container Deployment (second container)
- CronJob
- StatefulSet

### ENV_VAR Mode
- Updating environment variables in StatefulSet

### HELM_VALUES Mode
- Single container (default container)
- Multi-container (default container)
- **Multi-container (additional container)** - This tests the fix for the bug where additional containers weren't being updated correctly

## Test Fixtures

Test fixtures are located in `tests/fixtures/` and include:
- `deployment-single-container.yaml` - Simple deployment with one container
- `deployment-multi-container.yaml` - Deployment with multiple containers
- `helm-values-single-container.yaml` - Helm values with default container only
- `helm-values-multi-container.yaml` - Helm values with default + additional containers
- `cronjob.yaml` - CronJob resource
- `statefulset.yaml` - StatefulSet with environment variables

## Adding New Tests

To add a new test:

1. Create a fixture file in `tests/fixtures/` if needed
2. Add a new `run_test` call in `run-tests.sh` with:
   - Test name
   - Mode (IMAGE_TAG, ENV_VAR, or HELM_VALUES)
   - Container name
   - Fixture file path
   - New value to set
   - Expected pattern to verify
   - (Optional) Environment variable name for ENV_VAR mode

Example:
```bash
run_test \
  "Your test description" \
  "HELM_VALUES" \
  "container-name" \
  "${FIXTURES_DIR}/your-fixture.yaml" \
  "v1.2.3" \
  "tag: v1.2.3"
```
