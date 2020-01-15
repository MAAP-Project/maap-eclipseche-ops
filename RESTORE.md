# Steps to restore the MAAP ADE from an EBS Snapshot

When restoring the MAAP ADE from a snapshot, additional steps are required if a new DNS is being used for the 
restored version. These steps are noted below.

### Step 1) Backup Docker ephemeral workspace data

When Eclipse Che is first started, any running workspaces that were not stopped prior to a server shut down are started in a disconnected state from the host Kubernetes service. It is in this state that we must backup any data that exists outside of the persisted 'projects' volume.  Once a workspace is restarted, any of this ephemeral data is permanently deleted. 

Once workspace containers are started in the disconnected state, we need to get a list of workspaces that require backup. 

```bash
microk8s.docker ps | grep workspace
```

Find the local file path on the host container by running

```bash
microk8s.docker inspect <workspace container id>
```

The local path can be found under the `GraphData.data.UpperDir` node. Append this path to to the `/var/snap/microk8s/common/var/lib` directory to locate any ephemeral data in this workspace.

*Step 1 TODO:* develop a scripted routine to back up all ephemeral data of any user workspaces on server startup.

### Step 2) [NEW DNS ONLY] Edit the host file and enable microk8s features

```bash

vi /etc/host
## update file with the public DNS of the host EC2 instance

sudo microk8s.enable ingress; sleep 5;
sudo microk8s.enable storage; sleep 5;
sudo microk8s.enable dns

```

### Step 3) Configure iptables

```bash

sudo iptables -P INPUT ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -P FORWARD ACCEPT # for dns propogation
sudo iptables -F

```

### Step 4) [NEW DNS ONLY] Update helm with new DNS

```bash
ade_host='?'

sudo helm upgrade --install che --namespace default --set global.multiuser=true --set global.serverStrategy=single-host --set global.ingressDomain=$ade_host --set global.tls.enabled=true --set global.tls.useCertManager=true --set global.tls.useStaging=false --set tls.secretName=che-tls --set global.metricsEnabled=true —-dry-run
```

### Step 5) Restart microk8s

```bash
microk8s.stop
microk8s.start
```
