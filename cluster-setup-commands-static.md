## Command sequence for installing and configuring an Eclipse Che cluster

```bash
# The host name for the ADE server.
ade_host='?'
export KOPS_CLUSTER_NAME=$ade_host
export KOPS_STATE_STORE=s3://${ade_host}

sudo apt-get update
sudo apt-get -y dist-upgrade

# Install kops
curl -LO https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
chmod +x kops-linux-amd64
sudo mv kops-linux-amd64 /usr/local/bin/kops

# Install kubectl
curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
kubectl version --client

sudo apt install awscli

# configure aws if not running from an ec2 instance with the required iam permissions attached
aws configure

# create kops bucket and enable versioning
aws s3 mb s3://${ade_host}
aws s3api put-bucket-versioning --bucket ${ade_host} --versioning-configuration Status=Enabled

kops create cluster --zones=us-east-1a --name=$ade_host
kops create secret --name $ade_host sshpublickey admin -i ~/.ssh/authorized_keys 
kops update cluster --name $ade_host --yes

# Ensure cluster is ready 
kops validate cluster

# Config kubectl and verify pods are running
kubectl config current-context
kubectl get pods --all-namespaces

# Configure tiller
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

# Install ingress-nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.26.1/deploy/static/mandatory.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.26.1/deploy/static/provider/cloud-generic.yaml

# Add the following permissions to the master role 
wget https://raw.githubusercontent.com/MAAP-Project/maap-eclipseche-ops/master/k8s-cluster/master_additional_permissions.json
aws iam put-role-policy --role-name masters.${ade_host} --policy-name masters.${ade_host} --policy-document file://master_additional_permissions.json

# Install cert manager
kubectl create namespace cert-manager
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
kubectl apply \
  -f https://github.com/jetstack/cert-manager/releases/download/v0.12.0/cert-manager.yaml \
  --validate=false
  
kubectl create namespace che
aws iam create-user --user-name cert-manager
aws iam create-access-key --user-name cert-manager
kubectl create secret generic aws-cert-manager-access-key \
  --from-literal=CLIENT_SECRET=<REPLACE WITH SecretAccessKey content> -n cert-manager
  
# Add inline policy to cert-manager user
wget https://raw.githubusercontent.com/MAAP-Project/maap-eclipseche-ops/master/k8s-cluster/cert-mgr_additional_permissions.json
aws iam put-user-policy --user-name cert-manager --policy-name route53 --policy-document file://cert-mgr_additional_permissions.json

# kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.10/deploy/manifests/00-crds.yaml

cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: che-certificate-issuer
spec:
  acme:
    dns01:
      providers:
      - route53:
          region: us-east-1
          accessKeyID: <REPLACE WITH AccessKeyId content>
          secretAccessKeySecretRef:
            name: aws-cert-manager-access-key
            key: CLIENT_SECRET
        name: route53
    email: brian.p.satorius@jpl.nasa.gov
    privateKeySecretRef:
      name: letsencrypt
    server: https://acme-v02.api.letsencrypt.org/directory
EOF

cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
 name: che-tls
 namespace: che
spec:
 secretName: che-tls
 issuerRef:
   name: che-certificate-issuer
   kind: ClusterIssuer
 dnsNames:
   - '*.<REPLACE WITH ade_host value>'
 acme:
   config:
     - dns01:
         provider: route53
       domains:
         - '*.<REPLACE WITH ade_host value>'
EOF

# Install chectl
git clone https://github.com/che-incubator/chectl.git

# Install yarn

# Update node

# Run chectl
cd chectl/bin
git checkout 7.12.2

# Deploy Che (try --self-signed-cert)
./run chectl server:start --platform=k8s --installer=operator --domain=${ade_host} --multiuser

```
