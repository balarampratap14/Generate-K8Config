# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.177.0/containers/ubuntu/.devcontainer/base.Dockerfile

# [Choice] Ubuntu version: bionic, focal
ARG VARIANT="focal"
FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}

ENV KUBECONFIG=/workspaces/generate-k8s-access-policies/config-koireader-dev
ENV KOPS_CLUSTER_NAME=us-east-2.koi-ventures.com
ENV KOPS_STATE_STORE=s3://kops-koi-cluster-dev

# ENV KUBECONFIG=/workspaces/generate-k8s-access-policies/config-production
# ENV KOPS_CLUSTER_NAME=us-west-2.koi-ventures.com
# ENV KOPS_STATE_STORE=s3://kops-koi-cluster

# [Optional] Uncomment this section to install additional OS packages.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -yq install --no-install-recommends git curl ca-certificates

RUN curl --fail -LO https://dl.k8s.io/release/v1.20.7/bin/linux/amd64/kubectl \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/kubectl
