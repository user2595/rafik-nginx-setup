
# Static Site Deployment with Traefik and Helm


## Overview
This project deploys a static Nginx site behind Traefik Ingress, using Kubernetes and Helm. The site dynamically displays environment-specific messages using Kubernetes Secrets.


## Setup
 **Start Minikube and Install Traefik**
   ```bash
   ./bootstrap.sh
   ```

## Access the Site
Visit `https://dev.domain` or  `https://prod.domain` in your browser. Depending on the environment, you should see:

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
-
- **gcloud-Version**: 358.0.0
- **gke-Version**: 1.21.2-gke.1300
- **Minikube-Version**: v1.35.0
- **Docker-Version**: 27.4.1
- **Kubernetes-Version**: v1.21.2
- **Kubectl-Version**: v1.32.1
- **Helm-Chart-Version**: 34.2.0
- **Traefik-Version**: v3.3.2
- **nginx-Version**: 1.21.0-alpine



## Projektstruktur
```
traefik-nginx-setup/
│
├── static-site/
│   ├── Chart.yaml
│   ├── values-dev.yaml
│   ├── values-prod.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       ├── secret.yaml
│       └── _helpers.tpl
│── traefik/
│   ├── values.yaml
│── cert-manager/
│   ├── values.yaml
|   |── cluster-issuer.yaml
│
├── bootstrap.sh
└── README.md
```

