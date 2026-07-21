#!/bin/bash

# Cross-platform sed in-place editing
sed_inplace() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS requires an extension argument (empty string for no backup)
    sed -i '' "$@"
  else
    # Linux/GNU sed
    sed -i "$@"
  fi
}

SUPPORTED_MODES=(ENV_VAR IMAGE_TAG HELM_VALUES)
MODE=$1
CONTAINER_NAME=$2
FILES=$3
NEW_IMAGE_TAG=$4
ENV_NAME=$5
NEW_ENV_VALUE=$6
if [[ ! " ${SUPPORTED_MODES[@]} " =~ " ${MODE} " ]]; then
  echo " +++++++++ ERROR MODE \"${MODE}\" is not part of the supported values [ ${SUPPORTED_MODES[@]} ] " >&2
  exit 1
fi

IFS=","
for FILEPATH in $FILES; do

  if test -f "${FILEPATH}"; then
    echo " +++ + Updating file ${FILEPATH}"
  else
    echo " +++++++++ ERROR file \"${FILEPATH}\" does not exist" >&2
    exit 1
  fi


  if [[ ${MODE} == "IMAGE_TAG" ]]; then
    SUPPORTED_OBJECT_KINDS=(Deployment StatefulSet CronJob Kustomization)
    if [ -z "${NEW_IMAGE_TAG}" ]; then
      echo " +++++++++ ERROR NEW_IMAGE_TAG  \"${NEW_IMAGE_TAG}\" is not correct " >&2
      exit 1
    fi

    objectKind=$(yq r ${FILEPATH} kind)
    echo " +++ + Detected Object kind as \"${objectKind}\" "

    if [[ ! " ${SUPPORTED_OBJECT_KINDS[@]} " =~ " ${objectKind} " ]]; then
      echo " +++++++++ ERROR Object kind \"${objectKind}\" is not part of the supported values [ ${SUPPORTED_OBJECT_KINDS[@]} ] for file ${FILEPATH} " >&2
      exit 1
    fi

    if [[ ${objectKind} == "Deployment" ]] || [[ ${objectKind} == "StatefulSet" ]] ; then
      containerPosition=$(yq r ${FILEPATH} spec.template.spec.containers.*.name | grep -n ${CONTAINER_NAME}$ | cut -d: -f1)
      containerIndex=$((${containerPosition/M/}-1))
      if (( ${containerIndex} < 0 )) ; then
        echo " +++++++++ ERROR container with name ${CONTAINER_NAME} could not be found in file  ${FILEPATH}" >&2
        exit 1
      fi

      echo " +++ + Container Index $containerIndex"
      currentImageValue=$(yq r ${FILEPATH} spec.template.spec.containers[${containerIndex}].image)
      if [[ ${currentImageValue} == "null" ]]; then
        echo " +++++++++ ERROR Cannot find image field for container named  ${CONTAINER_NAME} in file ${FILEPATH} " >&2
        exit 1
      fi

      echo " +++ + + Processing image from $currentImageValue"

      # Extract image name without tag (everything before ':')
      imageFullName="${currentImageValue%%:*}"
      echo " +++ + + to new  image  tag    ${imageFullName}:${NEW_IMAGE_TAG}"
      sed_inplace "s+${currentImageValue}+${imageFullName}:${NEW_IMAGE_TAG}+g" ${FILEPATH}
    fi

    if [[ ${objectKind} == "CronJob" ]] ; then
      containerPosition=$(yq r ${FILEPATH} spec.jobTemplate.spec.template.spec.containers.*.name | grep -n ${CONTAINER_NAME}$ | cut -d: -f1)
      containerIndex=$((${containerPosition/M/}-1))
      if (( ${containerIndex} < 0 )); then
        echo " +++++++++ ERROR container with name ${CONTAINER_NAME} could not be found in file CronJob  ${FILEPATH}" >&2
        exit 1
      fi

      echo " +++ + Container Index in CronJob $containerIndex"
      currentImageValue=$(yq r ${FILEPATH} spec.jobTemplate.spec.template.spec.containers[${containerIndex}].image)
      if [[ ${currentImageValue} == "null" ]]; then
        echo " +++++++++ ERROR Cannot find image field for container named  ${CONTAINER_NAME} in file ${FILEPATH} " >&2
        exit 1
      fi

      echo " +++ + + Processing image from $currentImageValue"

      # Extract image name without tag (everything before ':')
      imageFullName="${currentImageValue%%:*}"
      echo " +++ + + to new  image  tag    ${imageFullName}:${NEW_IMAGE_TAG}"
      sed_inplace "s+${currentImageValue}+${imageFullName}:${NEW_IMAGE_TAG}+g" ${FILEPATH}
    fi


    if [[ ${objectKind} == "Kustomization" ]] ; then
      kustomizeBuildPath="${FILEPATH%/*}"
      echo " +++ + Building kustomize in directory ${kustomizeBuildPath}"
      fullKustomizeBuild=$(kustomize build ${kustomizeBuildPath})

      delimiter="---"
      s=$fullKustomizeBuild$delimiter
      kustomizeImageNameToUpdate=""
      while [[ $s ]]; do
          object="${s%%"$delimiter"*}"
          containerPosition=$(echo "$object" | yq r - spec.template.spec.containers.*.name | grep -n ${CONTAINER_NAME}$ | cut -d: -f1)
          if [[ $containerPosition ]]; then
            containerIndex=$((${containerPosition/M/}-1))
            currentImageValue=$(echo "$object" | yq r - spec.template.spec.containers[${containerIndex}].image)
            if [[ ! $currentImageValue ]]; then
              currentImageValue=$(echo "$object" | yq r - spec.jobTemplate.spec.template.spec.containers[${containerIndex}].image)
            fi
            # Extract image name without tag (everything before ':')
            imageFullName="${currentImageValue%%:*}"
            kustomizeImageNameToUpdate=${imageFullName}
          fi
          s=${s#*"$delimiter"};
      done;

      if [[ ! $kustomizeImageNameToUpdate ]]; then
        echo " +++++++++ ERROR container with name ${CONTAINER_NAME} could not be found in any file build by kustomize from folder ${kustomizeBuildPath}" >&2
        exit 1
      fi

      kustomizeImageNamePosition=$(yq r ${FILEPATH} images.*.name | grep -n ${kustomizeImageNameToUpdate} | cut -d: -f1)
      kustomizeContainerIndex=$((${kustomizeImageNamePosition/M/}-1))
      kustomizeCurrentNewTagValue=$(yq r ${FILEPATH} images[${kustomizeContainerIndex}].newTag)

      echo " +++ + + Processing newTag for image name: $kustomizeImageNameToUpdate"
      echo " +++ + + + from newTag: ${kustomizeCurrentNewTagValue}"
      echo " +++ + + + to   newTag: ${NEW_IMAGE_TAG}"
      sed_inplace "s+${kustomizeCurrentNewTagValue}+${NEW_IMAGE_TAG}+g" ${FILEPATH}
    fi
  fi

  if [[ ${MODE} == "ENV_VAR" ]]; then
    SUPPORTED_OBJECT_KINDS=(Deployment StatefulSet)
    objectKind=$(yq r ${FILEPATH} kind)
    echo " +++ + Detected Object kind as \"${objectKind}\" "

    if [[ ! " ${SUPPORTED_OBJECT_KINDS[@]} " =~ " ${objectKind} " ]]; then
      echo " +++++++++ ERROR Object kind \"${objectKind}\" is not part of the supported values [ ${SUPPORTED_OBJECT_KINDS[@]} ] for file ${FILEPATH} " >&2
      exit 1
    fi

    if [[ ${objectKind} == "Deployment" ]] || [[ ${objectKind} == "StatefulSet" ]] ; then
      containerPosition=$(yq r ${FILEPATH} spec.template.spec.containers.*.name | grep -n ${CONTAINER_NAME}$ | cut -d: -f1)
      containerIndex=$((${containerPosition/M/}-1))
      if (( ${containerIndex} < 0 )); then
        echo " +++++++++ ERROR container with name ${CONTAINER_NAME} could not be found in file  ${FILEPATH}" >&2
        exit 1
      fi

      echo " +++ + Container Index $containerIndex"
      envPosition=$(yq r ${FILEPATH} spec.template.spec.containers[${containerIndex}].env[*].name | grep -n ${ENV_NAME}$ | cut -d: -f1)
      envIndex=$((${envPosition/M/}-1))
      if (( ${envIndex} < 0 )); then
        echo " +++++++++ ERROR Environment variable with name ${ENV_NAME} not found in ${CONTAINER_NAME}" >&2
        exit 1
      fi
      currentEnvValue=$(yq r ${FILEPATH} spec.template.spec.containers[${containerIndex}].env[${envIndex}].value)

      echo " +++ + + Updating ${ENV_NAME} in container ${CONTAINER_NAME} from ${currentEnvValue}"
      echo " +++ + + To env   ${ENV_NAME} in container ${CONTAINER_NAME} to   ${NEW_ENV_VALUE}"
      sanitizedOldString=$(echo $currentEnvValue | sed 's/[][`~!@#$%^&*()-+{}\|;:_=",<.>/?'"'"']/\\&/g')
      sanitizedNewString=$(echo $NEW_ENV_VALUE | sed 's/[][`~!@#$%^&*()-+{}\|;:_=",<.>/?'"'"']/\\&/g')
      sed_inplace "s+${sanitizedOldString}+${sanitizedNewString}+g" ${FILEPATH}
    fi
  fi;

  if [[ ${MODE} == "HELM_VALUES" ]]; then
    # Read the default container name from the values file
    defaultContainerName=$(yq4 '.containerName // ""' "${FILEPATH}")

    # Determine if we're updating the default container or an additional container
    if [[ -n "${defaultContainerName}" ]] && [[ "${CONTAINER_NAME}" == "${defaultContainerName}" ]]; then
      # Updating the default container
      targetImageKey=".image.tag"
      targetCronJobKey=".cronJobs.*.image.tag"
      echo " +++ + Updating default container: ${CONTAINER_NAME}"
    elif [[ -z "${defaultContainerName}" ]]; then
      # No default container name specified, assume default paths
      targetImageKey=".image.tag"
      targetCronJobKey=".cronJobs.*.image.tag"
      echo " +++ + No default container name found, using default paths"
    else
      # Updating an additional container
      targetImageKey=".containers.${CONTAINER_NAME}.image.tag"
      targetCronJobKey=".cronJobs.${CONTAINER_NAME}.image.tag"
      echo " +++ + Updating additional container: ${CONTAINER_NAME}"
    fi

    # Update cronJobs if present
    if [[ $(yq4 'has("cronJobs")' "${FILEPATH}" 2>/dev/null) == "true" ]]; then
      if [[ -n "${defaultContainerName}" ]] && [[ "${CONTAINER_NAME}" != "${defaultContainerName}" ]]; then
        if [[ $(yq4 ".cronJobs | has(\"${CONTAINER_NAME}\")" "${FILEPATH}" 2>/dev/null) == "true" ]]; then
          yq4 "${targetCronJobKey} = \"${NEW_IMAGE_TAG}\"" -i ${FILEPATH}
          echo " +++ + + Updated cronJob: ${targetCronJobKey}"
        fi
      else
        yq4 "${targetCronJobKey} = \"${NEW_IMAGE_TAG}\"" -i ${FILEPATH}
        echo " +++ + + Updated cronJob: ${targetCronJobKey}"
      fi
    fi

    # Update image if present (for default container) or containers.<name> (for additional)
    if [[ -n "${defaultContainerName}" ]] && [[ "${CONTAINER_NAME}" == "${defaultContainerName}" ]]; then
      # Default container - check for .image
      if [[ $(yq4 'has("image")' "${FILEPATH}" 2>/dev/null) == "true" ]]; then
        yq4 "${targetImageKey} = \"${NEW_IMAGE_TAG}\"" -i ${FILEPATH}
        echo " +++ + + Updated ${targetImageKey} in ${FILEPATH} to ${NEW_IMAGE_TAG}"
      fi
    elif [[ -z "${defaultContainerName}" ]]; then
      # No container name specified, use default behavior
      if [[ $(yq4 'has("image")' "${FILEPATH}" 2>/dev/null) == "true" ]]; then
        yq4 "${targetImageKey} = \"${NEW_IMAGE_TAG}\"" -i ${FILEPATH}
        echo " +++ + + Updated ${targetImageKey} in ${FILEPATH} to ${NEW_IMAGE_TAG}"
      fi
    else
      # Additional container - check for .containers.<name>
      if [[ $(yq4 "has(\"containers\") and (.containers | has(\"${CONTAINER_NAME}\"))" "${FILEPATH}" 2>/dev/null) == "true" ]]; then
        yq4 "${targetImageKey} = \"${NEW_IMAGE_TAG}\"" -i ${FILEPATH}
        echo " +++ + + Updated ${targetImageKey} in ${FILEPATH} to ${NEW_IMAGE_TAG}"
      else
        echo " +++++++++ ERROR: Container ${CONTAINER_NAME} not found in ${FILEPATH}" >&2
        exit 1
      fi
    fi
  fi
done
