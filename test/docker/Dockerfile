FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bats ca-certificates crudini curl genisoimage openssh-client qemu-system-x86 \
        qemu-utils shellcheck \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/backupninja-vm
RUN curl -fL --retry 3 -o base.qcow2 \
        https://cloud.debian.org/images/cloud/bookworm/20261021-2638/debian-12-generic-amd64-20261021-2638.qcow2 \
    && echo 'af209c3c3b4d7580bd5a9d32984d1dc3980681a055c64dd8d63ed23bcf22b8cfe6a60ff8f5e4d07287dc7726450c6e39d23dbb4f5af22fc7edfd783d532cecff  base.qcow2' | sha512sum -c - \
    && curl -fL --retry 3 -o rest-server.tar.gz \
        https://github.com/restic/rest-server/releases/download/v0.14.0/rest-server_0.14.0_linux_amd64.tar.gz \
    && echo '4c9c95bc079a0334e81fad379b19dc5c3353c71c2c88d652cafce2081c2b1c66  rest-server.tar.gz' | sha256sum -c - \
    && tar -xzf rest-server.tar.gz --strip-components=1 --wildcards '*/rest-server' \
    && rm rest-server.tar.gz

COPY test/docker/run-vms.sh test/docker/provision.sh ./
COPY . /src
ENTRYPOINT ["bash", "/opt/backupninja-vm/run-vms.sh"]
