# Lenovo TS150 – Ubuntu KVM Windows 10 Remote Tally Server

## Overview

This repository documents the complete setup of a **Lenovo TS150 server** running **Ubuntu Server 22.04 LTS**, hosting a **Windows 10 virtual machine on KVM**, and providing **secure remote access using WireGuard VPN (wg-easy Docker)**.

### Primary Use Case
- Centralized **Tally** deployment
- Up to **6 concurrent RDP users**
- **VPN-only access** (no public RDP exposure)
- Simple VPN client management via **wg-easy Web UI**

---

## Hardware Configuration

| Component | Specification |
|---------|--------------|
| Server | Lenovo TS150 |
| RAM | 16 GB |
| CPU | Multi-core |
| SSD 1 | Ubuntu OS |
| SSD 2 | VM Data Disk |
| USB | Backup Disk |

---

## Disk Layout

```text
SSD 1
 └── Ubuntu Server 22.04 (Host OS)

SSD 2
 └── /data
     └── KVM VM disks (Windows 10)

USB Disk
 └── Backup target (mount → sync → unmount)
```

---

## STEP 1 – Base System Preparation (Fresh Ubuntu)

```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

```bash
sudo timedatectl set-timezone Asia/Kolkata
```

---

## STEP 2 – Prepare Data Disk (SSD 2)

```bash
lsblk
```

_Assume disk: `/dev/sdb`_

```bash
sudo parted /dev/sdb --script mklabel gpt
sudo parted /dev/sdb --script mkpart primary ext4 0% 100%
sudo mkfs.ext4 /dev/sdb1
```

```bash
sudo mkdir -p /data
sudo mount /dev/sdb1 /data
```

Persist mount:

```bash
sudo blkid /dev/sdb1
```

Edit `/etc/fstab`:

```text
UUID=XXXX-XXXX  /data  ext4  defaults  0  2
```

```bash
sudo mount -a
```

---

## STEP 3 – Install KVM Virtualization

```bash
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
```

```bash
sudo systemctl enable libvirtd
sudo systemctl start libvirtd
```

```bash
sudo usermod -aG libvirt,kvm $USER
newgrp libvirt
```

Verify:

```bash
virsh list --all
```

---

## STEP 4 – Create Windows 10 VM

```bash
mkdir -p /data/vm
qemu-img create -f qcow2 /data/vm/win10.qcow2 150G
```

```bash
virt-install --name win10-tally --ram 8192 --vcpus 4 --disk path=/data/vm/win10.qcow2,format=qcow2 --os-variant win10 --cdrom /iso/Windows10.iso --network network=default --graphics vnc
```

### Inside Windows VM
- Install **Tally**
- Install **RDP Wrapper**
- Enable **6 concurrent users**
- Install **WireGuard client**

---

## STEP 5 – Install Docker (Required for wg-easy)

```bash
sudo apt install -y ca-certificates curl gnupg
```

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
```

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

---

## STEP 6 – Deploy WireGuard using wg-easy (jc21)

```bash
sudo mkdir -p /opt/wg-easy
cd /opt/wg-easy
```

Create `docker-compose.yml`:

```yaml
version: "3.8"

services:
  wg-easy:
    image: weejewel/wg-easy
    container_name: wg-easy
    environment:
      WG_HOST: <PUBLIC_IP_OR_DOMAIN>
      PASSWORD: <STRONG_ADMIN_PASSWORD>
      WG_DEFAULT_ADDRESS: 10.10.0.x
      WG_DEFAULT_DNS: 1.1.1.1
    volumes:
      - ./config:/etc/wireguard
    ports:
      - "51820:51820/udp"
      - "51821:51821/tcp"
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
    restart: unless-stopped
```

```bash
docker compose up -d
```

Access UI:

```text
http://SERVER_IP:51821
```

---

## STEP 7 – VPN Client Setup

- Create **Windows VM** client in wg-easy
- Create **remote user** clients
- Import config in WireGuard client

---

## STEP 8 – Remote Access Flow

```text
Remote User
   │
   └── WireGuard VPN (wg-easy)
           │
           └── Ubuntu Host
                    │
                    └── Windows 10 VM (RDP + Tally)
```

---

## STEP 9 – Backup Strategy (USB Disk)

### Manual Backup

```bash
sudo mount /dev/sdc1 /mnt/backup
rsync -av /data/ /mnt/backup/data/
sync
sudo umount /mnt/backup
```

### Automated Backup

```bash
sudo crontab -e
```

```bash
0 2 * * * /usr/bin/rsync -av --delete /data/ /mnt/backup/data/
```

---

## Maintenance Checklist

- Ubuntu updates (monthly)
- Windows VM updates
- Docker image updates
- VPN client audit
- Backup verification

---

## License

Internal infrastructure documentation. Use at your own risk.
