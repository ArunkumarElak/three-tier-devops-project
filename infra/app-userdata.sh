#!/bin/bash
# Bootstrap script for the application server (Ubuntu 24.04, t3.micro)
set -euxo pipefail

# 1 GB swap headroom for MySQL + Node on 1 GB RAM
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl git

# Docker Engine + compose plugin
curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu
systemctl enable --now docker

# Directory the pipeline deploys into
mkdir -p /opt/app
chown ubuntu:ubuntu /opt/app
