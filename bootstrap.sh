#!/bin/bash

# Minikube starten
minikube start

# Helm-Repo hinzufügen
helm repo add traefik https://helm.traefik.io/traefik
helm repo update

# Traefik installieren
helm install traefik traefik/traefik

# Namespaces erstellen
kubectl create namespace dev
kubectl create namespace prod

# Selbstsigniertes Zertifikat erstellen
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -out tls.crt -keyout tls.key -subj "/CN=localhost"

# Zertifikate als Secrets hinzufügen
kubectl create secret tls tls-secret --cert=tls.crt --key=tls.key -n dev
kubectl create secret tls tls-secret --cert=tls.crt --key=tls.key -n prod
helm install static-site ./helm-chart --set env=dev -n dev
helm install static-site ./helm-chart --set env=prod -n prod
kubectl rollout restart deployment nginx-deployment -n dev
kubectl rollout restart deployment nginx-deployment -n prod

# Minikube Tunnel starten
minikube tunnel
# Minikube Tunnel  Im Hintergrund starten
#minikube tunnel &> /dev/null &
# Minikube Tunnel beenden
#pkill -f "minikube tunnel"