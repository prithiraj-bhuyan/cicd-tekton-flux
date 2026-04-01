# CI/CD for Cloud Native - Hello World Demo

A simplified hello-world walkthrough of **Tekton** (CI) and **Flux CD** (CD) on AKS.

---

## Project Structure

```
demo/
├── app/                    # Hello World FastAPI app
│   ├── main.py             # Two endpoints: / and /health
│   ├── test_main.py        # Pytest tests
│   ├── requirements.txt
│   └── Dockerfile
├── tekton/                 # Tekton CI manifests
│   ├── 01-git-secret.yaml       # GitHub SSH key secret
│   ├── 02-docker-secret.sh      # Script to create ACR secret
│   ├── 03-run-tests-task.yaml   # Custom Task: run pytest
│   ├── 04-pipeline.yaml         # Pipeline: clone → test → build
│   └── 05-pipelinerun.yaml      # PipelineRun: trigger execution
├── k8s/                    # Kubernetes deployment manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── flux/                   # Flux CD image automation
    ├── image-repository.yaml
    ├── image-policy.yaml
    └── image-update-automation.yaml
```

---

## Prerequisites

- Azure CLI (`az`), logged in
- An AKS cluster + ACR (from your Terraform setup)
- `kubectl` configured to your cluster
- Tekton CLI (`tkn`) installed
- Flux CLI (`flux`) installed

---

## Part 1: Tekton CI Pipeline

### Step 1: Install Tekton on the Cluster

```bash
# Connect to your AKS cluster
az aks get-credentials --name <CLUSTER_NAME> --resource-group <RESOURCE_GROUP>

# Install Tekton Pipelines
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# Wait for pods to be ready
kubectl get pods --namespace tekton-pipelines --watch
```

### Step 2: Install Reusable Tekton Tasks

```bash
# Download git-clone and kaniko tasks
wget https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.9/git-clone.yaml
wget https://raw.githubusercontent.com/tektoncd/catalog/main/task/kaniko/0.6/kaniko.yaml

# Apply them to the cluster
kubectl apply -f git-clone.yaml
kubectl apply -f kaniko.yaml
```

### Step 3: Set Up Authentication

**GitHub Deploy Key:**
```bash
# Generate SSH key (no password)
ssh-keygen -t rsa -f ~/cicd-demo-key

# Add ~/cicd-demo-key.pub as a Deploy Key in your GitHub repo settings

# Create the Kubernetes secret (edit 01-git-secret.yaml with your base64-encoded key)
cat ~/cicd-demo-key | base64 -w0   # Copy this output into the YAML
kubectl apply -f tekton/01-git-secret.yaml
```

**ACR Docker Credentials:**
```bash
# Get your ACR username and password from Azure Portal > ACR > Access Keys
./tekton/02-docker-secret.sh <username> <password> <acr_name>
```

### Step 4: Apply the Custom Test Task and Pipeline

```bash
kubectl apply -f tekton/03-run-tests-task.yaml
kubectl apply -f tekton/04-pipeline.yaml
```

### Step 5: Run the Pipeline

```bash
# Edit 05-pipelinerun.yaml with your repo URL and ACR name, then:
kubectl create -f tekton/05-pipelinerun.yaml

# Watch the logs
tkn pipeline logs -f -L
```

**Expected output:** Tests pass → Image built → Pushed to ACR

```
[run-tests : run-fastapi-tests] 2 passed
[build-push : build-and-push] INFO Pushed image to 1 destinations
```

### Useful Tekton Commands

```bash
tkn pipeline logs -f -L          # Watch latest pipeline logs
tkn pipelinerun describe -L      # Describe latest run
tkn pipelinerun delete --all     # Clean up old runs
```

---

## Part 2: Flux CD (GitOps Deployment)

### Step 1: Bootstrap Flux

```bash
# Install Flux on the cluster (needs a GitHub PAT with repo permissions)
export GITHUB_TOKEN=<your-github-token>

flux bootstrap github \
  --owner=<YOUR_GITHUB_USERNAME> \
  --repository=hello-cicd \
  --branch=main \
  --path=./k8s \
  --personal
```

### Step 2: Push K8s Manifests to Git

Copy the `k8s/` folder contents into your GitHub repo and push:

```bash
git add k8s/
git commit -m "Add K8s deployment manifests"
git push
```

Flux will automatically detect and deploy the app.

### Step 3: Set Up Image Automation (Optional - for auto-deploy)

```bash
# Create ACR secret for Flux
kubectl apply -f flux/image-repository.yaml
kubectl apply -f flux/image-policy.yaml
kubectl apply -f flux/image-update-automation.yaml

# Reconcile
flux reconcile source git flux-system
```

Now when Tekton pushes a new image to ACR, Flux will:
1. Detect the new tag
2. Update deployment.yaml with the new image tag
3. Commit the change back to Git
4. Deploy the updated manifest to the cluster

### Useful Flux Commands

```bash
flux get all                              # See all Flux resources
flux reconcile source git flux-system     # Force reconciliation
flux get kustomizations                   # Check kustomization status
kubectl get pods                          # Verify app is running
```

---

## Quick Test

Once deployed, find the external IP:

```bash
kubectl get svc hello-app
```

Then:

```bash
curl http://<EXTERNAL-IP>/
# {"message": "Hello, Cloud Native!"}

curl http://<EXTERNAL-IP>/health
# {"status": "healthy"}
```

---

## The Full CI/CD Loop

```
Push code → Tekton clones → Tests run → Image built → Pushed to ACR
                                                          ↓
                                              Flux detects new tag
                                                          ↓
                                              Updates deployment.yaml
                                                          ↓
                                              Commits back to Git
                                                          ↓
                                              Deploys to K8s cluster
```
