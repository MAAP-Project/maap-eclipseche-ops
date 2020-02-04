## Command sequence for installing and configuring Eclipse Che

```bash
# The host name for the ADE server.
ade_host='?'

sudo apt-get update
sudo apt-get -y dist-upgrade
sudo snap install microk8s --classic --channel=1.13/stable
sudo snap install helm --classic --channel=2.15/stable

git clone https://mas.maap-project.org/root/che
cd che/deploy/kubernetes/helm/che
# yaml default values can be used as-is or updated as needed

sudo microk8s.enable ingress; sleep 5;
sudo microk8s.enable storage; sleep 5;
sudo microk8s.enable dns

sudo iptables -P INPUT ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -P FORWARD ACCEPT # for dns propogation
sudo iptables -F
sudo apt-get install iptables-persistent

sudo microk8s.kubectl create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:default
sudo microk8s.kubectl create serviceaccount tiller --namespace kube-system
sudo microk8s.kubectl apply -f ./tiller-rbac.yaml
sudo helm init --service-account tiller --wait

# Get latest cert-manager, https://docs.cert-manager.io/en/latest/getting-started/install/kubernetes.html
sudo microk8s.kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.10/deploy/manifests/00-crds.yaml
sudo microk8s.kubectl label namespace default certmanager.k8s.io/disable-validation=true

sudo helm repo add jetstack https://charts.jetstack.io
sudo helm repo update
sudo helm dependency update

# Install certs
sudo helm install --name cert-manager --version v0.12.0 jetstack/cert-manager --set createCustomResource=false
sudo helm upgrade --install cert-manager jetstack/cert-manager --set createCustomResource=true --version 0.10.1
sudo helm upgrade --install che --namespace default --set global.multiuser=true --set global.serverStrategy=single-host --set global.ingressDomain=$ade_host --set global.tls.enabled=true --set global.tls.useCertManager=true --set global.tls.useStaging=false --set tls.secretName=che-tls --set global.metricsEnabled=true ./

# Enable privileges
/var/snap/microk8s/current/args/kubelet
/var/snap/microk8s/current/args/kube-apiserver
append --allow-privileged
restart both services:
sudo systemctl restart snap.microk8s.daemon-apiserver
sudo systemctl restart snap.microk8s.daemon-kubelet



# To completely reset the system (you probably don't need this):
sudo helm del --purge che
sudo microk8s.reset
sudo snap remove microk8s --purge
sudo snap remove helm --purge
sudo rm -rf ~/.helm/
sudo rm -rf ~/snap/

# Why we don't use Kubernetes 1.16 and stay on 1.13/stable
https://github.com/ubuntu/microk8s/issues/198
https://github.com/helm/helm/issues/6374
```
