#!/bin/bash
# ============================================================
# MUNICIPAL COMPLAINT SYSTEM — ALL COMMANDS (COPY-PASTE READY)
# Repo: https://github.com/mantu0tech/Complain_System.git
# ============================================================
# Replace these placeholders before running:
#   YOUR_ACCOUNT_ID     → e.g. 051826716700
#   YOUR_JUMP_SERVER_IP → e.g. 13.204.94.136
#   YOUR_BUCKET_NAME    → e.g. your-s3-bucket-complain
#   YOUR_SNS_ARN        → e.g. arn:aws:sns:ap-south-1:051826716700:demo
#   YOUR_RDS_ENDPOINT   → e.g. municipal-postgres.xxxxx.ap-south-1.rds.amazonaws.com
#   YOUR_DB_PASSWORD    → your RDS master password
#   YOUR_VPC_ID         → from terraform output or aws eks describe-cluster
# ============================================================


# ─────────────────────────────────────────────────────────────
# SECTION 1 — AWS PRE-REQUISITES (Run from local machine)
# ─────────────────────────────────────────────────────────────

# Verify AWS CLI is configured
aws s3 ls
aws sts get-caller-identity

# Create S3 bucket
aws s3 mb s3://YOUR_BUCKET_NAME --region ap-south-1

# Create SNS topic
aws sns create-topic --name demo --region ap-south-1
# Note the ARN from output → use in .env as SNS_TOPIC_ARN

# Subscribe your email to SNS topic (replace EMAIL and ARN)
aws sns subscribe \
  --topic-arn arn:aws:sns:ap-south-1:YOUR_ACCOUNT_ID:demo \
  --protocol email \
  --notification-endpoint your@email.com \
  --region ap-south-1

# Create ECR repository
aws ecr create-repository \
  --repository-name complain-system \
  --region ap-south-1


# ─────────────────────────────────────────────────────────────
# SECTION 2 — LOCAL DOCKER (Run from project root on Windows)
# ─────────────────────────────────────────────────────────────

# Build and start all containers
docker compose up --build

# If DB tables not created, run this (replace container ID)
docker exec -it f09f66ffa6e6 python -c \
  "from app import app, db; app.app_context().push(); db.create_all(); print('Tables created')"

# Get running container ID
docker ps

# Stop all containers
docker compose down


# ─────────────────────────────────────────────────────────────
# SECTION 3 — TERRAFORM (Run from local machine)
# ─────────────────────────────────────────────────────────────

# Navigate to terraform directory
cd Complain_System/terraform/municipal

# Initialize terraform
terraform init

# Preview what will be created
terraform plan

# Apply infrastructure (takes ~15 mins for EKS)
terraform apply --auto-approve

# Get all outputs after apply
terraform output

# Get the sensitive DATABASE_URL
terraform output database_url

# Destroy everything (when done)
terraform destroy --auto-approve


# ─────────────────────────────────────────────────────────────
# SECTION 4 — JUMP SERVER SETUP (Run on jump server via SSH)
# ─────────────────────────────────────────────────────────────

# SSH into jump server (from local machine)
ssh -i ~/.ssh/municipal-key.pem ubuntu@YOUR_JUMP_SERVER_IP

# Install AWS CLI (if not already installed by Terraform user_data)
sudo apt install awscli -y

# Clone the repo
git clone https://github.com/mantu0tech/Complain_System.git
cd Complain_System

# Run the install script (installs docker, kubectl, eksctl, helm, aws cli)
bash install.sh

# Verify all tools installed
aws --version
docker ps
kubectl version --client
eksctl version

# Attach admin IAM role to jump server EC2 instance
# → Go to AWS Console → EC2 → Select instance → Actions → Security → Modify IAM Role
# → Select your admin_role → Update IAM role

# Configure kubectl to connect to EKS
aws eks update-kubeconfig --name municipal-dev --region ap-south-1

# Verify cluster connection
kubectl get nodes


# ─────────────────────────────────────────────────────────────
# SECTION 5 — BUILD & PUSH IMAGE TO ECR (Run on jump server)
# ─────────────────────────────────────────────────────────────

# Go to project directory
cd ~/Complain_System/project

# Create .env file
nano .env
# Paste your .env content (see SECTION 9 below for template)

# Switch to devops branch
git checkout devops

# Login to ECR
aws ecr get-login-password --region ap-south-1 | \
  docker login \
  --username AWS \
  --password-stdin \
  YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com

# Build Docker image
docker build -t complain-system .

# Tag image for ECR
docker tag complain-system:latest \
  YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/complain-system:latest

# Verify local images
docker images

# Push image to ECR
docker push \
  YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/complain-system:latest

# Verify image is in ECR
aws ecr describe-images \
  --repository-name complain-system \
  --region ap-south-1


# ─────────────────────────────────────────────────────────────
# SECTION 6 — KUBERNETES MANIFESTS (Run on jump server)
# ─────────────────────────────────────────────────────────────

# Navigate to k8s directory
cd ~/Complain_System/k8s

# Apply in this exact order:
kubectl apply -f namespace.yml
kubectl apply -f secret.yml
kubectl apply -f deployment.yml
kubectl apply -f service.yml
kubectl apply -f ingress.yml

# Check everything is running
kubectl get all -n municipal

# Check pods specifically
kubectl get pods -n municipal

# Check service
kubectl get service -n municipal

# Check ingress (ADDRESS column will be empty until LB controller is installed)
kubectl get ingress -n municipal

# Check logs of a pod (replace pod name)
kubectl logs -n municipal municipal-app-df4c46b4b-7n6x2

# Check env vars in a pod (verify DB connection)
kubectl exec -it -n municipal municipal-app-df4c46b4b-7n6x2 -- printenv | grep DATABASE
kubectl exec -it -n municipal municipal-app-df4c46b4b-7n6x2 -- env | grep DATABASE


# ─────────────────────────────────────────────────────────────
# SECTION 7 — AWS LOAD BALANCER CONTROLLER (Run on jump server)
# ─────────────────────────────────────────────────────────────

# Step 7.1 — Add EKS Helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Step 7.2 — Get your VPC ID
aws eks describe-cluster \
  --name municipal-dev \
  --region ap-south-1 \
  --query "cluster.resourcesVpcConfig.vpcId" \
  --output text
# Note the vpc-xxxxxxxxx value

# Step 7.3 — Download IAM policy for load balancer
curl -o iam_policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

# Step 7.4 — Create IAM policy
aws iam create-policy \
  --policy-name AWSLoadBalancerIAMPolicy \
  --policy-document file://iam_policy.json
# Note the Policy ARN from output

# Step 7.5 — Associate OIDC provider with cluster
eksctl utils associate-iam-oidc-provider \
  --cluster municipal-dev \
  --region ap-south-1 \
  --approve

# Step 7.6 — Create IAM service account (takes 10-15 mins)
eksctl create iamserviceaccount \
  --cluster municipal-dev \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/AWSLoadBalancerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve \
  --region ap-south-1

# Step 7.7 — Install load balancer controller via Helm (replace YOUR_VPC_ID)
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=municipal-dev \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-south-1 \
  --set vpcId=YOUR_VPC_ID

# Step 7.8 — Verify helm installation
helm list -n kube-system

# Step 7.9 — Restart the controller
kubectl rollout restart deployment aws-load-balancer-controller -n kube-system

# Step 7.10 — Check controller pods are running
kubectl get pods -n kube-system

# Step 7.11 — Check load balancer controller deployment
kubectl get deployment -n kube-system

# Step 7.12 — Check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Step 7.13 — Get ingress ADDRESS (load balancer DNS — may take 2-3 mins)
kubectl get ingress -n municipal

# Access app at the ADDRESS shown in above command


# ─────────────────────────────────────────────────────────────
# SECTION 8 — FIX EKS CONNECTIVITY ERROR (kubectl get nodes fails)
# ─────────────────────────────────────────────────────────────

# If you get "dial tcp 10.0.x.x:443: i/o timeout" error:
# Go to AWS Console → EKS → Clusters → municipal-dev
# → Networking → Cluster security group → Edit inbound rules
# → Add rule: Type=HTTPS, Port=443, Source=your jump server SG ID
# → Save rules

# Check who has access to EKS cluster
aws eks list-access-entries \
  --cluster-name municipal-dev \
  --region ap-south-1


# ─────────────────────────────────────────────────────────────
# SECTION 9 — .ENV FILE TEMPLATE
# ─────────────────────────────────────────────────────────────

# Create .env with these contents (fill in your values):
cat > .env << 'EOF'
# App
SECRET_KEY=your-super-secret-key-change-this

# Database — use RDS endpoint on EKS (NOT the docker db:5432)
#DATABASE_URL=postgresql://postgres:postgres@db:5432/complaints_db   # local only
DATABASE_URL=postgresql://postgres:YOUR_DB_PASSWORD@YOUR_RDS_ENDPOINT:5432/complaints_db

# AWS
AWS_REGION=ap-south-1
BUCKET_NAME=your-s3-bucket-complain
SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:YOUR_ACCOUNT_ID:demo

# For local dev only — on EC2/EKS use IAM roles instead (remove these lines on server)
# AWS_ACCESS_KEY_ID=your-access-key
# AWS_SECRET_ACCESS_KEY=your-secret-key
EOF


# ─────────────────────────────────────────────────────────────
# SECTION 10 — JENKINS CI/CD (Run on jump server)
# ─────────────────────────────────────────────────────────────

# Install Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
  sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" | \
  sudo tee /etc/apt/sources.list.d/jenkins.list

sudo apt update -y
sudo apt install -y openjdk-17-jdk jenkins

# Start Jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo systemctl status jenkins

# Allow Jenkins to use Docker and AWS
sudo usermod -aG docker jenkins

sudo mkdir -p /var/lib/jenkins/.kube
sudo cp ~/.kube/config /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube

sudo systemctl restart jenkins

# Get Jenkins initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
# Open browser: http://YOUR_JUMP_SERVER_IP:8080

# Verify Jenkins can access AWS and kubectl
sudo -u jenkins aws sts get-caller-identity
sudo -u jenkins aws ecr describe-repositories --region ap-south-1
sudo -u jenkins kubectl get nodes


# ─────────────────────────────────────────────────────────────
# SECTION 11 — CLEANUP (Teardown to stop AWS billing)
# ─────────────────────────────────────────────────────────────

# Delete IAM service account (run before terraform destroy)
eksctl delete iamserviceaccount \
  --cluster municipal-dev \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --region ap-south-1

# Delete all k8s resources
kubectl delete -f ~/Complain_System/k8s/

# Destroy all terraform infrastructure
cd ~/Complain_System/terraform/municipal
terraform destroy --auto-approve
