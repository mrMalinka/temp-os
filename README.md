# Example `config.json`:
```json
{
    "alpine": {
        "iso_path": "./isos/alpine.iso",
        "iso_url": "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-virt-3.19.0-x86_64.iso",
        "guide": "guide-alpine.md",
        "disk_size": "20G",
        "ram_size": "6G"
    }
}
```

# Dependencies
- jq
- wget
- qemu
- wl-clipboard