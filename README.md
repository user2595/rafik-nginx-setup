
# Static Site Deployment with Traefik and Helm



## Overview
This project deploys a static Nginx site behind Traefik Ingress, using Kubernetes and Helm. The site dynamically displays environment-specific messages using Kubernetes Secrets.


## Setup
1. **Start Minikube and Install Traefik**
   ```bash
   ./bootstrap.sh
   ```

2. **Deploy for dev environment**
   ```bash
   helm install static-site ./helm-chart --set env=dev -n dev
   ```

3. **Deploy for prod environment**
   ```bash
   helm install static-site ./helm-chart --set env=prod -n prod
   ```

4. ** for switching between environments**
   ```bash
    kubectl rollout restart deployment nginx-deployment -n dev
    # or
    kubectl rollout restart deployment nginx-deployment -n prod
   ```

5. start the tunnel (termanal must always be open)
   ```bash
   minikube tunnel
   ```

## Access the Site
Visit `https://localhost` in your browser. Depending on the environment, you should see:

- **dev:**
  ```
  Hello World!
  I am on dev. And this is my secret {dev secret}.
  ```
- **prod:**
  ```
  Hello World!
  I am on prod. And this is my secret {prod secret}.
  ```

## teste with version ( on 06.02.2025)
- **Minikube-Version**: v1.35.0
- **Docker-Version**: 20.10.8
- **Kubernetes-Version**: v1.21.2
- **Kubectl-Version**: v1.32.1
- **Helm-Chart-Version**: 34.2.0
- **Traefik-Version**: v3.3.2
- **nginx-Version**: 1.21.0-alpine



## Projektstruktur
```
traefik-nginx-setup/
│
├── helm-chart/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       ├── secret.yaml
│
│
├── bootstrap.sh
└── README.md
```
# Chart.yaml
```
apiVersion: v2
name: static-site
description: A simple static site served by Nginx and Traefik
version: 0.1.0
```
# values.yaml
```
environments:
  dev:
    environment: dev
    secretMessage: "I debug with print statements and caffeine"
  prod:
    environment: prod
    secretMessage: "It worked only on my machine"
```
# templates/secret.yaml
```
apiVersion: v1
kind: Secret
metadata:
  name: site-secret
type: Opaque
stringData:
  message: {{ index .Values.environments (.Values.env | default "dev") "secretMessage" }}
```
# templates/deployment.yaml
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
          env:
          - name: ENVIRONMENT
            value: {{ index .Values.environments (.Values.env | default "dev") "environment" | quote }}
          - name: SECRET_MESSAGE
            valueFrom:
              secretKeyRef:
                name: site-secret
                key: message
          command: ["sh", "-c"]  # Einfache Shell zum Ersetzen der Platzhalter
          args:
           - echo "<html><body><h1>Hello World!</h1><p>I am on $ENVIRONMENT. And this is my secret $SECRET_MESSAGE.</p></body></html>" > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'

```
# templates/service.yaml
```
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```
# templates/ingress.yaml
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress-test
spec:
  tls:
    - hosts:
        - "localhost"
      secretName: tls-secret
  rules:
    - host: localhost
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-service
                port:
                  number: 80

```

# bootstrap.sh
```bash
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

helm install static-site ./helm-chart --set env=dev -n dev
helm install static-site ./helm-chart --set env=prod -n prod

```