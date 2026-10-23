#!/bin/bash
set -euo pipefail

mkdir -p /results
work=$(mktemp -d)
pids=()
cleanup() {
    status=$?
    trap - EXIT
    for pid in "${pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            wait "$pid" || true
        fi
    done
    exit "$status"
}
trap 'cleanup' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

cd "$work"
ssh-keygen -q -t ed25519 -N '' -f key
key=$(cat key.pub)
ssh_opts=(-i "$work/key" -o StrictHostKeyChecking=accept-new
    -o UserKnownHostsFile="$work/known_hosts" -o BatchMode=yes
    -o ConnectTimeout=5 -o ServerAliveInterval=15 -o ServerAliveCountMax=4)
accel=tcg
cpu=max
if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    accel=kvm
    cpu=host
fi
echo "QEMU accelerator: $accel"

start_vm() {
    local name=$1 port=$2 memory=$3 forwards=$4
    mkdir "$name"
    cat > "$name/user-data" <<EOF
#cloud-config
hostname: $name
manage_etc_hosts: true
disable_root: false
ssh_pwauth: false
users:
  - name: root
    ssh_authorized_keys:
      - $key
  - name: backupninja
    uid: 1000
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - $key
EOF
    printf 'instance-id: %s\nlocal-hostname: %s\n' "$name" "$name" > "$name/meta-data"
    genisoimage -quiet -output "$name/seed.iso" -volid cidata -joliet -rock \
        "$name/user-data" "$name/meta-data"
    qemu-img create -q -f qcow2 -F qcow2 \
        -b /opt/backupninja-vm/base.qcow2 "$name/root.qcow2" 12G
    local disks=()
    if [[ "$name" == bntest0 ]]; then
        for disk in b c d e; do
            qemu-img create -q -f qcow2 "$name/$disk.qcow2" 128M
            disks+=(-drive "file=$name/$disk.qcow2,format=qcow2,if=none,id=$disk"
                -device "scsi-hd,drive=$disk,serial=bntest-$disk")
        done
    fi
    qemu-system-x86_64 -machine "q35,accel=$accel" -cpu "$cpu" \
        -smp 2 -m "$memory" -display none -monitor none \
        -serial "file:/results/$name.serial.log" -no-reboot \
        -device virtio-scsi-pci,id=scsi \
        -drive "file=$name/root.qcow2,format=qcow2,if=none,id=root" \
        -device scsi-hd,drive=root \
        "${disks[@]}" \
        -drive "file=$name/seed.iso,format=raw,media=cdrom" \
        -nic "user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:$port-:22$forwards" \
        > "/results/$name.qemu.log" 2>&1 &
    pids+=("$!")
}

start_vm bntest1 22 1024 ',hostfwd=tcp:127.0.0.1:7722-:7722,hostfwd=tcp:127.0.0.1:8000-:8000'
start_vm bntest0 2222 2048 ''

wait_vm() {
    local port=$1 deadline=$((SECONDS + 600)) status
    echo "Waiting for cloud-init on SSH port $port"
    while (( SECONDS < deadline )); do
        if ssh "${ssh_opts[@]}" -p "$port" root@127.0.0.1 \
            'timeout 300 cloud-init status --wait' >> "/results/ssh-$port.log" 2>&1; then
            return 0
        else
            status=$?
        fi
        # cloud-init restarts sshd during first boot. Retry transport failures,
        # but preserve actual cloud-init errors and timeouts.
        if (( status != 255 )); then
            echo "cloud-init failed on port $port (exit $status). See SSH and serial logs." >&2
            return "$status"
        fi
        for pid in "${pids[@]}"; do
            if ! kill -0 "$pid" 2>/dev/null; then
                echo "QEMU exited before SSH became available. See VM logs." >&2
                return 1
            fi
        done
        sleep 2
    done
    echo "Timed out waiting for VM SSH on port $port. See VM logs." >&2
    return 1
}
wait_vm 22
wait_vm 2222

# Each VM is reached through QEMU user networking; no host network or disks
# are exposed. 10.0.2.2 is the container-side gateway, not the Docker host.
for port in 22 2222; do
    scp "${ssh_opts[@]}" -P "$port" /opt/backupninja-vm/provision.sh \
        /opt/backupninja-vm/rest-server root@127.0.0.1:/root/
    ssh "${ssh_opts[@]}" -p "$port" root@127.0.0.1 \
        'timeout 1200 bash /root/provision.sh' 2>&1 | tee "/results/provision-$port.log"
done
scp "${ssh_opts[@]}" -P 2222 "$work/key" root@127.0.0.1:/root/.ssh/id_ed25519
tar -C /src --exclude=.git --exclude=tmp --exclude=test-results -cf - . |
    ssh "${ssh_opts[@]}" -p 2222 root@127.0.0.1 \
        'mkdir /src; tar -xf - -C /src'

ssh "${ssh_opts[@]}" -p 2222 root@127.0.0.1 \
        'cd /src && ./autogen.sh &&
     ./configure --prefix=/usr --mandir=/usr/share/man --sysconfdir=/etc \
       --localstatedir=/var --libdir=/usr/lib --libexecdir=/usr/lib &&
     make clean && make && make install' 2>&1 | tee /results/build.log

command='cd /src && timeout 3600 bash test/test.sh'
for handler in "$@"; do
    if [[ ! "$handler" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        echo "Invalid handler: $handler" >&2
        exit 2
    fi
    command+=" $handler"
done
ssh "${ssh_opts[@]}" -p 2222 root@127.0.0.1 "$command" 2>&1 | tee /results/tests.log
