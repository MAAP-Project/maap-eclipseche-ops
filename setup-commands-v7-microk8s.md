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
# add `<mount-target-DNS>:/ /efs nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev,fsc 0 0` to /etc/fstab
# [Additional mounting considerations - Amazon Elastic File System](https://docs.aws.amazon.com/efs/latest/ug/mounting-fs-mount-cmd-general.html)
sudo mount -a
```

## MicroK8S Snap Installation
```shell
sudo snap install microk8s --classic --channel=1.20/stable
sudo snap install kubectl --classic --channel=1.20/stable  # Install kubectl, required for chectl
# Snap update required for the libseccomp library
sudo snap refresh 

sudo mkdir ~/.kube
sudo usermod -a -G microk8s ubuntu
sudo chown -f -R ubuntu ~/.kube
sudo microk8s.config | cat - > $HOME/.kube/config
# Log out and back in

# Install cilium, it solves networking in GCC. First, wait until calico is fully initialied by looking at the pods.
sudo microk8s.enable helm3
sudo microk8s.enable cilium # may need to wait several minutes, be patient
sudo ip link delete vxlan.calico
# Following allows clustering to work, i.e. microk8s add-node/join, with cilium.
sudo cp /var/snap/microk8s/2074/actions/cilium.yaml /var/snap/microk8s/2074/args/cni-network/cni.yaml

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
microk8s.kubectl edit daemonset -n ingress nginx-ingress-microk8s-controller

# Set up cluster at this point
microk8s add-node # on head machine
microk8s join... # on worker machine
microk8s.kubectl get nodes # verify!

# Create a new namespace for the cert-manager
microk8s.kubectl create namespace cert-manager

# Apply the official yaml file 
microk8s.kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.2.0/cert-manager.yaml

# Install chectl
bash <(curl -sL  https://www.eclipse.org/che/chectl/)

wget https://raw.githubusercontent.com/MAAP-Project/maap-eclipseche-ops/master/che7/maap-k8sconfig-patch.yaml
wget https://raw.githubusercontent.com/MAAP-Project/maap-eclipseche-ops/master/che7/microk8s/prod.yaml 
wget https://raw.githubusercontent.com/MAAP-Project/maap-eclipseche-ops/master/che7/microk8s/ingress-prd.yaml 
# (updated domain in ingress-prd.yaml)

microk8s.kubectl apply -f prod.yaml
microk8s.kubectl apply -f ingress-prd.yaml

# Ensure the following returns a value of 'True' before proceeding
microk8s.kubectl get cert

# Deploy nfs-client-che storage class
microk8s.kubectl apply -f nfs-client-che-sc.yaml

# Verify microk8s.status, chectl uses this to verify that microk8s is running. If the following command takes too long, set permissions
# [microk8s.status takes forever (almost 2 minutes) as user but not as sudo · Issue #884 · ubuntu/microk8s · GitHub](https://github.com/ubuntu/microk8s/issues/884)
microk8s.status

# Deploy Che
chectl server:deploy --installer=operator --platform=microk8s --che-operator-cr-patch-yaml=maap-k8sconfig-patch.yaml --multiuser --domain={REPLACE_ME} 

kubectl edit daemonset nginx-ingress-microk8s-controller -n ingress   
# If needed by IT security, add the following setting to ensure http requests are signed in spec/template/spec/containers/args
#  - --default-ssl-certificate=default/default-tls-secret
# If needed by IT security, add the following annotation to ensure that *all* http requests are forwarded to https
# nginx.ingress.kubernetes.io/force-ssl-redirect: "true"

# DONE!
```

# Resetting MicroK8S
```
# Remove node from cluster if it's in a clustered configuration
sudo microk8s leave
sudo microk8s remove-node...

sudo microk8s.reset
sudo snap remove microk8s --purge
sudo snap remove kubectl --purge
sudo rm -rf ~/.kube
sudo rm -rf /var/snap/microk8s
sudo rm -rf /var/snap/kubectl
sudo rm -rf ~/snap/microk8s
sudo rm -rf ~/snap/kubectl
sudo rm -rf /root/snap/microk8s
sudo rm -rf /root/snap/kubectl
# sudo ip addr
# sudo ip link delete <device> any orphaned network, i.e. things that have `cilium` or `calico` in them
```
