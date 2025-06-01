set -euo pipefail

if [ $# -ne 1 ]; then
    echo "} usage: $0 <ISO_NAME>"
    exit 1
fi

# read config
ISO_NAME="$1"
CONFIG_FILE="config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "} config file '$CONFIG_FILE' not found"
    exit 1
fi

CONFIG=$(jq -r ".${ISO_NAME}" "$CONFIG_FILE")
if [ -z "$CONFIG" ]; then
    echo "} '$ISO_NAME' not defined in $CONFIG_FILE"
    exit 1
fi

# parse
ISO_PATH=$(echo "$CONFIG" | jq -r '.iso_path')
ISO_URL=$(echo "$CONFIG" | jq -r '.iso_url')
GUIDE=$(echo "$CONFIG" | jq -r '.guide')
DISK_SIZE=$(echo "$CONFIG" | jq -r '.disk_size')
RAM_SIZE=$(echo "$CONFIG" | jq -r '.ram_size')

# creating ramdisk
RAMDISK_DIR="$(pwd)/tempos-drives"
mkdir -p "$RAMDISK_DIR"

if ! mountpoint -q "$RAMDISK_DIR"; then
    echo "} mounting ramdisk to $RAMDISK_DIR"
    sudo mount -t tmpfs -o size=$DISK_SIZE tmpfs "$RAMDISK_DIR"
fi

# download and copy iso to ramdisk
ISO_RAMDISK="$RAMDISK_DIR/${ISO_NAME}.iso"

# make the directories for the iso path
mkdir -p "$(dirname "$ISO_PATH")"

if [ ! -f "$ISO_PATH" ]; then
    echo "} downloading iso from $ISO_URL"
    wget "$ISO_URL" -O "$ISO_PATH"
fi

cp "$ISO_PATH" "$ISO_RAMDISK"

# make the virtual drive drive
ROOT_IMG="$RAMDISK_DIR/${ISO_NAME}-root.qcow2"
if [ ! -f "$ROOT_IMG" ]; then
    echo "} creating root image '$ROOT_IMG'"
    qemu-img create -f qcow2 "$ROOT_IMG" "$DISK_SIZE"
fi

# check if guide exists
if [ -n "$GUIDE" ]; then
    if [ -f "$GUIDE" ]; then
        echo "} guide for $ISO_NAME:"
        cat "$GUIDE"
        echo
    else
        echo "} guide for $ISO_NAME not found: $GUIDE"
    fi
else
    echo "} no guide for $ISO_NAME"
fi

echo "} starting qemu..."
qemu-system-x86_64 \
  -enable-kvm \
  -m "$RAM_SIZE" \
  -smp "$(nproc)" \
  -cpu host \
  -drive if=virtio,file="$ROOT_IMG",format=qcow2 \
  -boot order=c,once=d \
  -cdrom "$ISO_RAMDISK" \
  -vga virtio \
  -display gtk \
  -net nic,model=virtio \
  -net user &

QEMU_PID=$!

echo "} pasting unmount command to clipboard"
echo "sudo umount \"$RAMDISK_DIR\" && rmdir \"$RAMDISK_DIR\"" | wl-copy
