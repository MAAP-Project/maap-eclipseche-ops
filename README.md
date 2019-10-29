# MAAP Eclipse Che Operations Guide

This guide is intended to provide devops members of MAAP instructions for configuring and deploying the MAAP ADE.

## Intended Use

These instructions have been tested on EC2 VMs running Ubuntu 18.04. 

### Command sequence for installing and configuring Eclipse Che

```bash
sudo apt-get update
sudo apt-get -y dist-upgrade
sudo snap install microk8s --classic --channel=1.13/stable
sudo snap install helm --classic --channel=stable

git clone https://github.com/eclipse/che
cd che/deploy/kubernetes/helm/che
git checkout tags/6.19.6
git branch 6.19.6-maap
# update yaml as needed

sudo microk8s.enable ingress; sleep 5;
sudo microk8s.enable storage; sleep 5;
sudo microk8s.enable dns

sudo iptables -P INPUT ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -P FORWARD ACCEPT # for dns propogation
sudo iptables -F

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

# Install certs, remember to update with real email in yaml file. Also update to v2 of acme: https://acme-v02.api.letsencrypt.org/directory
sudo helm install --name cert-manager jetstack/cert-manager --set createCustomResource=false
sudo helm upgrade --install cert-manager jetstack/cert-manager --set createCustomResource=true --version 0.10.1
sudo helm upgrade --install che --namespace default --set global.multiuser=true --set global.serverStrategy=single-host --set global.ingressDomain=ade.maap-project.org --set global.tls.enabled=true --set global.tls.useCertManager=true --set global.tls.useStaging=false --set tls.secretName=che-tls ./

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

### Configuration for Nginx Ingress Controller

By default, MicroK8s installs a temporary, insecure ssl certificate that needs to be replaced during the [Nginx Ingress](https://github.com/ubuntu/microk8s/blob/1.12/microk8s-resources/actions/ingress.yaml#L66) node startup process. We address this by adding post-start execution commands to point to the secure certificate. Once Che is fully configured, run the following command:

```bash
microk8s.kubectl edit ds/nginx-ingress-microk8s-controller
```

Then, replace the yaml contents with the modified configuration here: [/deployment-templates/nginx-ingress-microk8s-controller.yaml](/deployment-templates/nginx-ingress-microk8s-controller.yaml).

This change will trigger a redployment of the nginx k8s node, at which point the secure certificate will be used anytime the cluster is restarted.
