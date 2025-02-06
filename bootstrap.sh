#!/bin/bash


minikube start --driver=docker --memory=4g --cpus=2

helm repo add traefik https://helm.traefik.io/traefik
helm repo update

helm install traefik traefik/traefik

kubectl create namespace dev
kubectl create namespace prod

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -out tls.crt -keyout tls.key -subj "/CN=localhost"

kubectl create secret tls tls-secret --cert=tls.crt --key=tls.key -n dev
kubectl create secret tls tls-secret --cert=tls.crt --key=tls.key -n prod

helm install static-site ./helm-chart  -n dev   -f ./helm-chart/values-dev.yaml
helm install static-site ./helm-chart  -n prod  -f ./helm-chart/values-prod.yaml


# for Debugging
#minikube tunnel
#minikube tunnel &> /dev/null &
#pkill -f "minikube tunnel"