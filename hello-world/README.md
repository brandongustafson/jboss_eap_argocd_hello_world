# Hello World Demo

Spring Boot → JBoss EAP 7.4 → Docker → ArgoCD

A single Hello World app that walks through the full local deployment pipeline.
Designed for live customer demos. Everything runs on your laptop.

---

## Prerequisites — Downloads

### 1. Java 11 JDK
**https://adoptium.net/temurin/releases/?version=11&os=mac&arch=aarch64&package=jdk**
Download the `.pkg` file and run the installer.
```bash
java -version
# openjdk version "11.x.x"
```

### 2. Maven 3.x
**https://maven.apache.org/download.cgi**
Download `apache-maven-3.x.x-bin.tar.gz`, then:
```bash
tar -xzf apache-maven-3.x.x-bin.tar.gz -C ~/tools/
echo 'export PATH=$HOME/tools/apache-maven-3.x.x/bin:$PATH' >> ~/.zshrc
source ~/.zshrc
mvn -version
```

### 3. JBoss EAP 7.4 (requires Red Hat login)
**https://access.redhat.com/jbossnetwork/restricted/listSoftware.html**
- Product: **JBoss Enterprise Application Platform**, Version: **7.4**
- Download: **Red Hat JBoss Enterprise Application Platform 7.4** (the plain ZIP, first item)

```bash
mkdir -p ~/jboss-demo
unzip ~/Downloads/jboss-eap-7.4.0.zip -d ~/jboss-demo/
# Add a management user for the admin console
~/jboss-demo/jboss-eap-7.4/bin/add-user.sh -u admin -p Admin1234! -s
```

### 4. Docker Desktop (already installed)
Make sure it's running. Then enable the built-in Kubernetes cluster:
**Docker Desktop → Settings → Kubernetes → Enable Kubernetes → Apply & Restart**

This gives you a local single-node Kubernetes cluster — no extra install needed.

---

## Project Structure

```
hello-world/
├── pom.xml                                   Maven build — WAR packaging
├── Dockerfile                                Multi-stage: JDK build → JRE runtime
├── scripts/
│   └── demo.sh                               Full narrated demo script
├── src/main/
│   ├── java/com/demo/helloworld/
│   │   ├── HelloWorldApplication.java        Main class + JBoss bridge
│   │   └── HelloController.java              GET / → renders hello.html
│   ├── resources/
│   │   ├── templates/hello.html              The page (Thymeleaf)
│   │   └── application.properties
│   └── webapp/WEB-INF/
│       └── jboss-web.xml                     Sets context root on JBoss EAP
└── k8s/
    ├── namespace.yaml                        Kubernetes namespace
    ├── deployment.yaml                       2-replica deployment with health probes
    ├── service.yaml                          ClusterIP service
    ├── ingress.yaml                          Ingress (for future use / OCP migration)
    └── argocd-app.yaml                       ArgoCD Application manifest
```

---

## Running the Demo

### Option A — Full automated walkthrough (recommended for live demos)
```bash
cd hello-world
./scripts/demo.sh
```
Pauses at each step, explains what's happening, runs the commands, validates the result.

### Option B — Manual step by step

#### Step 1 — Build
```bash
mvn clean package -DskipTests
ls -lh target/hello-world.war
```

#### Step 2 — Deploy to JBoss EAP 7.4
```bash
# Terminal 1: start EAP
~/jboss-demo/jboss-eap-7.4/bin/standalone.sh

# Terminal 2: deploy
cp target/hello-world.war ~/jboss-demo/jboss-eap-7.4/standalone/deployments/

# Watch for the .deployed marker
ls ~/jboss-demo/jboss-eap-7.4/standalone/deployments/

# Validate
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/hello-world/
# Open: http://localhost:8080/hello-world/
```
Admin console: http://localhost:9990 (admin / Admin1234!)

#### Step 3 — Docker
```bash
# Build
docker build -t hello-world:1.0.0 .

# Run
docker run -d --name hello-world-demo -p 8080:8080 hello-world:1.0.0

# Validate
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/
# Open: http://localhost:8080/

# Logs
docker logs hello-world-demo

# Stop
docker rm -f hello-world-demo
```

#### Step 4 — Install ArgoCD
```bash
# Create namespace
kubectl create namespace argocd

# Install
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for it
kubectl rollout status deployment/argocd-server -n argocd --timeout=180s

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Expose the UI (run in a separate terminal, keep it running)
kubectl port-forward svc/argocd-server -n argocd 8443:443
# Open: https://localhost:8443  (accept the self-signed cert)
# Login: admin / <password above>
```

#### Step 5 — Deploy via ArgoCD
```bash
# 1. Push this project to GitHub
git remote add origin https://github.com/YOUR_USERNAME/hello-world.git
git push -u origin main

# 2. Update k8s/argocd-app.yaml — set repoURL to your repo

# 3. Apply the ArgoCD Application
kubectl apply -f k8s/argocd-app.yaml

# 4. Watch the sync
argocd login localhost:8443 --username admin --insecure
argocd app get hello-world
argocd app sync hello-world
argocd app wait hello-world --health
```

---

## How It Works

### Why WAR instead of JAR?
JBoss EAP is a full Java EE application server with its own Servlet container
(Undertow). It expects a WAR. The embedded Tomcat is excluded from the WAR
(`scope=provided`) so JBoss's Undertow handles HTTP instead.

### Why does the same WAR run in Docker?
`spring-boot-maven-plugin` repackages the WAR to be executable — it adds a
launcher that starts embedded Tomcat when you run `java -jar hello-world.war`.
JBoss ignores this launcher and uses the WAR structure normally.

### SpringBootServletInitializer
The bridge between Spring Boot and JBoss. When JBoss deploys the WAR, it finds
`HelloWorldApplication` (which extends `SpringBootServletInitializer`) via the
Servlet 3.0 ServiceLoader mechanism and calls `configure()` to bootstrap the
Spring context. No `web.xml` needed.

### ArgoCD GitOps flow
```
git push → ArgoCD detects change → pulls k8s/ manifests → applies to cluster
```
`selfHeal: true` means manual `kubectl` changes get reverted to match Git within ~3 minutes.

---

## Future: Migrating to AWS OCP

When ready to move to OpenShift on AWS:

1. **Push image to ECR**
   ```bash
   aws ecr create-repository --repository-name hello-world
   docker tag hello-world:1.0.0 <account>.dkr.ecr.<region>.amazonaws.com/hello-world:1.0.0
   docker push <account>.dkr.ecr.<region>.amazonaws.com/hello-world:1.0.0
   ```

2. **Update `k8s/deployment.yaml`** — change the `image:` to the ECR URI

3. **Add an OpenShift Route** — replace `k8s/ingress.yaml` with:
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

4. **Point ArgoCD at the OCP cluster** — update `k8s/argocd-app.yaml`:
   ```yaml
   destination:
     server: https://<your-ocp-api-url>:6443
   ```

---

## Troubleshooting

**JBoss deployment fails (`.failed` marker appears)**
```bash
tail -50 ~/jboss-demo/jboss-eap-7.4/standalone/log/server.log | grep -E "ERROR|WARN"
```
Most common cause: Java version mismatch. EAP 7.4 requires Java 8 or 11.

**Docker build fails**
```bash
# Force ARM64 platform explicitly
docker buildx build --platform linux/arm64 -t hello-world:1.0.0 .
```

**ArgoCD app stuck in OutOfSync**
```bash
argocd app sync hello-world --force
```

**Kubernetes not reachable after enabling in Docker Desktop**
Give it 2-3 minutes to start, then:
```bash
kubectl config use-context docker-desktop
kubectl cluster-info
```
