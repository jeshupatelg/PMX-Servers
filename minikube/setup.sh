#!/usr/bin/env bash

set -euo pipefail

# Helper to verify/install Minikube
install_minikube() {
    echo "Checking Minikube installation..."
    if command -v minikube &> /dev/null; then
        echo "Minikube is already installed: $(minikube version)"
    else
        echo "Minikube not found. Installing..."
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        
        if [ -w /usr/local/bin ]; then
            install minikube-linux-amd64 /usr/local/bin/minikube
        else
            echo "No write access to /usr/local/bin. Attempting sudo install..."
            sudo install minikube-linux-amd64 /usr/local/bin/minikube || {
                echo "Sudo installation failed. Falling back to local bin path ($HOME/.local/bin)..."
                mkdir -p "$HOME/.local/bin"
                cp minikube-linux-amd64 "$HOME/.local/bin/minikube"
                chmod +x "$HOME/.local/bin/minikube"
                export PATH="$PATH:$HOME/.local/bin"
            }
        fi
        rm -f minikube-linux-amd64
        echo "Minikube installed successfully!"
    fi
}

# Helper to verify/install Kubectl
install_kubectl() {
    echo "Checking Kubectl installation..."
    if command -v kubectl &> /dev/null; then
        echo "Kubectl is already installed: $(kubectl version --client)"
    else
        echo "Kubectl not found. Installing..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        
        if [ -w /usr/local/bin ]; then
            install kubectl /usr/local/bin/kubectl
        else
            echo "No write access to /usr/local/bin. Attempting sudo install..."
            sudo install kubectl /usr/local/bin/kubectl || {
                echo "Sudo installation failed. Falling back to local bin path ($HOME/.local/bin)..."
                mkdir -p "$HOME/.local/bin"
                cp kubectl "$HOME/.local/bin/kubectl"
                chmod +x "$HOME/.local/bin/kubectl"
                export PATH="$PATH:$HOME/.local/bin"
            }
        fi
        rm -f kubectl
        echo "Kubectl installed successfully!"
    fi
}

# 1. Install prerequisites if missing
install_minikube
install_kubectl

# Check if Minikube is already running
if minikube status > /dev/null 2>&1; then
    echo "Minikube is already running. Exiting setup script."
    exit 0
fi

# 2. Start Minikube
echo "Starting Minikube (using docker driver)..."
# In a non-interactive CI/CD environment, ensure it runs cleanly
minikube start --driver=docker

# 3. Configure Addons
if [ -f addons.txt ]; then
    echo "Enabling configured Minikube addons..."
    while IFS= read -r addon || [ -n "$addon" ]; do
        # Strip carriage return characters if any, ignore comments and empty lines
        addon=$(echo "$addon" | tr -d '\r')
        [[ "$addon" =~ ^#.*$ ]] && continue
        [[ -z "$addon" ]] && continue
        echo "Enabling addon: $addon"
        minikube addons enable "$addon"
    done < addons.txt
else
    echo "No addons.txt file found. Skipping addons configuration."
fi

# 4. Apply Kubernetes Templates
if [ -d templates ]; then
    echo "Applying Kubernetes templates from the templates/ directory..."
    kubectl apply -f templates/
else
    echo "No templates/ directory found. Skipping template application."
fi

echo "Minikube setup complete!"
