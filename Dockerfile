FROM alpine:3.16

ARG TARGETARCH
ARG KUSTOMIZE_VERSION=5.8.2

RUN apk add --no-cache curl bash grep

RUN case "${TARGETARCH}" in amd64|arm64) ;; *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; esac && \
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/2.1.1/yq_linux_${TARGETARCH}" -o /usr/local/bin/yq && \
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/v4.35.1/yq_linux_${TARGETARCH}" -o /usr/local/bin/yq4 && \
    curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_${TARGETARCH}.tar.gz" -o /tmp/kustomize.tar.gz && \
    tar -xzf /tmp/kustomize.tar.gz -C /usr/local/bin kustomize && \
    rm /tmp/kustomize.tar.gz && \
    chmod 755 /usr/local/bin/yq /usr/local/bin/yq4 /usr/local/bin/kustomize && \
    yq --version && yq4 --version && kustomize version

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
