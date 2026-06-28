# Municipal Complaint System — EKS Deployment Guide

# Project ARCH
**<img width="936" height="603" alt="image" src="https://github.com/user-attachments/assets/d0ef4ad4-6314-4054-b3fd-bed120b5f058" />
**

> **Repo:** https://github.com/mantu0tech/Complain_System.git

A Flask-based citizen complaint portal with AI-powered priority prediction, deployed on AWS EKS using Terraform and Jenkins CI/CD.

---

## Architecture Overview

```
Flask App (Gunicorn:5000)
    ├── Amazon S3          → Stores complaint images
    ├── Amazon SNS         → Email notifications on complaint submission
    ├── PostgreSQL RDS     → Users, complaints, staff data
    └── AI Model (.pkl)    → Auto-assigns complaint priority (High/Medium/Low)

Deployment Stack:
    Terraform   → Provisions VPC, EKS, RDS, Jump Server
    Jenkins     → CI/CD pipeline on Jump Server
    Kubernetes  → Runs the app (2 replicas, LoadBalancer via ALB)
    ECR         → Stores Docker images
```

---

## Prerequisites — Collect These Before Starting

| Item | Where to get it |
|---|---|
| AWS Account with admin access | AWS Console |
| S3 bucket ARN | Create in AWS Console → S3 |
| SNS Topic ARN | Create in AWS Console → SNS |
| IAM Admin Role ARN | AWS Console → IAM → Roles |
| AWS Access Key (local dev only) | IAM → Users → Security credentials |
| SSH public key | `cat ~/.ssh/id_rsa.pub` on your machine |

---

## Step 1 — AWS Pre-Setup (Local Machine)

### 1.1 Create S3 Bucket
```bash
aws s3 mb s3://your-s3-bucket-complain --region ap-south-1
```

### 1.2 Create SNS Topic
```bash
aws sns create-topic --name demo --region ap-south-1
# Save the ARN from output → you need it in .env
```
Then subscribe your email: AWS Console → SNS → Topics → demo → Create subscription → Email

### 1.3 Create ECR Repository
```bash
aws ecr create-repository --repository-name complain-system --region ap-south-1
```

---

## Step 2 — Deploy Infrastructure with Terraform

### 2.1 Clone the repo
```bash
git clone https://github.com/mantu0tech/Complain_System.git
cd Complain_System/terraform/municipal
```

### 2.2 Fill in terraform.tfvars
Edit `terraform.tfvars` — only change these values:

```hcl
project_name    = "municipal"
environment     = "dev"
aws_region      = "ap-south-1"

# Your SSH public key
create_key_pair = true
ssh_public_key  = "ssh-rsa AAAA...your-key-here"

# Your IAM admin role
admin_role_arns = {
  admin = "arn:aws:iam::YOUR_ACCOUNT_ID:role/adminroleforproject"
}

# Database
db_name         = "complaints_db"
db_username     = "postgres"
db_password     = "StrongPassword123!"

# Node config
eks_node_groups = {
  default = {
    desired_size   = 2
    min_size       = 1
    max_size       = 3
    instance_types = ["t3.medium"]
    disk_size      = 20
    labels         = {}
  }
}

rds_instance_class      = "db.t3.micro"
rds_publicly_accessible = true
rds_multi_az            = false
rds_deletion_protection = false
```

### 2.3 Apply Terraform
```bash
terraform init
terraform plan
terraform apply --auto-approve
```
> Takes ~15 minutes. EKS cluster creation is the slow part.

### 2.4 Save the Terraform Outputs
```bash
terraform output
```
You will see:
```
jump_server_ip     = "13.204.94.136"
ssh_command        = "ssh -i ~/.ssh/municipal-key.pem ubuntu@13.204.94.136"
eks_cluster_name   = "municipal-dev"
kubeconfig_command = "aws eks update-kubeconfig --name municipal-dev --region ap-south-1"
rds_endpoint       = "municipal-postgres.xxxxx.ap-south-1.rds.amazonaws.com:5432"
rds_host           = "municipal-postgres.xxxxx.ap-south-1.rds.amazonaws.com"
```
Keep these — you will use them in the next steps.

---

## Step 3 — Set Up Jump Server

### 3.1 SSH into Jump Server
```bash
ssh -i ~/.ssh/municipal-key.pem ubuntu@YOUR_JUMP_SERVER_IP
```

### 3.2 Clone Repo and Run Install Script
```bash
sudo apt install awscli -y
git clone https://github.com/mantu0tech/Complain_System.git
cd Complain_System
bash install.sh
```
This installs: Docker, kubectl, eksctl, Helm, AWS CLI v2.

### 3.3 Attach Admin IAM Role to Jump Server
Go to **AWS Console → EC2 → Instances → municipal-jumpserver → Actions → Security → Modify IAM Role → Select admin_role → Update IAM role**

### 3.4 Connect to EKS Cluster
```bash
aws eks update-kubeconfig --name municipal-dev --region ap-south-1
kubectl get nodes
```
Both nodes should show `Ready`.

> **If you get `dial tcp 10.0.x.x:443: i/o timeout` error** → See Troubleshooting section.

---

## Step 4 — Build and Push Docker Image

### 4.1 Create .env file on jump server
```bash
cd ~/Complain_System/project
nano .env
```
Paste this content (fill in your values):
```env
# App
SECRET_KEY=your-super-secret-key-change-this

# Database — use RDS endpoint here (NOT db:5432)
DATABASE_URL=postgresql://postgres:YOUR_PASSWORD@YOUR_RDS_HOST:5432/complaints_db

# AWS
AWS_REGION=ap-south-1
BUCKET_NAME=your-s3-bucket-complain
SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:YOUR_ACCOUNT_ID:demo
```
> Do NOT add AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY on the server — the IAM role handles authentication.

### 4.2 Switch to devops branch
```bash
git checkout devops
```

### 4.3 Login to ECR and Push Image
```bash
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin \
  YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com

docker build -t complain-system .

docker tag complain-system:latest \
  YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/complain-system:latest

docker push \
  YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/complain-system:latest
```

Verify in AWS Console → ECR → complain-system → Images. You should see the `latest` tag.

---

## Step 5 — Deploy to Kubernetes

### 5.1 Update Kubernetes secret.yml
Edit `k8s/secret.yml` with your base64-encoded values:
```bash
echo -n "your-value-here" | base64
```

### 5.2 Apply All Manifests (in order)
```bash
cd ~/Complain_System/k8s

kubectl apply -f namespace.yml
kubectl apply -f secret.yml
kubectl apply -f deployment.yml
kubectl apply -f service.yml
kubectl apply -f ingress.yml
```

### 5.3 Verify Pods Are Running
```bash
kubectl get all -n municipal
```
Expected output:
```
NAME                                  READY   STATUS    RESTARTS   AGE
pod/municipal-app-df4c46b4b-7n6x2    1/1     Running   0          90s
pod/municipal-app-df4c46b4b-8ntmk    1/1     Running   0          90s

NAME                         TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
service/municipal-service    ClusterIP   172.20.4.1    <none>        80/TCP    83s

NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/municipal-app    2/2     2            2           90s
```

---

## Step 6 — Install AWS Load Balancer Controller

The ingress `ADDRESS` will be empty until the ALB controller is installed. This is what gives you a public URL.

### 6.1 Add Helm Repo
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

### 6.2 Get VPC ID
```bash
aws eks describe-cluster \
  --name municipal-dev \
  --region ap-south-1 \
  --query "cluster.resourcesVpcConfig.vpcId" \
  --output text
# Outputs: vpc-09b3468485d64eae1  ← save this
```

### 6.3 Create Load Balancer IAM Policy
```bash
curl -o iam_policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerIAMPolicy \
  --policy-document file://iam_policy.json
# Save the ARN from output
```

### 6.4 Associate OIDC Provider
```bash
eksctl utils associate-iam-oidc-provider \
  --cluster municipal-dev \
  --region ap-south-1 \
  --approve
```

### 6.5 Create IAM Service Account (takes 10-15 mins)
```bash
eksctl create iamserviceaccount \
  --cluster municipal-dev \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/AWSLoadBalancerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve \
  --region ap-south-1
```

### 6.6 Install Controller via Helm
```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=municipal-dev \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-south-1 \
  --set vpcId=YOUR_VPC_ID
```

### 6.7 Verify and Restart
```bash
helm list -n kube-system
kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
kubectl get pods -n kube-system
```

### 6.8 Get Your App URL
```bash
kubectl get ingress -n municipal
# ADDRESS column now shows your ALB DNS → open in browser
```

Your app is live at the ALB DNS address shown.

---

## Step 7 — Jenkins CI/CD (Optional Automation)

After setting up Jenkins (see STEP_BY_STEP_GUIDE.md for full Jenkins setup), every `git push` to master will:
1. Checkout code from GitHub
2. Build Docker image
3. Push to ECR
4. Deploy to EKS via `kubectl set image`
5. Wait for rollout to complete

Webhook URL for GitHub: `http://YOUR_JUMP_SERVER_IP:8080/github-webhook/`

---

## Verify Everything Works

```bash
# Pods running
kubectl get pods -n municipal

# Check DB connection inside pod
kubectl exec -it -n municipal POD_NAME -- printenv | grep DATABASE

# Check app logs
kubectl logs -n municipal POD_NAME

# Load balancer controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

---

## Cleanup (Stop AWS Billing)

```bash
# 1. Delete IAM service account
eksctl delete iamserviceaccount \
  --cluster municipal-dev \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --region ap-south-1

# 2. Delete kubernetes resources
kubectl delete -f ~/Complain_System/k8s/

# 3. Destroy all terraform infrastructure
cd ~/Complain_System/terraform/municipal
terraform destroy --auto-approve
```
