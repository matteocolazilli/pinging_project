# Pinging Project - A CI/CD Pipeline for Deployment on a Kubernetes Cluster

This project implements a simple microservices application consisting of two "pingers" that run on a local Kubernetes cluster managed by Kind. The applications are containerized using Docker, and the project also includes a basic CI/CD workflow with GitHub Actions for building and pushing the images, as well as a self-hosted runner for deployment.

## Architecture

The architecture consists of the following components:

- **Pinger A & Pinger B**: Two containerized Python applications that ping each other at regular intervals.
- **Kubernetes (Kind)**: The applications run inside a local Kubernetes cluster created with Kind.
- **ConfigMap**: A Kubernetes ConfigMap is used to configure the ping interval and timeout.
- **Namespaces**: The project uses separate namespaces (`ping-app` and `github-runner`) to isolate the application and runner resources.
- **GitHub Actions**: The workflows are configured to automate the building of the pinger Docker images and their deployment via a self-hosted runner.

## Prerequisites

Before you begin, ensure you have the following tools installed:

- [Docker](https://docs.docker.com/get-docker/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [jq](https://stedolan.github.io/jq/download/)

## Compatibility

This project is designed to work on specific operating systems and architectures.

- **Operating System**: The `run.sh` setup script is a Bash script and uses standard Unix commands. It is therefore compatible with:
    - **Linux** (any modern distribution)
    - **macOS**
    - **Windows** via WSL (Windows Subsystem for Linux) (NOT TESTED). It is not compatible with the standard Windows command-line environments (CMD or PowerShell).

- **CPU Architecture**: The Docker images for the applications are built for multiple architectures (`linux/amd64` and `linux/arm64`). This ensures compatibility with:
    - **Intel/AMD (x86_64)** processors, common in most PCs.
    - **ARM64 (aarch64)** processors, such as those in Apple Silicon Macs (M1/M2/M3) and other ARM-based devices.

## Setup Guide

This guide will show you how to deploy the entire application from scratch. The main workflow involves preparing the Docker images, uploading them to your registry, and only then starting the cluster.

### 1. Fork the Repository

**This is the most important step.** To use the CI/CD pipeline and configure the project correctly, you must first create your own copy (fork) of this repository.

Click the **Fork** button in the top-right corner of this GitHub page.

You will work on your forked version from now on.

### 2. Clone Your Fork

Once you have created the fork, clone **your** repository to your local machine. Replace `<YOUR_GITHUB_USERNAME>` with your username.

```bash
git clone https://github.com/<YOUR_GITHUB_USERNAME>/pinging_project.git
cd pinging_project
```

### 3. Configure GitHub Secrets

In your **forked** repository, go to **Settings > Secrets and variables > Actions** and add the following secrets. These are necessary for the CI/CD pipeline to upload Docker images to your container registry in the future.

- `DOCKER_USERNAME`: Your Docker Hub username.
- `DOCKER_PASSWORD`: Your Docker Hub password or an access token.

### 4. Create the `.env` File

The startup script requires a `.env` file in the project root to configure the GitHub Actions self-hosted runner. Create a file named `.env` and add the following variables:

```
GITHUB_PAT="ghp_xxxxxxxxxxxxxxxxxxxx"
REPO_OWNER="<YOUR_GITHUB_USERNAME>"
REPO_NAME="pinging_project"
MACHINE_ID="<YOUR_MACHINE_ID>"
```

- `GITHUB_PAT`: A GitHub Personal Access Token with `repo` permissions.
- `REPO_OWNER`: **Important:** Enter your GitHub username here.
- `REPO_NAME`: The name of the repository (should be `pinging_project`).
- `MACHINE_ID`: A unique identifier for your machine (e.g., `your-name-laptop`).

### 5. Prepare and Push the Docker Images

Before starting the cluster, the application Docker images must be available on Docker Hub. This will ensure that Kubernetes can pull them and start the applications without errors.

**Step 5.1: Log in to Docker Hub**
Log in to your Docker Hub account from the terminal:
```bash
docker login
```

**Step 5.2: Modify the Kubernetes Manifests**
Open the `k8s/app/pinger-a.yaml` and `k8s/app/pinger-b.yaml` files. In both files, replace `matteoclz` with your Docker Hub username in the `image` field.

*Example for `pinger-a.yaml`:*
```yaml
      - name: pinger-a
        image: <YOUR_DOCKERHUB_USERNAME>/pinger-a:latest
```

**Step 5.3: Build and Push the Images**
Now, build the images and upload them to your Docker Hub. Replace `<YOUR_DOCKERHUB_USERNAME>` with your username.
```bash
# Build and push pinger-a
docker build -t <YOUR_DOCKERHUB_USERNAME>/pinger-a:latest ./app/pinger-a
docker push <YOUR_DOCKERHUB_USERNAME>/pinger-a:latest

# Build and push pinger-b
docker build -t <YOUR_DOCKERHUB_USERNAME>/pinger-b:latest ./app/pinger-b
docker push <YOUR_DOCKERHUB_USERNAME>/pinger-b:latest
```

### 6. Run the Startup Script

Now that the images are on Docker Hub and the manifests are correct, you can run the `run.sh` script to create the cluster and deploy the applications. This time, everything will work on the first try.

The script requires elevated privileges. You have two options:

1.  **Run with `sudo` (Easiest Option):**
    ```bash
    sudo ./run.sh
    ```
2.  **Add your user to the `docker` group:**
    ```bash
    sudo usermod -aG docker $USER
    # Requires a logout/login to apply the change
    ```
    **Warning:** Adding a user to the `docker` group grants privileges equivalent to root and can lead to serious security issues if compromised. Only use this approach if you fully understand the implications!

### 7. Verify the Deployment

Once the script has finished, you can verify that everything is running correctly.

```bash
kubectl get pods -n ping-app
```

You should see the pods in a `Running` state.

### 8. View the Logs

To see the application output, use `kubectl logs`.

```bash
# Get the name of a pinger-a pod
PINGER_A_POD=$(kubectl get pods -n ping-app -l app=pinger-a -o jsonpath='{.items[0].metadata.name}')

# View the logs
kubectl logs -f $PINGER_A_POD -n ping-app
```

### 9. Cleanup

To delete the local Kubernetes cluster, run:

```bash
kind delete cluster
```

## CI/CD

After completing this initial manual setup, every subsequent `push` to the `main` branch of your fork will trigger the GitHub Actions pipeline. The workflow will automatically rebuild and upload the updated Docker images to your Docker Hub and then redeploy them to your cluster.
