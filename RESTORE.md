# Steps to restore the MAAP ADE from an EBS Snapshot

When restoring the MAAP ADE from a snapshot, additional steps are required if a new DNS is being used for the 
restored version. These steps are noted below.

### Step 1) Configure microk8s and iptables

```bash

sudo microk8s.enable ingress; sleep 5;
sudo microk8s.enable storage; sleep 5;
sudo microk8s.enable dns

sudo iptables -P INPUT ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -P FORWARD ACCEPT # for dns propogation
sudo iptables -F

cd che/deploy/kubernetes/helm/che
```

### Step 2) [NEW DNS ONLY] Edit the host file


```bash

vi /etc/host
## update file with the public DNS of the host EC2 instance

```

### Step 3) [NEW DNS ONLY] Update helm with new DNS

```bash
sudo helm upgrade che che --namespace default --set global.multiuser=true --set global.serverStrategy=single-host --set global.ingressDomain=<public.DNS.of.host> --set global.tls.enabled=true --set global.tls.useCertManager=true --set global.tls.useStaging=false --set tls.secretName=che-tls --set global.metricsEnabled=true —-dry-run
```

### Step 4) Restart microk8s

```bash
microk8s.stop
microk8s.start
```
