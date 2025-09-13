#!/bin/bash

set -euo pipefail

echo "=== [1/9] Parando serviços Kubernetes e containerd... ==="
sudo systemctl stop kubelet 2>/dev/null || true
sudo systemctl stop containerd 2>/dev/null || true

echo "=== [2/9] Matando processos relacionados a Kubernetes e containerd... ==="
pkill -f kube 2>/dev/null || true
pkill -f etcd 2>/dev/null || true
pkill -f containerd 2>/dev/null || true
pkill -f cri-containerd 2>/dev/null || true

echo "=== [3/9] Limpando containers e snapshots do containerd... ==="
sudo ctr -n k8s.io containers list -q | xargs -r sudo ctr -n k8s.io containers rm
sudo ctr -n k8s.io snapshots list -q | xargs -r sudo ctr -n k8s.io snapshots rm
sudo ctr -n k8s.io images list -q | xargs -r sudo ctr -n k8s.io images rm

echo "=== [4/9] Limpando pods via crictl (se disponível)... ==="
if command -v crictl >/dev/null 2>&1; then
    sudo crictl pods -q | xargs -r sudo crictl stopp
    sudo crictl pods -q | xargs -r sudo crictl rmp
    sudo crictl rmi --prune
    sudo crictl ps -a -q | xargs -r sudo crictl rm
fi

echo "=== [5/9] Limpando diretórios de configuração e dados... ==="
sudo rm -rf ~/.kube ~/.k3s ~/.kind ~/.minikube
sudo rm -rf /etc/kubernetes /var/lib/etcd /var/lib/kubelet
sudo rm -rf /run/containerd /var/lib/containerd /etc/cni /opt/cni

echo "=== [6/9] Limpando iptables... ==="
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X
sudo iptables -t nat -X

echo "=== [7/9] Limpando redes CNI e bridge... ==="
sudo ip link delete cni0 2>/dev/null || true
sudo ip link delete flannel.1 2>/dev/null || true
sudo ip link delete docker0 2>/dev/null || true

echo "=== [8/9] Checando e liberando portas conhecidas do Kubernetes... ==="
K8S_PORTS=(6443 2379 2380 10250 10251 10252 10255)
for port in "${K8S_PORTS[@]}"; do
    pid=$(sudo lsof -iTCP -sTCP:LISTEN -Pn | grep ":$port" | awk '{print $2}' | uniq)
    if [ -n "$pid" ]; then
        echo "Porta $port ocupada por PID $pid. Matando..."
        sudo kill -9 "$pid"
    fi
done

echo "=== [9/9] Reiniciando containerd (opcional)... ==="
read -p "Deseja reiniciar o containerd? (s/n): " resp
if [[ "$resp" =~ ^[Ss]$ ]]; then
    sudo systemctl start containerd
fi

echo "=== ✅ Ambiente Kubernetes com containerd foi sanitizado. ==="
