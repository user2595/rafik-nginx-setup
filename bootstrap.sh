#!/bin/bash

set -e  
set -o pipefail  

PROJECT_ID="k8s-traefik-nginx"
CLUSTER_NAME="gke-static-site"
REGION="europe-west3"
ZONE="europe-west3-a"
NODE_POOL_NAME="default-pool"
EMAIL="tarik.moussa95@gmail.com"
DOMAIN_DEV="dev.kub.eulernest.eu"
DOMAIN_PROD="prod.kub.eulernest.eu"
NUMBER_OF_NODES=3
DISK_SIZE_OF_NODES=20
MACHINE_TYPE="e2-small"




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
if ! gcloud container clusters describe $CLUSTER_NAME --region $REGION &> /dev/null; then
  echo "⏳ Cluster does not exist, creating..."
  gcloud container clusters create-auto $CLUSTER_NAME --region $REGION
  # gcloud container clusters create $CLUSTER_NAME \
  #   --zone $ZONE \
  #   --num-nodes=1 \
  #   --enable-autoscaling --min-nodes=1 --max-nodes=$NUMBER_OF_NODES \
  #   --disk-size=$DISK_SIZE_OF_NODES \
  #   --machine-type=$MACHINE_TYPE \
  #   --disk-type=pd-balanced \
  echo "✅ Cluster created!  🚀"
else
  echo "✅ Cluster already exists!"
fi



echo "🔄 Fetching Kubernetes credentials for $CLUSTER_NAME..."
gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION

echo "🔄 Updating Helm repositories..."
helm repo add traefik https://helm.traefik.io/traefik || true
helm repo add jetstack https://charts.jetstack.io || true
helm repo update

echo "📦 Installing Traefik as Ingress Controller..."
helm upgrade --install traefik traefik/traefik  -n traefik --create-namespace -f ./traefik/values.yaml  --set service.spec.loadBalancerIP=$TRAFFIC_IP

echo "⏳ Waiting for Traefik LoadBalancer..."
kubectl wait --for=condition=Available deployment traefik -n traefik --timeout=600s || true

echo "📦 Installing Cert-Manager for Let's Encrypt..."
helm upgrade --install cert-manager jetstack/cert-manager -n cert-manager --create-namespace -f ./cert-manager/values.yaml

echo "🔑 Creating Let's Encrypt ClusterIssuer..."
kubectl apply -f ./cert-manager/cluster-issuer.yaml

echo "⏳ Waiting for Cert-Manager..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=600s || true

echo "📌 Creating namespaces..."
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -

echo "🌍 Deploying Dev environment with its own domain..."
helm upgrade --install static-site-dev ./static-site -n dev --create-namespace -f ./static-site/values-dev.yaml

echo "🌍 Deploying Prod environment with its own domain..."
helm upgrade --install static-site-prod ./static-site -n prod --create-namespace -f ./static-site/values-prod.yaml

echo "✅ Setup complete! Test your environments:"
echo "🔗 Traffic IP: $TRAFFIC_IP"
echo "🔗 Dev: https://$DOMAIN_DEV"
echo "🔗 Prod: https://$DOMAIN_PROD"




echo "🚀 Helm Releases:"
helm list -A