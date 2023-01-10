#!/bin/bash

SUPPORTED_MODES=(ENV_VAR IMAGE_TAG)
MODE=$1
CONTAINER_NAMES=$2
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
  for CONTAINER_NAME in CONTAINER_NAMES; do
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

        imageFullName=$(grep -Po '\K.*?(?=:)' <<< ${currentImageValue})
        if [ -z "${imageFullName}" ]; then imageFullName=${currentImageValue}; fi
        echo " +++ + + to new  image  tag    ${imageFullName}:${NEW_IMAGE_TAG}"
        sed -i "s+${currentImageValue}+${imageFullName}:${NEW_IMAGE_TAG}+g" ${FILEPATH}
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

        imageFullName=$(grep -Po '\K.*?(?=:)' <<< ${currentImageValue})
        if [ -z "${imageFullName}" ]; then imageFullName=${currentImageValue}; fi
        echo " +++ + + to new  image  tag    ${imageFullName}:${NEW_IMAGE_TAG}"
        sed -i "s+${currentImageValue}+${imageFullName}:${NEW_IMAGE_TAG}+g" ${FILEPATH}
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
              imageFullName=$(grep -Po '\K.*?(?=:)' <<< ${currentImageValue})
              if [ -z "${imageFullName}" ]; then imageFullName=${currentImageValue}; fi
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
        sed -i "s+${kustomizeCurrentNewTagValue}+${NEW_IMAGE_TAG}+g" ${FILEPATH}
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
        sed -i "s+${sanitizedOldString}+${sanitizedNewString}+g" ${FILEPATH}
      fi
    fi;
  done
done