```shell
sudo apt-get update
sudo apt-get -y dist-upgrade
sudo snap install microk8s --classic --channel=1.19/stable
# Snap update required for the libseccomp library
sudo snap refresh 

# For GCC, need to install cilium. Currently there's a bug https://github.com/ubuntu/microk8s/issues/1603
# so you'll need to enable it, ctrl-c it when it appears to hang with "0 of 1 updated pods..." (2-3 of these messages)
# Then disable it. Wait a bit, and re-enable it. Make sure that when you re-enable it that it re-downloads
# cilium. If it says it's already enabled, you didn't wait long enough.
sudo microk8s.enable cilium;
sudo microk8s.disable cilium;
# Wait until the command "sudo microk8s.kubectl get pods --all-namespaces" returns only healthy, running pods.
sudo microk8s.enable cilium;
# End GCC

sudo microk8s.enable ingress; sleep 1;
sudo microk8s.enable storage; sleep 1;
sudo microk8s.enable dns; sleep 1;
sudo microk8s.enable registry

sudo iptables -P INPUT ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -P FORWARD ACCEPT # for dns propogation
sudo iptables -F
sudo apt-get install iptables-persistent

# Install kubectl, required for chectl
sudo snap install kubectl --classic 
sudo usermod -a -G microk8s ubuntu
sudo chown -f -R ubuntu ~/.kube
[log back in]

microk8s.config | cat - > $HOME/.kube/config

##### If deploying to GCC:
# note this temporary workaround for cert acquistion issues: https://github.com/jetstack/cert-manager/issues/2442#issuecomment-564955495
# update the name server by running microk8s.kubectl -n kube-system edit configmap/coredns
# the nameserver can be found by running cat /run/systemd/resolve/resolv.conf
#####

# Create a new namespace for the cert-manager
kubectl create namespace cert-manager

# Apply the official yaml file 
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.14.2/cert-manager.yaml

##### If deploying to GCC:
# note this temporary workaround for cert acquistion issues: https://github.com/jetstack/cert-manager/issues/2442#issuecomment-564955495
# update the name server by running microk8s.kubectl -n kube-system edit configmap/coredns
# the nameserver can be found by running cat /run/systemd/resolve/resolv.conf
#####

# Install chectl
bash <(curl -sL  https://www.eclipse.org/che/chectl/)

wget https://raw.githubusercontent.com/MAAP-Project/maap-eclipseche-ops/master/che7/maap-k8sconfig-patch.yaml
wget https://raw.githubusercontent.com/MAAP-Project/maap-eclipseche-ops/master/che7/microk8s/prod.yaml 
wget https://raw.githubusercontent.com/MAAP-Project/maap-eclipseche-ops/master/che7/microk8s/ingress-prd.yaml 
# (updated domain in ingress-prd.yaml)

kubectl apply -f prod.yaml 
kubectl apply -f ingress-prd.yaml 

# Ensure the following returns a value of 'True' before proceeding
kubectl get cert

# Deploy Che
chectl server:deploy --installer=operator --platform=microk8s --che-operator-cr-patch-yaml=maap-k8sconfig-patch.yaml --domain={REPLACE_ME} --multiuser --chenamespace=default

kubectl edit daemonset nginx-ingress-microk8s-controller -n ingress   
# Add the following setting to ensure http requests are signed
#  - --default-ssl-certificate=default/default-tls-secret

kubectl edit ingress
# Add the following annotation to ensure that *all* http requests are forwarded to https
# nginx.ingress.kubernetes.io/force-ssl-redirect: "true"

# DONE!

# To completely reset the system (you probably don't need this):
sudo microk8s.reset
sudo snap remove microk8s --purge
```
