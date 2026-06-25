#!/bin/bash

set -e

echo "====================================="
echo "Updating System Packages"
echo "====================================="
sudo apt-get update -y
sudo apt-get upgrade -y

echo "====================================="
echo "Installing Required Packages"
echo "====================================="
sudo apt-get install -y curl wget unzip tar git apt-transport-https ca-certificates gnupg lsb-release

echo "====================================="
echo "Installing Docker"
echo "====================================="
sudo apt-get install -y docker.io

sudo systemctl start docker
sudo systemctl enable docker

sudo usermod -aG docker $USER
sudo chmod 666 /var/run/docker.sock

echo "Docker Version:"
docker --version

echo "====================================="
echo "Installing AWS CLI v2"
echo "====================================="
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

unzip -q awscliv2.zip

sudo ./aws/install --update

echo "AWS CLI Version:"
aws --version

echo "====================================="
echo "Installing kubectl"
echo "====================================="
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

chmod +x kubectl

sudo mv kubectl /usr/local/bin/

echo "kubectl Version:"
kubectl version --client

echo "====================================="
echo "Installing eksctl"
echo "====================================="
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH

curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_${PLATFORM}.tar.gz"

tar -xzf eksctl_${PLATFORM}.tar.gz -C /tmp

sudo mv /tmp/eksctl /usr/local/bin

echo "eksctl Version:"
eksctl version

echo "====================================="
echo "Installing Helm"
echo "====================================="
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "Helm Version:"
helm version

echo "====================================="
echo "Installation Complete"
echo "====================================="

echo ""
echo "IMPORTANT:"
echo "Logout and login again for Docker group permissions."
echo "Or run:"
echo "newgrp docker"
echo ""

docker --version
aws --version
kubectl version --client
eksctl version
helm version
