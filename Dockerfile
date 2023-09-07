# It is cached on the GitHub builder https://github.com/actions/runner-images/blob/main/images/linux/Ubuntu2204-Readme.md#cached-docker-images
FROM alpine:3.16

RUN apk update && \
    apk add wget curl bash grep

RUN wget -nv https://github.com/mikefarah/yq/releases/download/2.1.1/yq_linux_amd64 && \
    chmod 744 yq_linux_amd64 && \
    mv yq_linux_amd64 /usr/local/bin/yq && \
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash && \
    mv kustomize /usr/local/bin/kustomize

# install yq v4
RUN wget -nv https://github.com/mikefarah/yq/releases/download/v4.35.1/yq_linux_amd64 && \
    chmod 744 yq_linux_amd64 && \
    mv yq_linux_amd64 /usr/local/bin/yq4

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

