FROM mcr.microsoft.com/devcontainers/base:trixie

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        bats \
        build-essential \
        crudini \
        dialog \
        faketime \
        file \
        gawk \
        shellcheck \
    && rm -rf /var/lib/apt/lists/*
