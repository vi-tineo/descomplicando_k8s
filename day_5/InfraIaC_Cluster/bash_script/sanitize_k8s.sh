#!/bin/bash

sudo kubeadm reset -f
sudo systemctl stop kubelet
sudo systemctl stop containerd  # ou docker, dependendo do seu runtime

sudo rm -rf /etc/cni/net.d
sudo rm -rf /var/lib/cni/
sudo rm -rf /var/lib/kubelet/*
sudo rm -rf /etc/kubernetes/
sudo ip link delete cni0 2>/dev/null
sudo ip link delete flannel.1 2>/dev/null

sudo reboot
