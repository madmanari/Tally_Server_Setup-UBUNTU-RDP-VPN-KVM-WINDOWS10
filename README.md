# Tally_Server_Setup-UBUNTU-RDP-VPN-KVM-WINDOWS10
This is repository is to host Tally Server Locally and access from anywhere...

WireGuard is deployed using the wg-easy (jc21) Docker image, with Ubuntu Host as VPN server, Windows 10 VM and external clients as VPN clients, and RDP access to the VM only over VPN.



**
 * Lenovo TS150 – Ubuntu KVM Remote Tally Server
 * Production Setup Guide (wg-easy WireGuard)
 *
 * Host OS      : Ubuntu Server 22.04 LTS
 * VPN Server   : wg-easy (Docker)
 * VM Client    : Windows 10 (KVM)
 * Access       : VPN → RDP → Tally
   


---

Lenovo TS150 – Ubuntu KVM Remote Tally Server

Overview

This repository documents the end-to-end setup of a Lenovo TS150 server running Ubuntu Server 22.04 LTS, hosting a Windows 10 virtual machine using KVM, and providing secure remote access via WireGuard VPN (wg-easy Docker).

Primary use case:

Centralized Tally access

Multi-user RDP (up to 6 users)

VPN-only access (no public RDP)

Simple VPN management via web UI



---

Hardware Configuration

Component	Specification

Server	Lenovo TS150
RAM	16 GB
CPU	Multi-core
SSD 1	OS Disk
SSD 2	VM Data Disk
USB	Backup Disk



---

Disk Layout

SSD 1
 └── Ubuntu Server 22.04 (Host OS)

SSD 2
 └── /data
     └── KVM VM disks (Windows 10)

USB Disk
 └── Backup target (mount → sync → unmount)

--

STEP 1 – Base System Preparation (Fresh Ubuntu)

sudo apt update && sudo apt upgrade -y
sudo reboot

sudo timedatectl set-timezone Asia/Kolkata


---

STEP 2 – Prepare Data Disk (SSD 2)

lsblk

Assume /dev/sdb

sudo parted /dev/sdb --script mklabel gpt
sudo parted /dev/sdb --script mkpart primary ext4 0% 100%
sudo mkfs.ext4 /dev/sdb1

sudo mkdir /data
sudo mount /dev/sdb1 /data

Persist mount:

sudo blkid /dev/sdb1

Edit /etc/fstab:

UUID=XXXX-XXXX  /data  ext4  defaults  0  2

sudo mount -a


---

STEP 3 – Install KVM Virtualization

sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager

sudo systemctl enable libvirtd
sudo systemctl start libvirtd

sudo usermod -aG libvirt,kvm $USER
newgrp libvirt

Verify:

virsh list --all


---

STEP 4 – Create Windows 10 VM

mkdir -p /data/vm
qemu-img create -f qcow2 /data/vm/win10.qcow2 150G

virt-install \
--name win10-tally \
--ram 8192 \
--vcpus 4 \
--disk path=/data/vm/win10.qcow2 \
--os-variant win10 \
--cdrom /iso/Windows10.iso \
--network network=default \
--graphics vnc

Inside Windows:

Install Tally

Install RDP Wrapper

Enable 6 concurrent users

Install WireGuard client



---

STEP 5 – Install Docker (Required for wg-easy)

sudo apt install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo systemctl enable docker
sudo systemctl start docker


---

STEP 6 – Deploy WireGuard using wg-easy (jc21)

Create Directory

mkdir -p /opt/wg-easy
cd /opt/wg-easy

Docker Compose File

nano docker-compose.yml

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


---

Start WireGuard Server

docker compose up -d

Access UI:

http://SERVER_IP:51821


---

STEP 7 – Create VPN Clients (wg-easy UI)

Using the Web UI:

Create client win10-vm

Create clients for remote users

Download configs / QR codes



---

STEP 8 – Configure Windows 10 VM as VPN Client

Inside Windows 10 VM:

1. Install WireGuard for Windows


2. Import client config from wg-easy


3. Connect VPN



Result:

Windows VM joins VPN subnet 10.10.0.0/24

RDP accessible only via VPN IP



---

STEP 9 – External Client Access

Remote users:

Install WireGuard

Import config

Connect VPN

RDP to Windows VM VPN IP


No public RDP exposure required.


---

Network Architecture

Remote User
   │
   └── WireGuard VPN (wg-easy)
           │
           └── Ubuntu Host
                    │
                    └── Windows 10 VM (RDP + Tally)


---

STEP 10 – Backup Strategy (USB Disk)

Manual Backup

sudo mount /dev/sdc1 /mnt/backup
rsync -av /data/ /mnt/backup/data/
sync
sudo umount /mnt/backup


---

Automated Backup (Cron)

sudo crontab -e

0 2 * * * /usr/bin/rsync -av --delete /data/ /mnt/backup/data/


---

Benefits

VPN managed via web UI

No public RDP ports

Encrypted access

Centralized accounting

Simple client onboarding

Low maintenance



---

Maintenance Checklist

Update Ubuntu monthly

Update Windows VM

Update Docker images

Verify VPN clients

Test backups weekly





