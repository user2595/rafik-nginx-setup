#!/bin/bash

set -e  
set -o pipefail  

PROJECT_ID="your-google-cloud-project-id"
CLUSTER_NAME="gke-static-site"
REGION="europe-west3"
NODE_POOL_NAME="default-pool"
EMAIL=""
DOMAIN_DEV="dev.kub.eulernest.eu"
DOMAIN_PROD="prod.kub.eulernest.eu"
NUMBER_OF_NODES=3
DISK_SIZE_OF_NODES=20
MACHINE_TYPE="e2-small"

echo "🚀 Enabling Google Cloud APIs..."
gcloud services enable container.googleapis.com artifactregistry.googleapis.com

echo "🔧 Setting Google Cloud project..."
gcloud config set project $PROJECT_ID

echo "📌 Creating GKE cluster (if not already present)..."
if ! gcloud container clusters describe $CLUSTER_NAME --region $REGION &> /dev/null; then
  gcloud container clusters create $CLUSTER_NAME \
    --region $REGION \
    --num-nodes=$NUMBER_OF_NODES \
    --disk-size=$DISK_SIZE_OF_NODES \
    --machine-type=$MACHINE_TYPE \
    --enable-ip-alias \
    --disk-type=pd-standard \
    --release-channel=regular \
    --enable-autoupgrade \
    --enable-autorepair \
    --enable-network-policy
else
  echo "✅ Cluster already exists!"
fi

echo "🔄 Fetching Kubernetes credentials for $CLUSTER_NAME..."
gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION

echo "🔄 Updating Helm repositories..."
helm repo add traefik https://helm.traefik.io/traefik
helm repo add jetstack https://charts.jetstack.io
helm repo update

echo "📦 Installing Traefik as Ingress Controller..."
helm upgrade --install traefik traefik/traefik -f ./helm-chart/values-traefik.yaml -n traefik --create-namespace

echo "⏳ Waiting for Traefik LoadBalancer..."
kubectl wait --for=condition=Available deployment traefik -n traefik --timeout=90s

echo "📦 Installing Cert-Manager for Let's Encrypt..."
helm upgrade --install cert-manager jetstack/cert-manager -n cert-manager --create-namespace -f ./helm-chart/values-cert-manager.yaml

echo "🔑 Creating Let's Encrypt ClusterIssuer..."
kubectl apply -f ./helm-chart/templates/cluster-issuer.yaml

echo "⏳ Waiting for Cert-Manager..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=90s

echo "📌 Creating namespaces..."
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -

echo "🌍 Deploying Dev environment with its own domain..."
helm upgrade --install static-site-dev ./helm-chart -n dev --create-namespace -f ./helm-chart/values-dev.yaml

echo "🌍 Deploying Prod environment with its own domain..."
helm upgrade --install static-site-prod ./helm-chart -n prod --create-namespace -f ./helm-chart/values-prod.yaml

echo "✅ Setup complete! Test your environments:"
echo "🔗 Dev: https://$DOMAIN_DEV"
echo "🔗 Prod: https://$DOMAIN_PROD"

echo "🚀 Helm Releases:"
helm list -A