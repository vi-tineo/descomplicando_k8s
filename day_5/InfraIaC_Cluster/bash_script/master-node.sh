#!/bin/bash
set -e

K8S_VERSION="v1.29"

echo "🔧 Atualizando pacotes e instalando dependências..."
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg lsb-release software-properties-common

echo "🔐 Adicionando chave GPG do Kubernetes..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "📦 Adicionando repositório do Kubernetes..."
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

echo "📦 Instalando kubelet, kubeadm e kubectl..."
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "📦 Instalando containerd..."
sudo apt-get install -y containerd

echo "⚙️ Configurando containerd..."
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "🚫 Desativando swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "🌉 Carregando módulo br_netfilter..."
sudo modprobe br_netfilter
echo "br_netfilter" | sudo tee /etc/modules-load.d/k8s.conf

echo "📐 Configurando parâmetros de rede exigidos pelo Kubernetes..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

echo "🔄 Aplicando configurações de rede..."
sudo sysctl --system
sudo systemctl restart systemd-sysctl

echo "✅ Nó controller pronto para iniciar o cluster com kubeadm init!"
