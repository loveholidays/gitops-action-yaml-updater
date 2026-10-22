FROM alpine:3.23.6@sha256:85fe1e81d6758c208f3e1eed4338a1997e19d4be002d4dd32d3100c9a8c010a0

ARG TARGETARCH
ARG YQ_VERSION=3.4.1
ARG YQ4_VERSION=v4.35.1
ARG KUSTOMIZE_VERSION=5.8.2

RUN apk add --no-cache ca-certificates ca-certificates-bundle curl bash grep && \
    apk upgrade --no-cache ca-certificates ca-certificates-bundle && \
    update-ca-certificates && \
    ca_version="$(apk list --installed ca-certificates | sed 's/^ca-certificates-//;s/ .*//')" && \
    bundle_version="$(apk list --installed ca-certificates-bundle | sed 's/^ca-certificates-bundle-//;s/ .*//')" && \
    test "$(apk version -t "${ca_version}" 20261020-r0)" != "<" && \
    test "$(apk version -t "${bundle_version}" 20261020-r0)" != "<"

RUN case "${TARGETARCH}" in amd64|arm64) ;; *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; esac && \
    yq_asset="yq_linux_${TARGETARCH}" && \
    yq4_asset="yq_linux_${TARGETARCH}" && \
    kustomize_asset="kustomize_v${KUSTOMIZE_VERSION}_linux_${TARGETARCH}.tar.gz" && \
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/checksums" -o /tmp/yq-checksums && \
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/checksums_hashes_order" -o /tmp/yq-checksums-order && \
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${yq_asset}" -o /tmp/yq && \
    yq_sha256_column="$(awk '$0 == "SHA-256" { print NR + 1; exit }' /tmp/yq-checksums-order)" && \
    yq_sha256="$(awk -v asset="${yq_asset}" -v column="${yq_sha256_column}" '$1 == asset { print $column; found = 1; exit } END { if (!found) exit 1 }' /tmp/yq-checksums)" && \
    test "${#yq_sha256}" -eq 64 && printf '%s  %s\n' "${yq_sha256}" /tmp/yq | sha256sum -c - && \
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ4_VERSION}/checksums" -o /tmp/yq4-checksums && \
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ4_VERSION}/checksums_hashes_order" -o /tmp/yq4-checksums-order && \
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ4_VERSION}/${yq4_asset}" -o /tmp/yq4 && \
    yq4_sha256_column="$(awk '$0 == "SHA-256" { print NR + 1; exit }' /tmp/yq4-checksums-order)" && \
    yq4_sha256="$(awk -v asset="${yq4_asset}" -v column="${yq4_sha256_column}" '$1 == asset { print $column; found = 1; exit } END { if (!found) exit 1 }' /tmp/yq4-checksums)" && \
    test "${#yq4_sha256}" -eq 64 && printf '%s  %s\n' "${yq4_sha256}" /tmp/yq4 | sha256sum -c - && \
    curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/checksums.txt" -o /tmp/kustomize-checksums && \
    curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/${kustomize_asset}" -o /tmp/kustomize.tar.gz && \
    kustomize_sha256="$(awk -v asset="${kustomize_asset}" '$2 == asset { print $1; found = 1; exit } END { if (!found) exit 1 }' /tmp/kustomize-checksums)" && \
    test "${#kustomize_sha256}" -eq 64 && printf '%s  %s\n' "${kustomize_sha256}" /tmp/kustomize.tar.gz | sha256sum -c - && \
    install -m 755 /tmp/yq /usr/local/bin/yq && \
    install -m 755 /tmp/yq4 /usr/local/bin/yq4 && \
    tar -xzf /tmp/kustomize.tar.gz -C /usr/local/bin kustomize && \
    chmod 755 /usr/local/bin/kustomize && \
    rm -f /tmp/yq /tmp/yq4 /tmp/kustomize.tar.gz /tmp/yq-checksums /tmp/yq-checksums-order /tmp/yq4-checksums /tmp/yq4-checksums-order /tmp/kustomize-checksums && \
    yq --version && yq4 --version && kustomize version

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
