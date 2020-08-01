## Command sequence for installing and configuring an Eclipse Che cluster

```bash
# The host name for the ADE server.
ade_host='?'
export KOPS_CLUSTER_NAME=$ade_host
export KOPS_STATE_STORE=$ade_host

sudo apt-get update
sudo apt-get -y dist-upgrade

# Install kops
curl -LO https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
chmod +x kops-linux-amd64
sudo mv kops-linux-amd64 /usr/local/bin/kops

sudo apt install awscli
aws configure
aws s3 mb s3://$ade_host

kops create cluster --zones=us-east-1a --name=$ade_host
kops create secret --name $ade_host sshpublickey admin -i ~/.ssh/authorized_keys 
kops update cluster --name $ade_host --yes

# Ensure cluster is ready 
kops validate cluster
kubectl config current-context
kubectl get pods --all-namespaces

# Install Ingress-nginx
kubectl apply \
  -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml
kubectl apply \
  -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/aws/service-l4.yaml
kubectl apply \
  -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/aws/patch-configmap-l4.yaml
aws iam create-service-linked-role --aws-service-name "elasticloadbalancing.amazonaws.com"

# Install cert manager
kubectl create namespace cert-manager
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
kubectl apply \
  -f https://github.com/jetstack/cert-manager/releases/download/v0.8.1/cert-manager.yaml \
  --validate=false
kubectl create namespace che
aws iam create-user --user-name cert-manager
aws iam create-access-key --user-name cert-manager
kubectl create secret generic aws-cert-manager-access-key \
  --from-literal=CLIENT_SECRET=<REPLACE WITH SecretAccessKey content> -n cert-manager

```
