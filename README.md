# Lenovo TS150 – Ubuntu KVM + Docker Application Server

## Overview

This repository documents a **production-grade deployment** of a Lenovo TS150 server running **Ubuntu Server 22.04 LTS**, hosting:

- A **Windows 10 KVM virtual machine** for multi-user Tally access
- A **Docker application stack** for internal business services
- Secure remote access via **WireGuard (wg-easy)**
- HTTPS access using **Nginx Proxy Manager (jc21)**

This setup is designed for **small to medium office environments** with centralized services and strict network security.

---

## Server Specifications & Resource Allocation

### Physical Server
| Component | Specification |
|---------|---------------|
| Model | Lenovo TS150 |
| Total RAM | 16 GB |
| CPU | Multi-core |
| Storage | 2× SSD + USB Backup |

### Memory Allocation
| Layer | RAM |
|-----|-----|
| Ubuntu Host + Docker Services | 8 GB |
| Windows 10 KVM VM | 8 GB |
| **Total** | **16 GB** |

### Docker Services (Host)
- Nginx Proxy Manager (HTTPS / Reverse Proxy)
- WireGuard (wg-easy)
- n8n (Automation)
- Plane (Project Management)
- Odoo (ERP)
- Frappe Framework (ERPNext base)

---

## Disk Layout

```text
SSD 1
 └── Ubuntu Server 22.04 (Host OS)
     └── /opt (Docker stacks)

SSD 2
 └── /data
     └── KVM VM disks (Windows 10)

USB Disk
 └── Backup target (mount → sync → unmount)
```

---

## Network Architecture

```text
Remote User
   │
   └── WireGuard VPN (wg-easy)
           │
           └── Ubuntu Host
               ├── Docker Services (HTTPS via NPM)
               └── Windows 10 VM (RDP + Tally)
```

---

# STEP 1 – Base System Preparation (Fresh Ubuntu)

```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

```bash
sudo timedatectl set-timezone Asia/Kolkata
```

---

# STEP 2 – Prepare Data Disk (SSD 2)

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

# STEP 3 – Install KVM Virtualization

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

---

# STEP 4 – Create Windows 10 VM (Tally Server)

```bash
mkdir -p /data/vm
qemu-img create -f qcow2 /data/vm/win10.qcow2 150G
```

```bash
virt-install --name win10-tally --ram 8192 --vcpus 4 --disk path=/data/vm/win10.qcow2,format=qcow2 --os-variant win10 --cdrom /iso/Windows10.iso --network network=default --graphics vnc
```

### Windows VM Configuration
- RAM: **8 GB**
- vCPU: **4**
- RDP Wrapper: **6 concurrent users**
- Applications: **Tally**
- WireGuard Client installed

---

# STEP 5 – Install Docker

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

# STEP 6 – Docker Application Stack

## Core Infrastructure
- Nginx Proxy Manager
- WireGuard (wg-easy)

## Business Applications
- n8n
- Plane
- Odoo
- Frappe / ERPNext

_All services are deployed using Docker Compose under `/opt` and exposed only via HTTPS reverse proxy._

---

# STEP 7 – WireGuard (wg-easy)

- UDP **51820** exposed
- Web UI protected via HTTPS reverse proxy
- No direct IP/port access

Clients:
- Windows 10 VM
- Remote users

---

# STEP 8 – Backup Strategy

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

## Security Highlights

- VPN-only internal access
- HTTPS everywhere
- No public RDP exposure
- Segregated workloads (VM vs containers)

---

## Maintenance

- Monthly OS updates
- Docker image updates
- Backup verification
- VPN peer audit

---

## License

This project is licensed under the **MIT License**.
