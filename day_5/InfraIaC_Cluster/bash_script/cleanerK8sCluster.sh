#!/bin/bash

set -euo pipefail

echo ">>> INICIANDO SANITIZAÇÃO COMPLETA DO CLUSTER KUBERNETES <<<"

# Verificação de root
if [[ "$EUID" -ne 0 ]]; then
  echo "Este script deve ser executado como root (use sudo)." >&2
  exit 1
fi

# Confirmação
read -rp "ATENÇÃO: Isso irá DESTRUIR o cluster atual e apagar todos os dados. Deseja continuar? (s/n): " confirm
if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
  echo "Operação cancelada."
  exit 0
fi

echo ">>> Parando serviços relacionados ao Kubernetes..."
systemctl stop kubelet || true
systemctl stop containerd || true
systemctl stop docker || true

echo ">>> Limpando configuração local do kubectl..."
rm -rf ~/.kube

echo ">>> Resetando o cluster com kubeadm..."
kubeadm reset -f || true

echo ">>> Removendo configurações e dados remanescentes do cluster..."

# Removendo arquivos e diretórios relevantes
rm -rf /etc/kubernetes/
rm -rf /var/lib/etcd
rm -rf /var/lib/kubelet/*
rm -rf /etc/cni/
rm -rf /opt/cni/
rm -rf /var/lib/cni/
rm -rf /run/flannel/
rm -rf /var/run/calico/
rm -rf /var/lib/calico/
rm -rf /etc/kubelet*
rm -rf /etc/systemd/system/kubelet.service.d
rm -rf /etc/systemd/system/kubelet.service

# Também remove arquivos de binários kube*, se desejado
# rm -f /usr/bin/kubeadm /usr/bin/kubelet /usr/bin/kubectl

echo ">>> Limpando interfaces de rede criadas pelo Kubernetes/CNI..."
for intf in cni0 flannel.1 docker0 kube-ipvs0; do
  ip link delete "$intf" 2>/dev/null || true
done

echo ">>> Limpando IPTABLES..."
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X

echo ">>> Limpando IPVS..."
ipvsadm --clear 2>/dev/null || true

echo ">>> Limpando arquivos residuais de container runtimes..."
rm -rf /var/lib/docker/*
rm -rf /var/lib/containerd/*
rm -rf /var/log/pods/*
rm -rf /var/log/containers/*

echo ">>> Recarregando systemd e reiniciando serviços essenciais..."
systemctl daemon-reexec
systemctl daemon-reload

systemctl start containerd || true
systemctl start docker || true
systemctl start kubelet || true

echo "✅ SANITIZAÇÃO CONCLUÍDA!"
echo "Sistema pronto para um novo 'kubeadm init'."
