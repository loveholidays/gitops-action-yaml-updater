# Update yaml's file docker action
#### gitops-action-yaml-updater

This action updates in place yaml files using yq for correct identification of resources under container
If the yaml file is a kustomize partial file, make sure that the value to be updated is part of the file mentioned in the filepath.

This also supports kustomize images: newTag directive

## Inputs
### `mode`
**Required** The value intended to be updated ENV_VAR or IMAGE_TAG. Default `""`.
### `container-name`
**Required** The name of the container present in the pod definition

For docker container image tag we support
`Deployment StatefulSet CronJob or Kustomization images:newTag` object types

For Environment variable values we support
`Deployment StatefulSet` object types

Default `""`
### `filepath`
**Required** The name of the file that holds the container image name

Expects relative path from the current working directory. 
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

      - name: Update image tag for container nginx in deployment.yaml
        uses: loveholidays/gitops-action-yaml-updater@v1.0
        with:
          mode: IMAGE_TAG
          container-name: nginx
          new-image-tag: prod-${{ steps.your-previous-step-id.outputs.GITHUB_SHORT_SHA }}
          filepath: deployment.yaml

      - name: Update MY_GITHUB_SHORT_SHA env value for nginx container
        uses: loveholidays/gitops-action-yaml-updater@v1.0
        with:
          mode: ENV_VAR
          container-name: nginx
          env-name: MY_GITHUB_SHORT_SHA
          new-env-value: ${{ steps.your-previous-step-id.outputs.GITHUB_SHORT_SHA }}
          filepath: deployment.yaml