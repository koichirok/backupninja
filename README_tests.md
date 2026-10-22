When developping fixes or new features for backupninja, it is highly recommended
to run the test suite to help spot potential problems.

Docker (recommended)
====================

Install Docker Engine with Linux container support, or open the repository
in its VS Code Dev Container. The Dev Container uses Docker-in-Docker with
its own daemon and storage, not the host Docker socket.

From the repository root, run:

```sh
bash test/docker.sh
# Run just one handler, or several:
bash test/docker.sh sys
bash test/docker.sh mysql pgsql
```

Never run `test/test.sh` directly on the host or in the Dev Container.
It mounts filesystems, changes system configuration, and reformats the
dedicated test disks. It belongs only inside the disposable test VMs.

The runner builds an image containing the current working tree, including
uncommitted source changes. It does not mount the workspace: this also works
when the Docker daemon is inside a Dev Container. Ignored build output is
regenerated in the guest. Dependencies require network access to Debian and
GitHub during image creation and VM provisioning.

The image contains a versioned, SHA-512-verified Debian 12 amd64 cloud image
and a SHA-256-verified rest-server binary. Two disposable QEMU VMs reproduce
the existing local (`bntest0`) and SSH remote (`bntest1`) test environment.
The local VM has four additional virtual disks for real partition, MBR,
LVM, and LUKS tests. The root disk is never repartitioned.

No privileged test container, host block devices, loop devices, device-mapper,
host network, or host Docker socket are required. QEMU uses user-mode
networking; guest SSH and REST ports are forwarded only to the test
container's loopback interface, not published to the host. SSH keys are
generated separately for each run. Destroying the container removes the
VMs and all their disks, including after a failed test.

Allow at least 6 GiB of available memory and several GiB of disk space.
The default accelerator is software emulation (TCG), which works without
nested virtualization, including inside Docker-in-Docker, but can be slow.
The guest architecture is x86-64. CI validates x86-64 Linux hosts; other
host architectures require QEMU software emulation and are not covered by CI.
On Linux hosts with working KVM, explicitly allow the single KVM device:

```sh
BN_TEST_KVM=1 bash test/docker.sh
```

This requires `/dev/kvm` to be accessible to the Docker daemon. It does not
expose disks. For DinD, KVM must also be available in the Dev Container;
otherwise omit this option and use TCG.

Test, build, provisioning, and serial-console logs are copied to
`test-results/`, including on failure. Set `BN_TEST_RESULTS` to change this
local destination. A failing suite, provisioning command, VM startup, or log
copy produces a nonzero exit status. SSH startup is limited to ten minutes,
provisioning to twenty minutes per VM, and tests to one hour.

GitHub Actions uses the same image and runner, caches Docker build layers,
enables KVM when available, and uploads the logs even when tests fail.
`BN_TEST_SKIP_BUILD=1` is reserved for running an already-built
`backupninja-tests` image, as in CI; rebuild it after changing sources.

The runner's own regression tests mock Docker, package installation, and mount
commands; they never operate on real disks:

```sh
bats test/docker/runner.bats
# To also run the root-only suite-runner cases in an isolated container:
docker run --rm --entrypoint bats backupninja-tests /src/test/docker/runner.bats
```

Vagrant (legacy alternative)
============================

The original test environment is based on Vagrant, and relies on the VirtualBox
provider. The required package may be installed using the following command:

    apt install vagrant virtualbox

On Debian 10 (buster) these packages aren't available in the default upstream
repositories, so you will need to use an alternative such as the one provided
by an individual Debian developper here:

    https://people.debian.org/~lucas/virtualbox-buster/

Once the requirements are in place, the test suite may be run in this manner:

    git clone git@0xacab.org:liberate/backupninja.git
    cd backupninja
    vagrant up
    vagrant ssh -c "sudo /vagrant/test/test.sh"

It's possible to only test a specific handler with:

    vagrant ssh -c "sudo /vagrant/test/test.sh rdiff"

To synchronise changes in the source code and rebuild backupninja:

    vagrant rsync local && vagrant ssh -c "build-backupninja.sh"

Please report any problems with the test suite on the issue tracker at:

    https://0xacab.org/liberate/backupninja/-/issues
