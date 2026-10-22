#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
for handler in "$@"; do
    if [[ ! "$handler" =~ ^[a-z][a-z0-9_-]*$ || ! -f "test/$handler.bats" ]]; then
        echo "Unknown test handler: $handler" >&2
        exit 2
    fi
done

image=backupninja-tests
if [[ "${BN_TEST_SKIP_BUILD:-0}" != 1 ]]; then
    docker build --tag "$image" --file test/docker/Dockerfile .
fi
args=(--init)
if [[ "${BN_TEST_KVM:-0}" == 1 ]]; then
    args+=(--device /dev/kvm)
fi
results="${BN_TEST_RESULTS:-test-results}"
mkdir -p "$results"
container=$(docker create "${args[@]}" "$image" "$@")
# ShellCheck cannot follow this EXIT trap after the final dynamic exit.
# shellcheck disable=SC2317
cleanup() {
    status=$?
    trap - EXIT
    if ! docker cp "$container:/results/." "$results/"; then
        echo "Failed to retrieve VM logs." >&2
        status=1
    fi
    if ! docker rm -f "$container" >/dev/null; then
        echo "Failed to remove test container: $container" >&2
        status=1
    fi
    exit "$status"
}
trap 'cleanup' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
docker start --attach "$container"
# docker start --attach is not guaranteed to propagate the container exit code.
status=$(docker inspect --format '{{.State.ExitCode}}' "$container")
exit "$status"
