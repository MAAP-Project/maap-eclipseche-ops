# Steps to restore the MAAP ADE from an EBS Snapshot

When restoring the MAAP ADE from a snapshot, additional steps are required if a new DNS is being used for the 
restored version. These steps are noted below.

### Step 1) Backup Docker ephemeral workspace data

In order to restore ephemeral workspace data, we rely on [Docker's OverlayFS Storage Driver](https://docs.docker.com/storage/storagedriver/overlayfs-driver/) to record the precise mappings from running workspaces to their corresponding host directories. A list of these mappings are captured using our [log-docker-container-directories.sh](log-docker-container-directories.sh). This script records the name of each running workspace and the `UpperDir` path of its running Docker container.

This script must run at regular intervals of no longer than once per hour on the ADE.

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

### Step 6) Restore any ephemeral workspace data from the most recent ADE snapshot

- Mount the ADE snapshot as a separate volume on the restarted ADE server
- Run the [docker-container-restore.sh](docker-container-restore.sh) script using the last mappings file generated from Step 1).

Example restore command:

```bash
./docker-container-restore.sh -t container-table-20200128_052001.log
```

Example restore output:

```
Restoring workspaces

1) /k8s_jupyter_workspace44gqlvllnmjd6zrg.ws-7f77884dc9-f5gdj_workspace44gqlvllnmjd6zrg_12dc53e0-3d76-11ea-8ddb-0eb70ec59768_0
  source folder /var/snap/microk8s/common/var/lib/docker/overlay2/6f2ea109cfed5b808f0d2091ec4a7d965477e679225dc1e1e6fb442921c0bd6b/diff
  container e423c78c8408
  restored to folder /restore-20200128_183523
2) /k8s_jupyter_workspacel6fugha3w6g1k7i3.ws-76598784d9-nbhkp_workspacel6fugha3w6g1k7i3_a01c26cc-3d70-11ea-8ddb-0eb70ec59768_0
  source folder /var/snap/microk8s/common/var/lib/docker/overlay2/0fcfdf9f6c122851ad42022a5a5c67a61c0568aeb78c83429ccae5bb62ee6d50/diff
  container b9b6878a0769
  restored to folder /restore-20200128_183527
3) /k8s_jupyter_workspacen85gyo8cus57h0e6.ws-799768c4cf-7w7l5_workspacen85gyo8cus57h0e6_bc6a5003-3d6b-11ea-8ddb-0eb70ec59768_0
  source folder /var/snap/microk8s/common/var/lib/docker/overlay2/c79f6ab6233271890dc225737298df391cb5683cd6505ce8b9f4ca884ff84f85/diff
  container 1571506beff1
  restored to folder /restore-20200128_183530
4) /k8s_jupyter_workspaceya6zcig9w1v8jjdp.ws-58cd77f667-zmdm9_workspaceya6zcig9w1v8jjdp_1541dd56-3d56-11ea-8ddb-0eb70ec59768_1
  source folder /var/snap/microk8s/common/var/lib/docker/overlay2/ab17ee0e54616d4ba05030f77958b2ac97c30f15f9308c4b17106470f3a58cd9/diff
  container fe2aa9572f28
  restored to folder /restore-20200128_183534
5) /k8s_jupyter_workspaceavoiy0vb1wjsmbi7.ws-967c6d5b8-spz7s_workspaceavoiy0vb1wjsmbi7_3a7a0afa-389f-11ea-8ddb-0eb70ec59768_0
  source folder /var/snap/microk8s/common/var/lib/docker/overlay2/d112418c1d9affd7c9be0d0f4d67e2a2c6d27ccd3bfddd69b4f4e3041a94fd39/diff
  container a99745068640
  restored to folder /restore-20200128_183535
6) /k8s_jupyter_workspaceiiadxylshjh6ux79.ws-556988b8d-lb467_workspaceiiadxylshjh6ux79_f6a76875-367e-11ea-8ddb-0eb70ec59768_0
  source folder /var/snap/microk8s/common/var/lib/docker/overlay2/f87f9e0b921057a10582ed2ccf3009ec29d2c82ae155f9ad57a0cf7a28cb82da/diff
  container 363d091bcc10
  restored to folder /restore-20200128_183538
7) /k8s_jupyter_workspace0af8xisf15too81b.ws-78b4fb59d8-dgl5t_workspace0af8xisf15too81b_2fd9b894-364f-11ea-8ddb-0eb70ec59768_0
  source folder /var/snap/microk8s/common/var/lib/docker/overlay2/5c6d8ced047e8b387ee85305316d334bc039dc481a8207e9d4af20aa4368c20e/diff
  container 2c5f11cd7050
  restored to folder /restore-20200128_183542
 ```
