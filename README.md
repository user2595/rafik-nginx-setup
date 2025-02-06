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

## Access the Site
Visit `https://localhost` in your browser. Depending on the environment, you should see:

- **dev:**
  ```
  Hello World!
  I am on dev. And this is my dev secret.
  ```
- **prod:**
  ```
  Hello World!
  I am on prod. And this is my prod secret.
  ```




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
│       └── configmap.yaml
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
    secretMessage: "This is my dev secret"
  prod:
    environment: prod
    secretMessage: "This is my prod secret"
```
# templates/secret.yaml
```
apiVersion: v1
kind: Secret
metadata:
  name: site-secret
type: Opaque
stringData:
  message: {{ index .Values.environments .Values.env "secretMessage" }}
```
# templates/deployment.yaml
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
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
        image: nginx:latest
        ports:
        - containerPort: 80
        env:
        - name: ENVIRONMENT
          value: {{ index .Values.environments .Values.env "environment" | quote }}
        - name: SECRET_MESSAGE
          valueFrom:
            secretKeyRef:
              name: site-secret
              key: message
        volumeMounts:
        - name: nginx-config
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-config
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
  name: nginx-ingress
  annotations:
    kubernetes.io/ingress.class: traefik
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
# templates/configmap.yaml
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  index.html: |
    <html>
      <head><title>Environment Info</title></head>
      <body>
        <h1>Hello World!</h1>
        <p>I am on {{ index .Values.environments .Values.env "environment" }}. And this is my {{ index .Values.environments .Values.env "secretMessage" }}.</p>
      </body>
    </html>
```
# bootstrap.sh
```bash
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

# Minikube Tunnel starten
minikube tunnel

```

