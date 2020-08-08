## Instructions for installing and configuring the MAAP Eclipse Che cluster

### Requirements
- This script has been tested using Ubuntu 18.04
- Full AWS account access required for the machine on which this script is run.
- Fill in the required fields denoted with brackets: 
  ```bash
  <>
  ```

### Step 1: Install required libraries

```bash
# The host name for the ADE server.
ade_host='<REPLACE with ADE host name>'
export KOPS_CLUSTER_NAME=$ade_host
export KOPS_STATE_STORE=s3://${ade_host}

sudo apt-get update
sudo apt-get -y dist-upgrade

# Install kops
curl -LO https://github.com/kubernetes/kops/releases/download/1.13.0/kops-linux-amd64
chmod +x kops-linux-amd64
sudo mv kops-linux-amd64 /usr/local/bin/kops

# Install kubectl
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.13.0/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# Install helm
wget https://get.helm.sh/helm-v2.14.3-linux-amd64.tar.gz
tar -zxvf helm-v2.14.3-linux-amd64.tar.gz 
sudo mv linux-amd64/helm /usr/local/bin/helm

# Install awscli
sudo apt install awscli
```

### Step 2: Configure K8s cluster

```bash
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

### Step 4: Update DNS record

In route 53, update the hosted zone with the external IP address emmitted above. As an example, you could create a new "CNAME" type recordset, and enter the external IP address as the alias value.

### Step 5: Enable the TLS and DNS challenge

```bash
# Use the following command to obtain the zone ID:
aws route53 list-hosted-zones
```
Copy the last segment of the Id from the output of the last command  content and replace INSERT_ZONE_ID with the route53 zone ID:
```json
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
```

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
   - '<REPLACE WITH ade_host value>'
 acme:
   config:
     - dns01:
         provider: route53
       domains:
         - '<REPLACE WITH ade_host value>'
EOF
```

Wait until the status of the cert-manager is `True`. Run `kubectl describe certificate/che-tls -n che` to verify this.

```bash
# sample output:
Status:
  Conditions:
    Last Transition Time:  2019-07-30T14:48:07Z
    Message:               Certificate is up to date and has not expired
    Reason:                Ready
    Status:                True
    Type:                  Ready
  Not After:               2019-10-28T13:48:05Z
Events:
  Type    Reason         Age    From          Message
  ----    ------         ----   ----          -------
  Normal  OrderCreated   5m29s  cert-manager  Created Order resource "che-tls-3365293372"
  Normal  OrderComplete  3m46s  cert-manager  Order "che-tls-3365293372" completed successfully
  Normal  CertIssued     3m45s  cert-manager  Certificate issued successfully
 ```

### Step 7: Install Che

```bash
git clone https://mas.maap-project.org/root/che
cd che/deploy/kubernetes/helm/che

kubectl create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:default
kubectl create serviceaccount tiller --namespace kube-system
kubectl apply -f ./tiller-rbac.yaml
#if necessary
#kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
sudo helm init --service-account tiller --wait

sudo helm upgrade --install che --namespace default --set global.multiuser=true --set global.serverStrategy=single-host --set global.ingressDomain=$ade_host --set global.tls.enabled=true --set global.tls.useCertManager=true --set global.tls.useStaging=false --set tls.secretName=che-tls ./

#DONE


git clone https://github.com/che-incubator/chectl.git

# Install yarn
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt update
sudo apt install yarn

# Update node
sudo apt install npm
npm cache clean -f
sudo npm install -g n
sudo n stable

# Install docker
sudo apt install docker.io
sudo docker login mas.maap-project.org
<ENTER mas.maap-project.org credentials>

cd chectl
git checkout 7.0.x
yarn
cd bin
./run server:start --platform=k8s --installer=operator --domain=${ade_host} --multiuser --tls
```

### Debugging
`./chectl-master/bin/run server:start --k8spodreadytimeout=180000 --installer=operator --listr-renderer=verbose --platform=k8s --che-operator-cr-yaml=maap-k8sconfig.yaml`
