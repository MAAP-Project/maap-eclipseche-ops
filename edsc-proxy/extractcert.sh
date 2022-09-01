#!/bin/bash
# Extracts the letsencrypt certs from kubernetes
CRTFILE="/home/ubuntu/kubessl/default-tls-secret.crt"
KEYFILE="/home/ubuntu/kubessl/default-tls-secret.key"
microk8s.kubectl get secret default-tls-secret -o yaml | grep -P '^\s+tls.crt:' | sed 's/^.*: //' | base64 -d > "$CRTFILE.tmp"
microk8s.kubectl get secret default-tls-secret -o yaml | grep -P '^\s+tls.key:' | sed 's/^.*: //' | base64 -d > "$KEYFILE.tmp"

if [ -s "$CRTFILE.tmp" ] && [ -s "$KEYFILE.tmp" ]
then
    mv "$CRTFILE.tmp" "$CRTFILE"
    mv "$KEYFILE.tmp" "$KEYFILE"
    sudo service apache2 graceful >/dev/null 2>&1
fi
