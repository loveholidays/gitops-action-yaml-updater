FROM alpine

ENV KUSTOMIZE_VER 4.5.7

RUN apk update && \
    apk add yq curl bash

RUN curl -L https://github.com/kubernetes-sigs/kustomize/releases/download/v${KUSTOMIZE_VER}/kustomize_${KUSTOMIZE_VER}_linux_amd64  -o /usr/local/bin/kustomize \
    && chmod +x /usr/local/bin/kustomize

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]