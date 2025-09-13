#/bin/bash
set -e

K8S_VERSION="v1.29"

echo "🔧 Atualizando pacotes e instalando dependências..."
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg lsb-release software-properties-common

# Baixar chave GPG do novo repositório
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | \
gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Adicionar repositório Kubernetes
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | \
tee /etc/apt/sources.list.d/kubernetes.list


echo "📦 Instalando kubelet..."
sudo apt-get update
sudo apt-get install -y kubelet kubeadm
sudo apt-mark hold kubelet kubeadm

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

echo "🌉 Configurando bridge network para iptables..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

echo "✅ Nó worker pronto para executar kubeadm join!"
