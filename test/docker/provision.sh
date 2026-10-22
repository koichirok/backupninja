#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C.UTF-8

# These guests never reboot; rebuilding the boot initramfs wastes several
# minutes under software emulation when LVM packages are installed.
sed -i 's/^update_initramfs=.*/update_initramfs=no/' /etc/initramfs-tools/update-initramfs.conf

apt-get update
apt-get install -y --no-install-recommends \
    borgbackup duplicity rdiff-backup restic rsync sudo
install -m 0755 /root/rest-server /usr/local/bin/rest-server
mkdir -p /var/backups
chown vagrant: /var/backups
printf 'Port 22\nPort 7722\n' > /etc/ssh/sshd_config.d/bntest.conf
systemctl restart ssh

if [[ "$(hostname)" == bntest0 ]]; then
    apt-get install -y --no-install-recommends \
        automake autoconf make dialog bats mailutils exim4 faketime crudini \
        cstream trickle gnupg mmdebstrap ncompress zstd bzip2 xz-utils python3-paramiko \
        debconf-utils hwinfo lvm2 cryptsetup-bin parted fdisk file \
        default-mysql-server postgresql prometheus-node-exporter
    echo 'root: vagrant' >> /etc/aliases
    newaliases
    systemctl restart exim4
    echo '10.0.2.2 bntest1' >> /etc/hosts
    printf 'Host bntest1\n    StrictHostKeyChecking accept-new\n' > /root/.ssh/config
    # The guest boot disk uses GPT. Use the disposable second disk for MBR
    # coverage instead of modifying the VM's root partition table.
    [[ "$(lsblk -dn -o SERIAL /dev/sdb)" == bntest-b ]]
    parted -s /dev/sdb mklabel msdos mkpart primary 1MiB 100%
    mkdir -p /etc/backupninja
    touch /etc/backupninja/docker-test-vm
fi
