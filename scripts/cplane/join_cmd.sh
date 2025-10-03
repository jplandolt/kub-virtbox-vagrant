#!/usr/bin/env bash

echo "Cluster worker join command (requires sudo):"
echo ""
echo "--------------------------------------------------"
echo -n "sudo "
sudo kubeadm token create --print-join-command
echo "--------------------------------------------------"
echo ""

