#!/bin/bash
# Bootstrap script for the Jenkins server (Ubuntu 24.04, t3.micro)
set -euxo pipefail

# 2 GB swap: Jenkins + Docker builds need more than the 1 GB RAM on t3.micro
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y openjdk-17-jre-headless ca-certificates curl gnupg git

# Jenkins LTS
curl -fsSL https://pkg.jenkins.io/debian-lts/jenkins.io-2023.key -o /usr/share/keyrings/jenkins-keyring.asc
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-lts binary/" > /etc/apt/sources.list.d/jenkins.list
apt-get update -y
apt-get install -y jenkins

# Docker Engine + compose plugin (official convenience script)
curl -fsSL https://get.docker.com | sh

# Let Jenkins and ubuntu run docker
usermod -aG docker jenkins
usermod -aG docker ubuntu

systemctl enable --now docker
systemctl enable jenkins
systemctl restart jenkins
