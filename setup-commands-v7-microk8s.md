# Eclipse Che 7 with MicroK8S and EFS
This installation will create the MAAP ADE with Eclipse Che 7 in `single-host` mode. It uses an NFS volume for its persistent Kubernetes volumes.

## Configure EC2 instance
The cluster node will be an EC2 instance of the type `r5.8xlarge`  running `Ubuntu 18.04` with 100GB `gp3` in the EBS root volume.

## OS Configuration
```shell
sudo apt-get update
sudo apt-get -y dist-upgrade

# Allows DNS progagation. In GCC, since it won't let us use alternative DNSs, this doesn't really matter but just to be consistent.
sudo iptables -P INPUT ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -P FORWARD ACCEPT # for dns propogation
sudo iptables -F
sudo apt-get install -y iptables-persistent

# [FS-CACHE for NFS clients | Frederik's Blog](https://blog.frehi.be/2019/01/03/fs-cache-for-nfs-clients/)
sudo apt-get install -y nfs-common cachefilesd
# uncomment RUN="yes" in /etc/default/cachefilesd
sudo service cachefilesd start
```

## Set up /etc/fstab for the NFS mount
```shell
sudo mkdir /efs
# get mount target
echo "$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone).fs-<EFSID>.efs.us-west-2.amazonaws.com"
# add the following line to the /etc/fstab file: 

    <mount-target-DNS>:/ /efs nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev,fsc 0 0`

# [Additional mounting considerations - Amazon Elastic File System](https://docs.aws.amazon.com/efs/latest/ug/mounting-fs-mount-cmd-general.html)
sudo mount -a
```

## MicroK8S Snap Installation
```shell
sudo snap install microk8s --classic --channel=1.20/stable
sudo snap alias microk8s.kubectl kubectl # Alias kubectl, required for chectl
# Snap update required for the libseccomp library
sudo snap refresh 

sudo mkdir -p ~/.kube
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube
sudo microk8s.config | cat - > $HOME/.kube/config
# Log out and back in

# Install cilium, it solves networking in GCC. First, wait until calico is fully initialied by looking at the pods.
sudo microk8s.enable helm3
sudo microk8s.enable cilium # may need to wait several minutes, be patient
sudo ip link delete vxlan.calico
# Following allows clustering to work, i.e. microk8s add-node/join, with cilium.
sudo cp -np /var/snap/microk8s/current/args/cni-network/cni.yaml.disabled /var/snap/microk8s/current/args/cni-network/cni.yaml.calico
sudo cp -p /var/snap/microk8s/current/actions/cilium.yaml /var/snap/microk8s/current/args/cni-network/cni.yaml

# Update /etc/hosts to add the ade hostname as localhost so that it doesn't hairpin

# STOP HERE if this node is going to be a worker node.

sudo microk8s.enable storage; sleep 1;

# Install NFS provisioner
sudo microk8s.helm3 repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
sudo microk8s.helm3 install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server=<ipaddr of efs as nfs> \
    --set nfs.path=/

# Set NFS provisioner as default
kubectl patch storageclass microk8s-hostpath -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
kubectl patch storageclass nfs-client -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

sudo microk8s.enable ingress; sleep 5;
sudo microk8s.enable dns:10.49.0.2; sleep 5; # needed for GCC as it blocks dns queries other than the local resolver
# sudo microk8s.enable dns; sleep 5; # needed any normal cluster
sudo microk8s.enable registry

# Edit ingress daemonset to set ingress class back to nginx, change `--ingress-class=public` to `--ingress-class=nginx`. Not sure why it's called public in 1.20, but it breaks the default settings in other components if it's not `nginx`
kubectl edit daemonset -n ingress nginx-ingress-microk8s-controller

# Set up the microk8s cluster. This sequence of steps should be run for each worker node you want to add to the cluster. 
# Run this command on the head machine
microk8s add-node 
# The following output should return. Run this on a worker machine:
microk8s join <master>:<port>/<token>
# Once all worker machines are joined, verify the nodes are listed:
kubectl get nodes 

# Create a new namespace for the cert-manager
kubectl create namespace cert-manager

# Apply the official yaml file 
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.2.0/cert-manager.yaml

# Install chectl
bash <(curl -sL  https://www.eclipse.org/che/chectl/)

wget https://raw.githubusercontent.com/MAAP-Project/maap-eclipseche-ops/master/che7/maap-k8sconfig-patch.yaml
wget https://raw.githubusercontent.com/MAAP-Project/maap-eclipseche-ops/master/che7/nfs-client-che-sc.yaml
wget https://raw.githubusercontent.com/MAAP-Project/maap-eclipseche-ops/master/che7/microk8s/prod.yaml 
wget https://raw.githubusercontent.com/MAAP-Project/maap-eclipseche-ops/master/che7/microk8s/ingress-prd.yaml 
# (updated domain in ingress-prd.yaml)

kubectl apply -f prod.yaml
kubectl apply -f ingress-prd.yaml

# Ensure the following returns a value of 'True' before proceeding
kubectl get cert

# Deploy nfs-client-che storage class
kubectl apply -f nfs-client-che-sc.yaml

# Verify microk8s.status, chectl uses this to verify that microk8s is running. If the following command takes too long, set permissions
# [microk8s.status takes forever (almost 2 minutes) as user but not as sudo · Issue #884 · ubuntu/microk8s · GitHub](https://github.com/ubuntu/microk8s/issues/884)
microk8s.status

# Deploy Che
chectl server:deploy --installer=operator --platform=microk8s --che-operator-cr-patch-yaml=maap-k8sconfig-patch.yaml --multiuser --domain={REPLACE_ME} 


# If needed by IT security, do the following

# Ensure http requests are signed in spec/template/spec/containers/args
kubectl  edit daemonset nginx-ingress-microk8s-controller -n ingress
#  - --default-ssl-certificate=default/default-tls-secret

# Add the following annotation to ensure that *all* http requests are forwarded to https
kubectl  edit ingress
# In metadata/annotations, add:
# nginx.ingress.kubernetes.io/force-ssl-redirect: "true"

# Disable automatic snap updates to prevent unexpected cluster outages
sudo systemctl stop snapd.service
sudo systemctl stop snapd.socket
sudo systemctl mask snapd.service
sudo systemctl mask snapd.socket

# DONE!
```

# Resetting MicroK8S
```shell
# Remove node from cluster if it's in a clustered configuration
sudo microk8s leave
sudo microk8s remove-node...

sudo microk8s.reset
sudo snap remove microk8s --purge
sudo rm -rf ~/.kube
sudo rm -rf /var/snap/microk8s
sudo rm -rf ~/snap/microk8s
sudo rm -rf /root/snap/microk8s
sudo ip addr
# Accept all traffic first to avoid ssh lockdown  via iptables firewall rules #
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -F
sudo iptables -X
sudo iptables -Z 
# sudo ip link delete <device> any orphaned network, i.e. things that have `cilium` or `calico` in them
```

# Upgrading MicroK8S

Upgrading MicroK8S is a little complicated because the networking can get messed up. That's why we disable snap so that it doesn't do it automatically. To perform an updated in a clustered environment.

1. Take note of the current version in `/var/snap/microk8s`. As of this writing with the `1.20/stable`, I am upgrading from version `2143`.
2. Restart the `snapd.service` and `snapd.socket`. You may have to wait a few minutes for this to full start up. Otherwise the `microk8s.leave` will not work.
2. Remove the node to be upgraded from the cluster (make sure the other two nodes are clustered!), following the instructions above in Resetting MicroK8S.
3. Continue to remove the entire MicroK8S installation.
4. Once MicroK8S has been removed, **reboot the instance**. There's a phantom MicroK8S web service that keeps running even after removal. Rebooting ensures that it's not.
5. [Optional] Install any system updates, i.e. apt-get.
6. Reinstall MicroK8S following instructions above, up to the `STOP HERE` for worker nodes.
7. Take note of the new version of MicroK8S. As of this writing, the new version is `2213`. Create a link to the new version from the old version. At the time of this writing, it is `cd /var/snap/microk8s; sudo ln -s 2213 2143`. This lets nginx start properly on the node.
8. Add the node back to one of the nodes of the existing cluster.
