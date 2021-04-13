#!/bin/bash
# Extracts the letsencrypt certs from kubernetes
microk8s.kubectl get secret default-tls-secret -o yaml | grep -P '^\s+tls.crt:' | sed 's/^.*: //' | base64 -d > /home/ubuntu/kubessl/default-tls-secret.crt
microk8s.kubectl get secret default-tls-secret -o yaml | grep -P '^\s+tls.key:' | sed 's/^.*: //' | base64 -d > /home/ubuntu/kubessl/default-tls-secret.key
