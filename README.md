# Update yaml's file docker action
#### gitops-action-yaml-updater

This action updates in place yaml files using yq for correct identification of resources under container
If the yaml file is a kustomize partial file, make sure that the value to be updated is part of the file mentioned in the filepath.

This also supports kustomize images: newTag directive

## Inputs
### `mode`
**Required** The value intended to be updated ENV_VAR or IMAGE_TAG or HELM_VALUES. Default `""`.
### `container-name`
**Required** The name of the container present in the pod definition

For docker container image tag we support
`Deployment StatefulSet CronJob or Kustomization images:newTag` object types

For Environment variable values we support
`Deployment StatefulSet` object types

For Helm values files (HELM_VALUES mode), the action supports:
- Default container images (`.image.tag`)
- Additional containers (`.containers.<container-name>.image.tag`)
- CronJob images (`.cronJobs.*.image.tag` or `.cronJobs.<container-name>.image.tag`)
- Raw container image strings whose image name matches `container-name`, for example `image: registry.example/load-test-tools:tag`
- Top-level default image tags (`image.tag`), even when the repository is set in another values file or differs from `container-name`

The action automatically detects whether you're updating the default container or an additional container by reading the `containerName` field from the Helm values file. When `containerName` is absent, a top-level `image.tag` is the default container and is updated directly. Raw or nested structured image values still match by image name, so unrelated image tags are not updated.

Default `""`

### `files`
**Required** The name of the file that holds the container image name

Expects relative path from the current working directory. 

Multiple files can be specified comma separated, i.e. `overlays/development-eu/packages/deployment-de.yaml,overlays/development-eu/packages/deployment-gb.yaml,kustomize-base/packages/deployment-ie.yaml`.

If action/checkout is used it is assumed that working directory is in the root of the cloned project

 Default `""`

### `new-image-tag`
**Optional** The value of the new image tag

If IMAGE_TAG is selected this is a mandatory value. 
You can populate this value with the current repo short sha.
Hint make sure that you have a previous step where you checkout the intended repo ( either the one for this workflow or other )
and calculate and export the short sha using 
`run: echo "::set-output name=GITHUB_SHORT_SHA::$(git rev-parse --short "$GITHUB_SHA") "` and use that output in your step
`new-image-tag: ${{ steps.your-previous-step-id.outputs.GITHUB_SHORT_SHA }}`
 
 Default `""`
### `env-name`
**Optional** The name of the env key that is present in the container form the specified file 

Default `""`

### `new-env-value`
**Optional** The new value for the env-name present in the container-name
 
Default `""`


## Outputs
none

## Example usage

### IMAGE_TAG mode - Update Kubernetes Deployment

```yaml
- name: Update image tag for container nginx in deployment.yaml
  uses: loveholidays/gitops-action-yaml-updater@v1.8.6
  with:
    mode: IMAGE_TAG
    container-name: nginx
    new-image-tag: prod-${{ steps.your-previous-step-id.outputs.GITHUB_SHORT_SHA }}
    files: overlays/development-eu/deployment.yaml
```

### IMAGE_TAG mode - Update multiple files

```yaml
- name: Update image tag for container bridge in two files
  uses: loveholidays/gitops-action-yaml-updater@v1.8.6
  with:
    mode: IMAGE_TAG
    container-name: nginx
    new-image-tag: prod-${{ steps.your-previous-step-id.outputs.GITHUB_SHORT_SHA }}
    files: "web/bridge/deployment.yaml,web/bridge-api/deployment.yaml"
```

### ENV_VAR mode - Update environment variable

```yaml
- name: Update MY_GITHUB_SHORT_SHA env value for nginx container
  uses: loveholidays/gitops-action-yaml-updater@v1.8.6
  with:
    mode: ENV_VAR
    container-name: nginx
    env-name: MY_GITHUB_SHORT_SHA
    new-env-value: ${{ steps.your-previous-step-id.outputs.GITHUB_SHORT_SHA }}
    files: overlays/development-eu/deployment.yaml
```

### HELM_VALUES mode - Update default container

```yaml
- name: Update default container image in Helm values
  uses: loveholidays/gitops-action-yaml-updater@v1.8.6
  with:
    mode: HELM_VALUES
    container-name: my-app
    new-image-tag: v1.2.3
    files: overlays/production/values.yaml
```

### HELM_VALUES mode - Update additional container (multi-container pod)

```yaml
- name: Update additional container image in Helm values
  uses: loveholidays/gitops-action-yaml-updater@v1.8.6
  with:
    mode: HELM_VALUES
    container-name: sidecar-ui
    new-image-tag: v2.0.0
    files: overlays/production/values.yaml
```

This will update `.containers.sidecar-ui.image.tag` in your Helm values file.

## ARM64 release

The v1.8.11 release adds native `linux/amd64` and `linux/arm64` images without
changing action inputs or update modes. The Docker build selects native yq
2.1.1, yq 4.35.1, and Kustomize 5.8.2 binaries with `TARGETARCH`. Other
architectures are rejected. The entrypoint and YAML update behaviour are unchanged.

CI builds and tests both architectures on pull requests. Publication runs only
after both test jobs pass, and verifies that the image manifest contains both
platforms. ARM64 CI execution uses QEMU on a GitHub-hosted AMD64 runner; this is
not a substitute for validation on the staging ARC runner.

After merge, let the master build publish `latest`, then publish the v1.8.11 tag
from the merged commit. Verify the versioned manifest before updating callers:

```sh
docker buildx imagetools inspect ghcr.io/loveholidays/gitops-action-yaml-updater:v1.8.11
```

Do not update caller references before the versioned image exists. The action
metadata in this release points to v1.8.11; existing v1.8.10 callers and images
remain unchanged. Validate the new Docker action on a staging ARM64 runner using
fixture files before updating the shared GitOps workflow. Hub and token generation
are separate migration tasks.

Rollback callers to their previous action SHA or tag. ARM64 callers must return
to an AMD64 runner as well if they revert to the AMD64-only v1.8.10 image. No
changes to application values are required by this release.

## Testing

The action includes a comprehensive test suite. See [tests/README.md](tests/README.md) for details on running tests.
