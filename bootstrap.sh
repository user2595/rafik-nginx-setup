#!/bin/bash

set -e  
set -o pipefail  

PROJECT_ID="k8s-traefik-nginx"
CLUSTER_NAME="gke-static-site"
REGION="us-central1"
ZONE="us-central1-a"
NODE_POOL_NAME="default-pool"
EMAIL="tarik.moussa95@gmail.com"
DOMAIN_DEV="dev.kub.eulernest.eu"
DOMAIN_PROD="prod.kub.eulernest.eu"
NUMBER_OF_NODES=3
DISK_SIZE_OF_NODES=20
MACHINE_TYPE="e2-small"


echo "🚀 Setting up Google Cloud project..."
gcloud config set project $PROJECT_ID
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

# startic ip
echo "🚀 Creating static IP for Traefik LoadBalancer..."
if ! gcloud compute addresses describe ingress-ip --region $REGION &> /dev/null; then
  gcloud compute addresses create ingress-ip --region $REGION --project $PROJECT_ID
  echo "⏳ Static IP does not exist, creating..."
else
  echo "✅ Static IP already exists!"
fi

# get static ip
TRAFFIC_IP=$(gcloud compute addresses describe ingress-ip --region $REGION --format='value(address)')
echo "✅ Static IP: $TRAFFIC_IP"
echo "🚀 Enabling Google Cloud APIs..."
gcloud services enable container.googleapis.com artifactregistry.googleapis.com

echo "🔧 Setting Google Cloud project..."
gcloud config set project $PROJECT_ID




echo "📌 Creating GKE cluster (if not already present)..."


if ! gcloud container clusters describe $CLUSTER_NAME --zone $ZONE &> /dev/null; then
  echo "⏳ Cluster does not exist, creating..."
  gcloud container clusters create-auto $CLUSTER_NAME --region $REGION
  # gcloud container clusters create $CLUSTER_NAME \
  #   --zone $ZONE \
  #   --num-nodes=1 \
  #   --enable-autoscaling --min-nodes=1 --max-nodes=$NUMBER_OF_NODES \
  #   --disk-size=$DISK_SIZE_OF_NODES \
  #   --machine-type=$MACHINE_TYPE \
  #   --enable-ip-alias \
  #   --disk-type=pd-balanced \
  #   --release-channel=regular \
  #   --enable-autoupgrade \
  #   --enable-autorepair \
  #   --spot
  echo "✅ Cluster created!  🚀"
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
echo "🔗 Traffic IP: $TRAFFIC_IP"
echo "🔗 Dev: https://$DOMAIN_DEV"
echo "🔗 Prod: https://$DOMAIN_PROD"

echo "🚀 Helm Releases:"
helm list -A