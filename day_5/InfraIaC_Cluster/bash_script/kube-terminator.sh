#!/bin/bash

# Modo fail-safe: erros não encerram o script
set +e

echo "=== ☢️ INICIANDO EXTERMÍNIO TOTAL DO KUBERNETES (DEBIAN 12) ==="

# === [1] Parar e desabilitar serviços ===
echo "===> [1/11] Parando e desabilitando serviços..."

SERVICES=("kubelet" "containerd")

for svc in "${SERVICES[@]}"; do
    if systemctl list-unit-files | grep -q "^$svc.service"; then
        echo " -> Parando e desabilitando $svc"
        systemctl stop "$svc"
        systemctl disable "$svc"
    else
        echo " -> Serviço $svc não encontrado, ignorando..."
    fi
done

# === [2] Matar processos relacionados ===
echo "===> [2/11] Matando processos relacionados..."
pkill -f kube
pkill -f etcd
pkill -f containerd
pkill -f flanneld

# === [3] Remover pacotes instalados ===
echo "===> [3/11] Removendo pacotes instalados..."
apt-get purge -y kubeadm kubectl kubelet kubernetes-cni cri-tools containerd
apt-get autoremove -y
snap remove microk8s

# === [4] Remover binários manuais ===
echo "===> [4/11] Removendo binários manuais..."
rm -f /usr/local/bin/{kubeadm,kubectl,kubelet,etcd,crictl}
rm -f /usr/bin/{kubeadm,kubectl,kubelet,etcd,crictl}

# === [5] Limpar containerd ===
echo "===> [5/11] Limpando containerd..."
if command -v ctr >/dev/null 2>&1; then
    ctr -n k8s.io containers list -q | xargs -r ctr -n k8s.io containers rm
    ctr -n k8s.io snapshots list -q | xargs -r ctr -n k8s.io snapshots rm
    ctr -n k8s.io images list -q | xargs -r ctr -n k8s.io images rm
fi
rm -rf /var/lib/containerd /etc/containerd /run/containerd

# === [6] Limpar diretórios e arquivos relacionados ===
echo "===> [6/11] Limpando arquivos e diretórios..."
rm -rf ~/.kube ~/.minikube ~/.k3d ~/.kind ~/.k0s ~/.k9s
rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd
rm -rf /etc/cni /opt/cni /run/flannel
rm -rf /etc/systemd/system/kubelet.service.d
rm -rf /etc/docker /var/lib/docker /var/run/docker.sock

# === [7] Deletar interfaces de rede ===
echo "===> [7/11] Limpando interfaces de rede..."
for iface in cni0 flannel.1 docker0; do
    if ip link show "$iface" &>/dev/null; then
        echo " -> Removendo interface $iface"
        ip link delete "$iface"
    fi
done

# === [8] Limpar firewall: nftables e iptables ===
echo "===> [8/11] Limpando firewall (nftables + iptables)..."

# nftables (nativo no Debian 12)
if command -v nft >/dev/null 2>&1; then
    echo " -> Limpando regras do nftables"
    nft flush ruleset
fi

# iptables (modo compatível)
if command -v iptables >/dev/null 2>&1; then
    echo " -> Limpando regras do iptables"
    iptables -F
    iptables -t nat -F
    iptables -t mangle -F
    iptables -X
    iptables -t nat -X
    iptables -P FORWARD ACCEPT
fi

# === [9] Limpar logs ===
echo "===> [9/11] Limpando logs..."
journalctl --rotate
journalctl --vacuum-time=1s
rm -rf /var/log/pods /var/log/containers /var/log/kube* /var/log/etcd

# === [10] Fechar processos usando portas conhecidas do K8s ===
echo "===> [10/11] Checando e liberando portas ocupadas..."
PORTS=(6443 2379 2380 10250 10251 10252 10255)
for port in "${PORTS[@]}"; do
    pid=$(lsof -iTCP -sTCP:LISTEN -Pn | grep ":$port" | awk '{print $2}' | uniq)
    if [ -n "$pid" ]; then
        echo " -> Porta $port usada por PID $pid. Matando..."
        kill -9 "$pid"
    fi
done

# === [11] Restaurar resolv.conf se necessário ===
echo "===> [11/11] Restaurando DNS (se necessário)..."
if [ ! -s /etc/resolv.conf ] || ! grep -q "nameserver" /etc/resolv.conf; then
    echo " -> Restaurando /etc/resolv.conf padrão"
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
else
    echo " -> DNS parece estar OK"
fi

echo "=== ✅ LIMPEZA COMPLETA CONCLUÍDA ==="
echo "🔁 Recomenda-se reiniciar o sistema: sudo reboot"
