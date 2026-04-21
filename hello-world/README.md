# Hello World - JBoss EAP + Docker + Kubernetes + ArgoCD

A Spring Boot Hello World application that demonstrates the full modern Java deployment pipeline.  The same WAR artifact runs on JBoss EAP 7.4, inside a Docker container, and on Kubernetes managed by ArgoCD.

Repository: [https://github.com/brandongustafson/jboss_eap_argocd_hello_world](https://github.com/brandongustafson/jboss_eap_argocd_hello_world)

---

## What This Demonstrates

- Building a Spring Boot WAR deployable to both JBoss EAP and Docker
- Deploying and validating on JBoss EAP 7.4 (Undertow web container)
- Containerizing with a multi-stage Docker build
- Running on Kubernetes via Docker Desktop
- GitOps continuous delivery with ArgoCD

---

## Project Structure

```
hello-world/
├── pom.xml                                        Maven build - WAR packaging, Tomcat excluded
├── Dockerfile                                     Multi-stage build: Maven compile + JRE runtime
├── README.md                                      This file
├── scripts/
│   └── demo.sh                                    End-to-end automated demo script
├── src/main/
│   ├── java/com/demo/helloworld/
│   │   ├── HelloWorldApplication.java             Main class + SpringBootServletInitializer
│   │   └── HelloController.java                   MVC controller, renders hello.html
│   ├── resources/
│   │   ├── templates/hello.html                   Thymeleaf HTML page
│   │   └── application.properties                 Spring Boot configuration
│   └── webapp/WEB-INF/
│       ├── jboss-web.xml                          Sets context root on JBoss EAP
│       └── jboss-deployment-structure.xml         Excludes JBoss logging modules (fixes SLF4J conflict)
└── k8s/
    ├── namespace.yaml                             Kubernetes namespace
    ├── deployment.yaml                            2-replica deployment with health probes
    ├── service.yaml                               ClusterIP service
    └── ingress.yaml                               Ingress definition (reference for future use)
```

---

## Prerequisites

### Java 11

Download Temurin JDK 11 for macOS ARM (Apple Silicon):

**https://adoptium.net/temurin/releases/?version=11&os=mac&arch=aarch64&package=jdk**

Download the `.pkg` file and run the installer.  Verify:

```bash
java -version
# openjdk version "11.x.x"
```

### Maven 3.x

Download from: **https://maven.apache.org/download.cgi**

Get `apache-maven-3.x.x-bin.tar.gz`, then:

```bash
tar -xzf apache-maven-3.x.x-bin.tar.gz -C ~/tools/
echo 'export PATH="$HOME/tools/apache-maven-3.x.x/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
mvn -version
```

### JBoss EAP 7.4 (requires Red Hat account)

Download from: **https://access.redhat.com/jbossnetwork/restricted/listSoftware.html**

- Product: JBoss Enterprise Application Platform
- Version: 7.4
- File: `Red Hat JBoss Enterprise Application Platform 7.4` (the plain ZIP, first item in the list)

```bash
mkdir -p ~/jboss-demo
unzip ~/Downloads/jboss-eap-7.4.0.zip -d ~/jboss-demo/
~/jboss-demo/jboss-eap-7.4/bin/add-user.sh -u admin -p Admin1234! -s
```

### Docker Desktop

Already installed.  Make sure it is running.

Enable the built-in Kubernetes cluster:

**Docker Desktop > Settings > Kubernetes > Enable Kubernetes > Apply and Restart**

This provides a local single-node Kubernetes cluster with no additional install required.

### ArgoCD CLI

```bash
mkdir -p ~/bin
curl -sSL -o ~/bin/argocd \
  https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-arm64
chmod +x ~/bin/argocd
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
argocd version --client --short
```

---

## Step-by-Step Setup

### Step 1 - Build the WAR

```bash
cd hello-world
mvn clean package -DskipTests
ls -lh target/hello-world.war
```

### Step 2 - Deploy to JBoss EAP 7.4

```bash
# Terminal 1: start EAP
~/jboss-demo/jboss-eap-7.4/bin/standalone.sh

# Terminal 2: deploy
cp target/hello-world.war \
  ~/jboss-demo/jboss-eap-7.4/standalone/deployments/

# Watch for the .deployed marker
ls ~/jboss-demo/jboss-eap-7.4/standalone/deployments/

# Validate
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/hello-world/
```

Open in browser: **http://localhost:8080/hello-world/**

Admin console: **http://localhost:9990** (admin / Admin1234!)

### Step 3 - Build and run the Docker image

```bash
# Build
docker build -t hello-world:1.0.0 .

# Run (use port 8081 if JBoss is already on 8080)
docker run -d --name hello-world-demo -p 8081:8080 hello-world:1.0.0

# Validate
curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/

# Logs
docker logs hello-world-demo

# Stop
docker rm -f hello-world-demo
```

### Step 4 - Install ArgoCD on Kubernetes

```bash
# Create namespace
kubectl create namespace argocd

# Install from official manifest
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for server to be ready
kubectl rollout status deployment/argocd-server -n argocd --timeout=180s

# Get the generated admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Expose the UI (run in a separate terminal, keep it running)
# Note: use port 8444 to avoid conflict with JBoss EAP which also uses 8443
kubectl port-forward svc/argocd-server -n argocd 8444:443
```

Open the UI: **https://localhost:8444** (accept the self-signed certificate)

Login: `admin` / (password from the command above)

### Step 5 - Deploy via ArgoCD

```bash
# Log in via CLI
argocd login localhost:8444 --username admin --insecure

# Create the application
argocd app create hello-world \
  --repo https://github.com/brandongustafson/jboss_eap_argocd_hello_world.git \
  --path hello-world/k8s \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace hello-world \
  --sync-policy automated \
  --auto-prune \
  --self-heal

# Watch the sync
argocd app get hello-world
argocd app wait hello-world --health

# Validate
kubectl get pods -n hello-world
kubectl port-forward svc/hello-world -n hello-world 8082:80
curl -s -o /dev/null -w "%{http_code}" http://localhost:8082/
```

---

## How It Works

### Why WAR instead of JAR?

JBoss EAP is a full Java EE application server with its own Servlet container (Undertow).  It expects a WAR file.  The embedded Tomcat is excluded from the WAR (`scope=provided`) so JBoss's Undertow handles HTTP instead of the bundled Tomcat.

### Why does the same WAR run in Docker?

`spring-boot-maven-plugin` repackages the WAR to be executable.  It adds a launcher that starts the embedded Tomcat when you run `java -jar hello-world.war`.  JBoss ignores this launcher and uses the WAR structure normally.  This means one artifact works in both environments.

### SpringBootServletInitializer

This is the bridge between Spring Boot and JBoss EAP.  When JBoss deploys the WAR, it finds `HelloWorldApplication` (which extends `SpringBootServletInitializer`) via the Servlet 3.0 ServiceLoader mechanism and calls `configure()` to bootstrap the Spring context.  No `web.xml` is needed.

### jboss-deployment-structure.xml

JBoss EAP ships its own SLF4J binding (`slf4j-jboss-logmanager`).  Spring Boot bundles Logback.  When both are on the classpath, SLF4J throws a conflict at startup.  This file tells JBoss to exclude its logging modules from this deployment so Spring Boot's Logback is the only logging implementation.

### Multi-stage Dockerfile

Stage 1 uses `maven:3.9-eclipse-temurin-11` to compile the WAR.  Stage 2 uses `eclipse-temurin:11-jre` to run it.  The final image contains only the JRE and the WAR.  No Maven, no source code, no build tools.  This keeps the image small and reduces the attack surface.

### ArgoCD GitOps flow

```
git push -> ArgoCD detects change -> pulls k8s/ manifests -> applies to cluster
```

`selfHeal: true` means if someone manually runs `kubectl apply` and changes something, ArgoCD reverts it back to match Git within approximately 3 minutes.  Git is the single source of truth.

---

## Ports at a Glance

| Service | Port | URL |
|---------|------|-----|
| JBoss EAP 7.4 | 8080 | http://localhost:8080/hello-world/ |
| Docker container | 8081 | http://localhost:8081/ |
| Kubernetes (port-forward) | 8082 | http://localhost:8082/ |
| JBoss admin console | 9990 | http://localhost:9990 |
| ArgoCD UI | 8444 | https://localhost:8444 |

---

## Future: Migrating to AWS OpenShift (OCP)

When ready to move to OpenShift on AWS:

**1. Push image to ECR**

```bash
aws ecr create-repository --repository-name hello-world
docker tag hello-world:1.0.0 \
  <account>.dkr.ecr.<region>.amazonaws.com/hello-world:1.0.0
docker push \
  <account>.dkr.ecr.<region>.amazonaws.com/hello-world:1.0.0
```

**2. Update `k8s/deployment.yaml`** - change the `image:` field to the ECR URI

**3. Replace `k8s/ingress.yaml` with an OpenShift Route**

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: hello-world
  namespace: hello-world
spec:
  to:
    kind: Service
    name: hello-world
  port:
    targetPort: http
  tls:
    termination: edge
```

**4. Point ArgoCD at the OCP cluster**

```bash
argocd cluster add <ocp-context-name>
argocd app set hello-world \
  --dest-server https://<your-ocp-api-url>:6443
```

---

## Troubleshooting

**JBoss deployment fails (.failed marker appears)**

```bash
tail -50 ~/jboss-demo/jboss-eap-7.4/standalone/log/server.log \
  | grep -E "ERROR|Caused by"
```

Most common cause: Java version mismatch.  EAP 7.4 requires Java 8 or 11.

Second most common: SLF4J conflict.  Ensure `jboss-deployment-structure.xml` is present in `WEB-INF/`.

**Docker build fails on ARM**

```bash
docker buildx build --platform linux/arm64 -t hello-world:1.0.0 .
```

**ArgoCD app stuck in OutOfSync**

```bash
argocd app sync hello-world --force
```

**Kubernetes pods in CreateContainerConfigError**

Check the security context.  The deployment requires `runAsUser: 1000` alongside `runAsNonRoot: true` so Kubernetes can verify the user is non-root by UID rather than by name.

**ArgoCD session expired**

```bash
argocd login localhost:8444 --username admin --insecure
```
