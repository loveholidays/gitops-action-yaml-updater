# It is cached on the GitHub builder https://github.com/actions/runner-images/blob/main/images/linux/Ubuntu2204-Readme.md#cached-docker-images
FROM alpine:3.16

ENV KUSTOMIZE_VER 4.5.7

RUN apk update && \
    apk add wget curl bash

RUN wget -nv https://github.com/mikefarah/yq/releases/download/2.1.1/yq_linux_amd64 && \
    chmod 744 yq_linux_amd64 && \
    mv yq_linux_amd64 /usr/local/bin/yq && \
    curl -L https://github.com/kubernetes-sigs/kustomize/releases/download/v${KUSTOMIZE_VER}/kustomize_${KUSTOMIZE_VER}_linux_amd64  -o /usr/local/bin/kustomize \
    && chmod +x /usr/local/bin/kustomize

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]