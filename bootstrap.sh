#!/bin/bash

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


create_uptime_check() {
  local SERVICE_NAME=$1
  local URL=$2

  echo "🔍 Erstelle Google Cloud Uptime Check für $SERVICE_NAME ($URL)..."

  gcloud monitoring uptime-checks create http $SERVICE_NAME-uptime-check \
    --display-name="$SERVICE_NAME Uptime Check" \
    --http-check-path="/" \
    --http-check-port=443 \
    --http-check-use-ssl \
    --resource-type="uptime_url" \
    --project=$PROJECT_ID \
    --monitored-resource-labels=project_id=$PROJECT_ID,url=$URL

  echo "✅ Uptime Check für $SERVICE_NAME erstellt!"
}

check_cert_status() {
  local CERT_NAME=$1
  local NAMESPACE=$2

  STATUS=$(kubectl get certificate -n $NAMESPACE $CERT_NAME -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')

  if [ "$STATUS" == "True" ]; then
    echo "✅ Zertifikat $CERT_NAME ist gültig!"
  else
    echo "❌ WARNUNG: Zertifikat $CERT_NAME ist NICHT bereit!"
  fi
}

check_clusterissuer_status() {
  local ISSUER_NAME=$1

  STATUS=$(kubectl get clusterissuer $ISSUER_NAME -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')

  if [ "$STATUS" == "True" ]; then
    echo "✅ ClusterIssuer $ISSUER_NAME ist bereit!"
  else
    echo "❌ WARNUNG: ClusterIssuer $ISSUER_NAME ist NICHT bereit!"
    echo "🔍 Überprüfe die Logs mit: kubectl describe clusterissuer $ISSUER_NAME"
  fi
}




set -e
set -o pipefail




echo "🚀 Setting up Google Cloud project..."
gcloud components install gke-gcloud-auth-plugin -q
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
helm repo add traefik https://helm.traefik.io/traefik || true
helm repo add jetstack https://charts.jetstack.io || true
helm repo update

echo "📦 Installing Traefik as Ingress Controller..."
helm upgrade --install traefik traefik/traefik  -n traefik --create-namespace -f ./traefik/values.yaml

echo "⏳ Waiting for Traefik LoadBalancer..."
kubectl wait --for=condition=Available deployment traefik -n traefik --timeout=600s || true

echo "📦 Installing Cert-Manager for Let's Encrypt..."
helm upgrade --install cert-manager jetstack/cert-manager -n cert-manager --create-namespace -f ./cert-manager/values.yaml

echo "🔑 Creating Let's Encrypt ClusterIssuer..."
kubectl apply -f ./cluster-issuer.yaml

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


# health check
echo "🔗 Creating health check for Traefik LoadBalancer..."
gcloud compute health-checks create http traefik-health-check \
    --port 80 \
    --request-path "/" \
    --check-interval 10s \
    --timeout 3s


echo "🔗 Creating backend service for Traefik LoadBalancer..."
gcloud compute backend-services create traefik-backend \
    --protocol HTTP \
    --global \
    --port-name http \
    --load-balancing-scheme EXTERNAL \
    --health-checks traefik-health-check


echo "🔗 Adding backend service to URL map..."
create_uptime_check "dev" "https://$DOMAIN_DEV"
create_uptime_check "prod" "https://$DOMAIN_PROD"

echo "🔗 Creating URL map for Traefik LoadBalancer..."
check_cert_status "tls-secret-dev" "dev"
check_cert_status "tls-secret-prod" "prod"

check_clusterissuer_status "letsencrypt-prod"
echo "🔗 Creating e-mail notification"
gcloud monitoring notification-channels create-email \
  --display-name="Uptime Alert" \
  --email-address="$EMAIL" \

