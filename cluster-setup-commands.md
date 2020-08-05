## Instructions for installing and configuring the MAAP Eclipse Che cluster

This script has been tested using Ubuntu 18.04. Required fields are denoted within brackets *<>*

### Step 1: Install required libraries

```bash
# The host name for the ADE server.
ade_host='<REPLACE with ADE host name>'
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

# Install helm
wget https://get.helm.sh/helm-v2.16.9-linux-amd64.tar.gz
tar -zxvf helm-v2.16.9-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm

# Install awscli
sudo apt install awscli
```

### Step 2: Configure K8s cluster

```bash
# configure aws if not running from an ec2 instance with the required iam permissions attached
aws configure

# create kops bucket and enable versioning
aws s3 mb s3://${ade_host}
aws s3api put-bucket-versioning --bucket ${ade_host} --versioning-configuration Status=Enabled

kops create cluster --zones=<REPLACE with target AWS region e.g. us-east-1a> --name=$ade_host
kops create secret --name $ade_host sshpublickey admin -i ~/.ssh/authorized_keys 
kops update cluster --name $ade_host --yes

# Ensure cluster is ready 
kops validate cluster

# Config kubectl and verify pods are running
kubectl config current-context
kubectl get pods --all-namespaces
```

### Step 3: Install Ingress-nginx

```bash
# Install ingress-nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.26.1/deploy/static/mandatory.yaml
kubectl apply \
  -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.26.1/deploy/static/provider/aws/service-l4.yaml     
kubectl apply \
  -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.26.1/deploy/static/provider/aws/patch-configmap-l4.yaml

# Find the external IP of ingress-nginx
kubectl get services --namespace ingress-nginx -o jsonpath='{.items[].status.loadBalancer.ingress[0].hostname}'
```

### Step 4: ADD CNAME record

In route 53, Create the wildcard DNS (for .${ade_host}) with the previous host name and ensure to add the dot (.) at the end of the host name. 
Within the ADE hosted zone, create a new "CNAME" type recordset, and use * for the name. Within the Alias value field, enter the external IP value generated in the last command of step 3.

### Step 5: Enable the TLS and DNS challenge

```bash
# Use the following command to obtain the zone ID:
aws route53 list-hosted-zones
```
Copy the last segment of the Id from the output of the last command  content and replace INSERT_ZONE_ID with the route53 zone ID:
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:GetChange",
                "route53:ListHostedZonesByName"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "route53:ChangeResourceRecordSets"
            ],
            "Resource": [
                "arn:aws:route53:::hostedzone/<INSERT_ZONE_ID>"
            ]
        }
    ]
}

Now update the IAM role attached to the master node EC2 instance (masters.[ade_host], in this case). Add an *inline policy* using the above json with the name `eclipse-che-route53`.

### Step 6: Install cert-manager 

```bash
# Install cert manager
kubectl create namespace cert-manager
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
kubectl apply \
  -f https://github.com/jetstack/cert-manager/releases/download/v0.10.1/cert-manager.yaml \
  --validate=false
kubectl create namespace che
aws iam create-user --user-name cert-manager
aws iam create-access-key --user-name cert-manager
kubectl create secret generic aws-cert-manager-access-key \
  --from-literal=CLIENT_SECRET=<REPLACE WITH SecretAccessKey content> -n cert-manager
  
# Add inline policy to cert-manager user
wget https://raw.githubusercontent.com/MAAP-Project/maap-eclipseche-ops/master/k8s-cluster/cert-mgr_additional_permissions.json
aws iam put-user-policy --user-name cert-manager --policy-name route53 --policy-document file://cert-mgr_additional_permissions.json


cat <<EOF | kubectl apply -f -
apiVersion: certmanager.k8s.io/v1alpha1
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
    email: <REPLACE WITH ADMIN'S EMAIL>
    privateKeySecretRef:
      name: letsencrypt
    server: https://acme-v02.api.letsencrypt.org/directory
EOF

cat <<EOF | kubectl apply -f -
apiVersion: certmanager.k8s.io/v1alpha1
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
```

### Step 7: Install Che

```bash
git clone https://mas.maap-project.org/root/che.git
cd che/deploy/kubernetes/helm/che
git checkout cluster-deploy
helm dep update
sudo helm upgrade --install che --namespace che --set global.multiuser=true --set global.serverStrategy=multi-host --set global.ingressDomain=${ade_host} --set global.tls.enabled=true --set global.tls.useCertManager=true --set global.tls.useStaging=false --set tls.secretName=che-tls
```
