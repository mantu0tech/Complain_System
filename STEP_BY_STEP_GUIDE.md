# Municipal Complaint System — Complete Step-by-Step Guide with Troubleshooting

> Repo: https://github.com/mantu0tech/Complain_System.git
> Region: ap-south-1 (Mumbai)

---

## What You Are Building

A production-grade Flask web application deployed on AWS EKS, with:
- PostgreSQL on RDS for the database
- S3 for complaint image storage
- SNS for email alerts
- AI model (.pkl) that auto-predicts complaint priority
- Jenkins CI/CD pipeline on a jump server
- AWS ALB (Application Load Balancer) as the public entry point

---

## PHASE 1 — AWS Pre-Setup

### Step 1.1 — Verify AWS CLI Works

**Run:**
```bash
aws s3 ls
aws sts get-caller-identity
```

**Expected:** Lists your S3 buckets and shows your account ID.

**Troubleshoot — "Unable to locate credentials":**
```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region (ap-south-1), Output format (json)
```

---

### Step 1.2 — Create S3 Bucket

**Run:**
```bash
aws s3 mb s3://your-s3-bucket-complain --region ap-south-1
```

**Expected:** `make_bucket: your-s3-bucket-complain`

**Troubleshoot — "BucketAlreadyExists":**
Bucket names are globally unique. Add a random suffix: `your-s3-bucket-complain-2024`

**Troubleshoot — "InvalidBucketName":**
Bucket names must be lowercase, no underscores. Use hyphens only.

---

### Step 1.3 — Create SNS Topic

**Run:**
```bash
aws sns create-topic --name demo --region ap-south-1
```

**Expected:**
```json
{
    "TopicArn": "arn:aws:sns:ap-south-1:051826716700:demo"
}
```
Save this ARN — it goes into your `.env` as `SNS_TOPIC_ARN`.

**Then subscribe your email:**
AWS Console → SNS → Topics → demo → Create subscription → Protocol: Email → Enter your email → Confirm the verification email.

---

### Step 1.4 — Create ECR Repository

**Run:**
```bash
aws ecr create-repository --repository-name complain-system --region ap-south-1
```

**Expected:** JSON output with `repositoryUri` like `051826716700.dkr.ecr.ap-south-1.amazonaws.com/complain-system`

---

## PHASE 2 — Terraform Infrastructure

### Step 2.1 — Clone Repository

**Run:**
```bash
git clone https://github.com/mantu0tech/Complain_System.git
cd Complain_System
ls
# Should see: README.md install.sh jenkinsfile k8s project terraform
```

### Step 2.2 — Configure terraform.tfvars

**Run:**
```bash
cd terraform/municipal
# Edit terraform.tfvars — only change the values marked below
```

**Minimum changes required:**

| Variable | What to change | Example |
|---|---|---|
| `ssh_public_key` | Paste output of `cat ~/.ssh/id_rsa.pub` | `"ssh-rsa AAAA..."` |
| `admin_role_arns.admin` | Your IAM admin role ARN | `"arn:aws:iam::051826716700:role/adminroleforproject"` |
| `db_password` | Strong password | `"MyStrongPass123!"` |

**Troubleshoot — Don't have an SSH key:**
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/municipal-key
cat ~/.ssh/municipal-key.pub  # paste this into terraform.tfvars
```

**Troubleshoot — Don't know your admin role ARN:**
```bash
aws iam list-roles --query "Roles[*].Arn" --output table
```

---

### Step 2.3 — Run Terraform

**Run:**
```bash
terraform init
terraform plan     # review what will be created — no resources created yet
terraform apply --auto-approve
```

**Expected:** After ~15 minutes:
```
Outputs:
jump_server_ip     = "13.204.94.136"
eks_cluster_name   = "municipal-dev"
rds_endpoint       = "municipal-postgres.cjqgwiy282it.ap-south-1.rds.amazonaws.com:5432"
ssh_command        = "ssh -i ~/.ssh/municipal-key.pem ubuntu@13.204.94.136"
kubeconfig_command = "aws eks update-kubeconfig --name municipal-dev --region ap-south-1"
```

**Troubleshoot — "Error: Unsupported instance type m7i-flex.large":**
Change in `terraform.tfvars`:
```hcl
instance_types = ["t3.medium"]   # cheaper and always available
```

**Troubleshoot — "Error acquiring the state lock":**
```bash
terraform force-unlock LOCK_ID
```

**Troubleshoot — "Error: creating EKS Node Group: InvalidParameterException":**
The EKS version and AMI may mismatch. Change `cluster_version` to `"1.31"` in tfvars.

**Troubleshoot — Apply takes longer than 30 minutes:**
EKS creation normally takes 12-15 mins. If over 30 mins, check AWS Console → CloudFormation → look for ROLLBACK status.

---

## PHASE 3 — Jump Server Setup

### Step 3.1 — SSH into Jump Server

**Run:**
```bash
ssh -i ~/.ssh/municipal-key.pem ubuntu@YOUR_JUMP_SERVER_IP
```

**Troubleshoot — "Permission denied (publickey)":**
```bash
# Check key permissions
chmod 400 ~/.ssh/municipal-key.pem
# Try again
ssh -i ~/.ssh/municipal-key.pem ubuntu@YOUR_JUMP_SERVER_IP
```

**Troubleshoot — "Connection timed out":**
- Check EC2 security group allows port 22 from your IP
- In AWS Console → EC2 → Security Groups → jumpserver-sg → Inbound rules → add SSH from your IP

---

### Step 3.2 — Install All Tools

**Run:**
```bash
sudo apt install awscli -y
git clone https://github.com/mantu0tech/Complain_System.git
cd Complain_System
bash install.sh
```

**Verify installation:**
```bash
aws --version
docker ps
kubectl version --client
eksctl version
```

**Troubleshoot — "bash: install.sh: Permission denied":**
```bash
chmod +x install.sh
bash install.sh
```

**Troubleshoot — "docker: command not found" after install.sh:**
```bash
sudo apt install docker.io -y
sudo systemctl start docker
sudo usermod -aG docker ubuntu
newgrp docker
docker ps  # test
```

---

### Step 3.3 — Attach IAM Role to Jump Server

This is critical — without it, AWS CLI commands will fail on the server.

**In AWS Console:**
1. Go to **EC2 → Instances**
2. Select the instance named **municipal-jumpserver**
3. Click **Actions → Security → Modify IAM role**
4. Select `admin_role` from the dropdown
5. Click **Update IAM role**

**Verify it worked:**
```bash
aws sts get-caller-identity
# Should show the role ARN, not your personal user
```

**Troubleshoot — Role not in dropdown:**
Create it: IAM → Roles → Create role → EC2 → Attach `AdministratorAccess` policy → name it `admin_role`

---

### Step 3.4 — Connect kubectl to EKS

**Run:**
```bash
aws eks update-kubeconfig --name municipal-dev --region ap-south-1
kubectl get nodes
```

**Expected:**
```
NAME                                         STATUS   ROLES    AGE   VERSION
ip-10-0-102-46.ap-south-1.compute.internal   Ready    <none>   57m   v1.35.6-eks-93b80c6
ip-10-0-103-140.ap-south-1.compute.internal  Ready    <none>   57m   v1.35.6-eks-93b80c6
```

---

### TROUBLESHOOT — kubectl get nodes: "dial tcp 10.0.x.x:443: i/o timeout"

This is the most common error. The jump server SG is not allowed to reach the EKS cluster API on port 443.

**Fix:**
1. AWS Console → **EKS → Clusters → municipal-dev → Networking**
2. Click on the **Cluster security group** link (format: `sg-xxxxxxxxxx`)
3. Click **Edit inbound rules**
4. Click **Add rule**:
   - Type: `HTTPS`
   - Protocol: `TCP`
   - Port: `443`
   - Source: Select **Custom** → search for your jump server security group (`municipal-jumpserver-sg`)
5. Click **Save rules**
6. Run `kubectl get nodes` again — should work now

**Alternative fix — add by SG ID:**
```bash
# Get your jump server SG ID
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=municipal-jumpserver" \
  --query "Reservations[*].Instances[*].SecurityGroups[*].GroupId" \
  --output text

# Get EKS cluster SG ID
aws eks describe-cluster \
  --name municipal-dev \
  --region ap-south-1 \
  --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" \
  --output text

# Add the rule via CLI
aws ec2 authorize-security-group-ingress \
  --group-id EKS_CLUSTER_SG_ID \
  --protocol tcp \
  --port 443 \
  --source-group JUMPSERVER_SG_ID \
  --region ap-south-1
```

---

## PHASE 4 — Build and Push Docker Image

### Step 4.1 — Create .env File on Jump Server

**Run:**
```bash
cd ~/Complain_System/project
nano .env
```

**Paste this (replace values):**
```env
# App
SECRET_KEY=your-super-secret-key-change-this

# Database — IMPORTANT: use RDS endpoint, NOT db:5432
DATABASE_URL=postgresql://postgres:YOUR_DB_PASSWORD@YOUR_RDS_HOST:5432/complaints_db

# AWS
AWS_REGION=ap-south-1
BUCKET_NAME=your-s3-bucket-complain
SNS_TOPIC_ARN=arn:aws:sns:ap-south-1:YOUR_ACCOUNT_ID:demo
```

Save: `Ctrl+X → Y → Enter`

**Troubleshoot — What is my RDS host?**
```bash
# From terraform output:
terraform output rds_host
# Or from AWS Console: RDS → Databases → municipal-postgres → Endpoint
```

---

### Step 4.2 — Build and Push to ECR

**Run:**
```bash
git checkout devops

# Login to ECR
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin \
  YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com

# Build image
docker build -t complain-system .

# Tag for ECR
docker tag complain-system:latest \
  YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/complain-system:latest

# Push
docker push \
  YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/complain-system:latest
```

**Verify in ECR:**
```bash
aws ecr describe-images --repository-name complain-system --region ap-south-1
```

**Troubleshoot — "no basic credentials" during docker push:**
ECR tokens expire every 12 hours. Re-run the `aws ecr get-login-password` login command above, then push again.

**Troubleshoot — "denied: User is not authorized":**
Your IAM role doesn't have ECR permissions. Attach `AmazonEC2ContainerRegistryFullAccess` policy to the role.

**Troubleshoot — Docker build fails "COPY failed: file not found":**
Make sure you are in the correct directory with `Dockerfile`:
```bash
ls  # should see Dockerfile, app.py, requirements.txt etc.
```

---

## PHASE 5 — Kubernetes Deployment

### Step 5.1 — Apply Manifests

**Run (in this order):**
```bash
cd ~/Complain_System/k8s
ls
# Should see: deployment.yml ingress.yml namespace.yml secret.yml service.yml

kubectl apply -f namespace.yml
kubectl apply -f secret.yml
kubectl apply -f deployment.yml
kubectl apply -f service.yml
kubectl apply -f ingress.yml
```

**Expected output:**
```
namespace/municipal created
secret/municipal-secret created
deployment.apps/municipal-app created
service/municipal-service created
ingress.networking.k8s.io/municipal-ingress created
```

---

### Step 5.2 — Verify Pods Running

**Run:**
```bash
kubectl get all -n municipal
```

**Troubleshoot — Pod in "ImagePullBackOff" or "ErrImagePull":**
```bash
kubectl describe pod POD_NAME -n municipal
# Look at "Events" section at the bottom

# Fix: Check ECR image URI in deployment.yml matches your account
# Fix: Ensure node IAM role has AmazonEC2ContainerRegistryReadOnly policy
```

**Troubleshoot — Pod in "CrashLoopBackOff":**
```bash
kubectl logs POD_NAME -n municipal
# Common causes:
# 1. DATABASE_URL wrong → check secret.yml has correct RDS endpoint
# 2. DB not reachable → check RDS security group allows port 5432 from EKS nodes
# 3. Missing .pkl model file → ensure it's in the Docker image
```

**Troubleshoot — Pod in "Pending" forever:**
```bash
kubectl describe pod POD_NAME -n municipal
# If "Insufficient memory/cpu" → reduce requests in deployment.yml
# If "No nodes available" → check kubectl get nodes shows Ready
```

**Troubleshoot — DB tables not created:**
```bash
# Exec into running pod and create tables manually
kubectl exec -it -n municipal POD_NAME -- python -c \
  "from app import app, db; app.app_context().push(); db.create_all(); print('Tables created')"
```

---

## PHASE 6 — AWS Load Balancer Controller

### Step 6.1 — Add Helm Repo

**Run:**
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

**Expected:** `Successfully got an update from the "eks" chart repository`

---

### Step 6.2 — Get VPC ID

**Run:**
```bash
aws eks describe-cluster \
  --name municipal-dev \
  --region ap-south-1 \
  --query "cluster.resourcesVpcConfig.vpcId" \
  --output text
```
**Expected:** `vpc-09b3468485d64eae1` (save this)

---

### Step 6.3 — Download and Create IAM Policy

**Run:**
```bash
curl -o iam_policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerIAMPolicy \
  --policy-document file://iam_policy.json
```

**Save the ARN from output:**
```
"Arn": "arn:aws:iam::051826716700:policy/AWSLoadBalancerIAMPolicy"
```

**Troubleshoot — "EntityAlreadyExists: A policy called AWSLoadBalancerIAMPolicy already exists":**
```bash
# The policy already exists from a previous attempt — that's fine, skip this step
# Get the existing policy ARN:
aws iam list-policies --query "Policies[?PolicyName=='AWSLoadBalancerIAMPolicy'].Arn" --output text
```

---

### Step 6.4 — Associate OIDC Provider

**Run:**
```bash
eksctl utils associate-iam-oidc-provider \
  --cluster municipal-dev \
  --region ap-south-1 \
  --approve
```

**Expected:** `IAM Open ID Connect provider is already associated with cluster` (if run before, that's fine)

---

### Step 6.5 — Create IAM Service Account

**Run (replace YOUR_ACCOUNT_ID):**
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

**Expected:** Takes 10-15 minutes. Creates a CloudFormation stack in background.

**Troubleshoot — "Error: no IAM OIDC provider found":**
Re-run Step 6.4 first.

**Troubleshoot — "AlreadyExistsException" in CloudFormation:**
```bash
# The stack already exists — delete it and retry
aws cloudformation delete-stack \
  --stack-name eksctl-municipal-dev-addon-iamserviceaccount-kube-system-aws-load-balancer-controller
# Wait 2 minutes, then re-run the eksctl create command
```

---

### Step 6.6 — Install Controller via Helm

**Run (replace YOUR_VPC_ID from Step 6.2):**
```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=municipal-dev \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-south-1 \
  --set vpcId=YOUR_VPC_ID
```

**Verify:**
```bash
helm list -n kube-system
kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
kubectl get pods -n kube-system
```

**Expected pods running:**
```
aws-load-balancer-controller-674cd5dbcf-br29v   1/1   Running   0   36s
aws-load-balancer-controller-674cd5dbcf-xvp4x   1/1   Running   0   23s
```

---

### Step 6.7 — Get Your Public App URL

**Run:**
```bash
kubectl get ingress -n municipal
```

**Expected:**
```
NAME                CLASS   HOSTS   ADDRESS                                                    PORTS   AGE
municipal-ingress   alb     *       k8s-municipa-municipa-ec8b305fa3-975537560.ap-south-1.elb.amazonaws.com   80    65s
```

Open the ADDRESS in your browser → your app is live.

**Troubleshoot — ADDRESS column is empty after 5 minutes:**
```bash
# Check controller logs for errors
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Common causes:
# 1. VPC ID is wrong → re-check Step 6.2
# 2. Subnets missing kubernetes.io/role/elb=1 tag → check your VPC terraform module
# 3. IAM service account permissions issue → re-check Step 6.5
```

---

## PHASE 7 — Jenkins CI/CD Setup

### Step 7.1 — Install Jenkins on Jump Server

**Run:**
```bash
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
  sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" | \
  sudo tee /etc/apt/sources.list.d/jenkins.list

sudo apt update -y
sudo apt install -y openjdk-17-jdk jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo systemctl status jenkins
```

**Expected:** `Active: active (running)`

---

### Step 7.2 — Allow Jenkins to Use Docker and kubectl

**Run:**
```bash
sudo usermod -aG docker jenkins
sudo mkdir -p /var/lib/jenkins/.kube
sudo cp ~/.kube/config /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube
sudo systemctl restart jenkins
```

---

### Step 7.3 — Open Jenkins UI

Open in browser: `http://YOUR_JUMP_SERVER_IP:8080`

Get initial password:
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

**Install suggested plugins** when prompted, then create your admin user.

---

### Step 7.4 — Install Required Plugins

Go to **Manage Jenkins → Plugins → Available plugins**. Install:
- Git
- Pipeline
- Docker Pipeline
- AWS Steps
- GitHub Integration
- Stage View

Restart Jenkins after installing.

---

### Step 7.5 — Create Pipeline Job

1. **New Item** → name: `municipal-complaint` → **Pipeline** → OK
2. **General** → Check "GitHub project" → URL: `https://github.com/mantu0tech/Complain_System`
3. **Build Triggers** → Check "GitHub hook trigger for GITScm polling"
4. **Pipeline** → Definition: `Pipeline script from SCM` → SCM: `Git`
   - Repository URL: `https://github.com/mantu0tech/Complain_System.git`
   - Branch: `*/devops`
   - Script Path: `Jenkinsfile`
5. **Save**

---

### Step 7.6 — Add GitHub Webhook

In your GitHub repo → **Settings → Webhooks → Add webhook:**
- Payload URL: `http://YOUR_JUMP_SERVER_IP:8080/github-webhook/`
- Content type: `application/json`
- Events: Just the push event
- Active: checked → **Add webhook**

Green tick = working.

---

### Step 7.7 — Verify Jenkins Can Access Everything

**Run:**
```bash
sudo -u jenkins aws sts get-caller-identity
sudo -u jenkins aws ecr describe-repositories --region ap-south-1
sudo -u jenkins kubectl get nodes
```

All three must succeed. If any fail, see troubleshooting below.

**Troubleshoot — Jenkins docker permission denied:**
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

**Troubleshoot — Jenkins kubectl: no config:**
```bash
sudo cp ~/.kube/config /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube
sudo systemctl restart jenkins
```

**Troubleshoot — Webhook not triggering build:**
- Confirm port 8080 is open in jump server security group (inbound TCP 8080 from 0.0.0.0/0)
- Confirm webhook URL ends with `/github-webhook/` (trailing slash required)
- Check webhook delivery in GitHub: Settings → Webhooks → click webhook → Recent Deliveries

**Troubleshoot — ECR push fails in pipeline after 12 hours:**
ECR login tokens expire. The `Login To ECR` stage in the Jenkinsfile re-authenticates each build automatically — this is by design, no fix needed.

---

## Quick Reference — All Common Errors

| Error | Cause | Fix |
|---|---|---|
| `dial tcp 10.0.x.x:443: i/o timeout` | EKS SG blocks port 443 | Add HTTPS inbound rule from jump server SG to EKS cluster SG |
| `ImagePullBackOff` | ECR image not found or wrong URI | Check image URI in deployment.yml matches your ECR repo |
| `CrashLoopBackOff` | App crash — usually DB connection | Check `kubectl logs POD_NAME -n municipal` for error |
| `no basic credentials` | ECR token expired | Re-run `aws ecr get-login-password` login command |
| `EntityAlreadyExists` | IAM policy/role already created | Skip creation step, get existing ARN with `aws iam list-policies` |
| `Tables created []` (empty) | DB exists but no tables | Run `db.create_all()` via kubectl exec into pod |
| Jenkins `docker: permission denied` | Jenkins not in docker group | `sudo usermod -aG docker jenkins && sudo systemctl restart jenkins` |
| ALB ADDRESS empty | LB controller not working | Check `kubectl logs -n kube-system deployment/aws-load-balancer-controller` |
| `terraform force-unlock needed` | State locked from crashed run | Run `terraform force-unlock LOCK_ID` |
| Pod `Pending` — no resources | Nodes too small | Increase node size or add nodes in terraform.tfvars |
