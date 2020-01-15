# MAAP Eclipse Che Operations Guide

This guide is intended to provide an operational template for configuring and deploying the MAAP ADE.

## Intended Use

These instructions have been tested on EC2 VMs running Ubuntu 18.04. 

### Installation Guide

[INSTALLATION.md](INSTALLATION.md)

### Restoring From Backup

[RESTORE.md](RESTORE.md)

### Restoring From Backup - Test Procedure

[RESTORE_TEST.md](RESTORE_TEST.md)

### Configuration for Nginx Ingress Controller

By default, MicroK8s installs a temporary, insecure ssl certificate that needs to be replaced during the [Nginx Ingress](https://github.com/ubuntu/microk8s/blob/1.12/microk8s-resources/actions/ingress.yaml#L66) node startup process. We address this by adding post-start execution commands to point to the secure certificate. Once Che is fully configured, run the following command:

```bash
microk8s.kubectl edit ds/nginx-ingress-microk8s-controller
```

Then, replace the yaml contents with the modified configuration here: [/deployment-templates/nginx-ingress-microk8s-controller.yaml](/deployment-templates/nginx-ingress-microk8s-controller.yaml).

This change will trigger a redployment of the nginx k8s node, at which point the secure certificate will be used anytime the cluster is restarted.
