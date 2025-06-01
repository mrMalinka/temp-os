set -euo pipefail

if [ $# -ne 1 ]; then
    echo "} usage: $0 <iso_name>"
    exit 1
fi

# read config
iso_name="$1"
config_file="config.json"

if [ ! -f "$config_file" ]; then
    echo "} config file '$config_file' not found"
    exit 1
fi

config=$(jq -r ".${iso_name}" "$config_file")
if [ -z "$config" ]; then
    echo "} '$iso_name' not defined in $config_file"
    exit 1
fi

# parse
iso_path=$(echo "$config" | jq -r '.iso_path')
iso_url=$(echo "$config" | jq -r '.iso_url')
guide=$(echo "$config" | jq -r '.guide')
disk_size=$(echo "$config" | jq -r '.disk_size')
ram_size=$(echo "$config" | jq -r '.ram_size')

# creating ramdisk
ramdisk_dir="$(pwd)/tempos-drives"
mkdir -p "$ramdisk_dir"

if ! mountpoint -q "$ramdisk_dir"; then
    echo "} mounting ramdisk to $ramdisk_dir"
    sudo mount -t tmpfs -o size=$disk_size tmpfs "$ramdisk_dir"
fi

# download and copy iso to ramdisk
iso_ramdisk="$ramdisk_dir/${iso_name}.iso"

# make the directories for the iso path
mkdir -p "$(dirname $iso_path)"

if [ ! -f "iso_path" ]; then
    echo "} downloading iso from $iso_url"
    wget "$iso_url" -O "$iso_path"
fi

cp "$iso_path" "$iso_ramdisk"

# make the virtual drive drive
root_img="$ramdisk_dir/${iso_name}-root.qcow2"
if [ ! -f "$root_img" ]; then
    echo "} creating root image '$root_img'"
    qemu-img create -f qcow2 "$root_img" "$disk_size"
fi

# check if guide exists
if [ -n "$guide" ]; then
    if [ -f "$guide" ]; then
        echo "} guide for $iso_name:"
        cat "$guide"
        echo
    else
        echo "} guide for $iso_name not found: $guide"
    fi
else
    echo "} no guide for $iso_name"
fi

echo "} starting qemu..."
qemu-system-x86_64 \
  -enable-kvm \
  -m "$ram_size" \
  -smp "$(nproc)" \
  -cpu host \
  -drive if=virtio,file="$root_img",format=qcow2 \
  -boot order=c,once=d \
  -cdrom "$iso_ramdisk" \
  -vga virtio \
  -display gtk \
  -net nic,model=virtio \
  -net user &

qemu_pid=$!

echo "} pasting unmount command to clipboard"
echo "sudo umount \"$ramdisk_dir\" && rmdir \"$ramdisk_dir\"" | wl-copy