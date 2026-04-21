#!/usr/bin/env bash
# =============================================================================
# demo.sh — End-to-end demo script
#
# Steps:
#   1. Build the Spring Boot WAR with Maven
#   2. Deploy to JBoss EAP 7.4 and validate
#   3. Build Docker image and run in Docker Desktop
#   4. Install ArgoCD on Docker Desktop Kubernetes
#   5. Deploy the app via ArgoCD (GitOps)
#
# Prerequisites (see README for download links):
#   - Java 11
#   - Maven 3.x
#   - JBoss EAP 7.4 extracted to ~/jboss-demo/jboss-eap-7.4/
#   - Docker Desktop (running, Kubernetes enabled)
# =============================================================================

BOLD='\033[1m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; RED='\033[0;31m'; DIM='\033[2m'; NC='\033[0m'

header() {
  clear
  echo ""
  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
  printf "${BOLD}${CYAN}║  %-60s║${NC}\n" "$1"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}
step()    { echo -e "\n${BOLD}${YELLOW}▶  $1${NC}\n"; }
info()    { echo -e "${CYAN}   $1${NC}"; }
success() { echo -e "${GREEN}   ✓  $1${NC}"; }
warn()    { echo -e "${YELLOW}   ⚠  $1${NC}"; }
err()     { echo -e "${RED}   ✗  $1${NC}"; }
run()     { echo -e "${DIM}   \$ $1${NC}"; eval "$1"; }
pause()   { echo -e "\n${DIM}   [ Press ENTER to continue ]${NC}"; read -r; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
EAP74_HOME="${EAP74_HOME:-$HOME/jboss-demo/jboss-eap-7.4}"
IMAGE_NAME="hello-world"
IMAGE_TAG="1.0.0"

# =============================================================================
# Preflight
# =============================================================================
header "Preflight — Checking tools"

PREFLIGHT_OK=true
check() {
  if command -v "$1" &>/dev/null; then
    success "$1 found"
  else
    err "$1 not found — $2"
    PREFLIGHT_OK=false
  fi
}

check java   "Install Java 11: https://adoptium.net/temurin/releases/?version=11&os=mac&arch=aarch64&package=jdk"
check mvn    "Install Maven: https://maven.apache.org/download.cgi"
check docker "Install Docker Desktop: https://www.docker.com/products/docker-desktop/"
check kubectl "Enable Kubernetes in Docker Desktop: Settings → Kubernetes → Enable Kubernetes"

docker info &>/dev/null 2>&1 && success "Docker Desktop is running" \
  || { err "Docker Desktop is not running — start it first"; PREFLIGHT_OK=false; }

kubectl cluster-info &>/dev/null 2>&1 \
  && success "Kubernetes is reachable ($(kubectl config current-context))" \
  || warn "Kubernetes not reachable — Steps 4 and 5 will be skipped. Enable in Docker Desktop Settings."

[ -d "$EAP74_HOME" ] \
  && success "JBoss EAP 7.4 found at $EAP74_HOME" \
  || warn "JBoss EAP 7.4 not found — Step 2 will be skipped"

echo ""
[ "$PREFLIGHT_OK" = false ] && { err "Fix the errors above and re-run."; exit 1; }

pause

# =============================================================================
# STEP 1: Build
# =============================================================================
header "STEP 1 of 5 — Build the Spring Boot WAR"

info "Spring Boot 2.7 app packaged as a WAR."
info "The same WAR is used for both JBoss EAP and Docker."
echo ""
info "Key pom.xml decisions:"
info "  packaging=war                  JBoss EAP expects a WAR, not a JAR"
info "  tomcat scope=provided          Exclude embedded Tomcat; JBoss provides Undertow"
info "  SpringBootServletInitializer   Bridges Spring Boot and JBoss at startup"
echo ""

pause

step "mvn clean package -DskipTests"
cd "$PROJECT_DIR"
mvn clean package -DskipTests

echo ""
success "WAR built"
run "ls -lh target/hello-world.war"

pause

# =============================================================================
# STEP 2: JBoss EAP 7.4
# =============================================================================
header "STEP 2 of 5 — Deploy to JBoss EAP 7.4"

if [ ! -d "$EAP74_HOME" ]; then
  warn "JBoss EAP 7.4 not found at $EAP74_HOME — skipping."
  warn "To set it up:"
  warn "  1. Download jboss-eap-7.4.0.zip from access.redhat.com"
  warn "  2. unzip jboss-eap-7.4.0.zip -d ~/jboss-demo/"
  warn "  3. Re-run this script"
  pause
else
  info "JBoss EAP 7.4 uses Undertow as its web container (replaced Tomcat in EAP 7)."
  info "Hot deploy: drop a WAR into the deployments/ folder and EAP picks it up automatically."
  echo ""

  pkill -f "jboss-eap-7.4" 2>/dev/null && sleep 2 || true

  step "Starting JBoss EAP 7.4..."
  LOG="$EAP74_HOME/standalone/log/server.log"
  rm -f "$LOG"
  "$EAP74_HOME/bin/standalone.sh" > /dev/null 2>&1 &
  EAP_PID=$!
  echo $EAP_PID > /tmp/eap74-demo.pid
  info "EAP started (PID $EAP_PID) — waiting for ready signal..."

  TIMEOUT=90; ELAPSED=0
  until grep -q "WildFly.*started\|JBoss EAP.*started" "$LOG" 2>/dev/null; do
    sleep 2; ELAPSED=$((ELAPSED+2)); echo -n "."
    [ $ELAPSED -ge $TIMEOUT ] && echo "" && err "Timed out. Check: $LOG" && break
  done
  echo ""
  STARTUP_TIME=$(grep -o "in [0-9]*ms" "$LOG" | tail -1 || echo "")
  success "JBoss EAP 7.4 is up $STARTUP_TIME"

  step "Deploying hello-world.war..."
  run "cp target/hello-world.war $EAP74_HOME/standalone/deployments/"

  ELAPSED=0
  until [ -f "$EAP74_HOME/standalone/deployments/hello-world.war.deployed" ]; do
    sleep 2; ELAPSED=$((ELAPSED+2)); echo -n "."
    [ -f "$EAP74_HOME/standalone/deployments/hello-world.war.failed" ] \
      && echo "" && err "Deployment FAILED — check: $LOG" && break
    [ $ELAPSED -ge 30 ] && echo "" && err "Timed out" && break
  done
  echo ""
  success "Deployed!"

  step "Validating..."
  sleep 2
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/hello-world/ || echo "000")
  if [ "$HTTP" = "200" ]; then
    success "HTTP $HTTP — app is live on JBoss EAP 7.4"
    info "  Open in browser: http://localhost:8080/hello-world/"
  else
    warn "Got HTTP $HTTP — check $LOG for errors"
  fi

  pause

  step "Stopping JBoss EAP..."
  kill "$(cat /tmp/eap74-demo.pid)" 2>/dev/null || pkill -f "jboss-eap-7.4" || true
  rm -f /tmp/eap74-demo.pid
  success "JBoss EAP stopped"

  pause
fi

# =============================================================================
# STEP 3: Docker
# =============================================================================
header "STEP 3 of 5 — Build Docker image and run locally"

info "Multi-stage Dockerfile:"
info "  Stage 1 (build)  : eclipse-temurin:11-jdk — compiles the WAR"
info "  Stage 2 (runtime): eclipse-temurin:11-jre  — runs the WAR"
info ""
info "Final image = JRE + WAR only. No Maven, no source code."
info "Non-root user configured (security best practice, required on OCP later)."
echo ""

pause

step "docker build -t $IMAGE_NAME:$IMAGE_TAG ."
run "docker build -t $IMAGE_NAME:$IMAGE_TAG ."

echo ""
success "Image built"
run "docker images $IMAGE_NAME"

pause

step "Running the container on port 8080..."
docker rm -f hello-world-demo 2>/dev/null || true
run "docker run -d --name hello-world-demo -p 8080:8080 $IMAGE_NAME:$IMAGE_TAG"

info "Waiting for Spring Boot to start..."
sleep 8

HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ || echo "000")
if [ "$HTTP" = "200" ]; then
  success "HTTP $HTTP — app is running in Docker!"
  info "  Open in browser: http://localhost:8080/"
else
  warn "Got HTTP $HTTP — checking container logs..."
  docker logs hello-world-demo --tail 20
fi

echo ""
step "Container logs (last 10 lines):"
run "docker logs hello-world-demo --tail 10"

pause

step "Stopping the container..."
run "docker rm -f hello-world-demo"
success "Container stopped"

pause

# =============================================================================
# STEP 4: Install ArgoCD
# =============================================================================
header "STEP 4 of 5 — Install ArgoCD on Docker Desktop Kubernetes"

if ! kubectl cluster-info &>/dev/null 2>&1; then
  warn "Kubernetes not reachable — skipping Steps 4 and 5."
  warn "Enable it: Docker Desktop → Settings → Kubernetes → Enable Kubernetes → Apply"
  pause
else
  info "ArgoCD is a GitOps CD tool for Kubernetes."
  info "It watches a Git repo and keeps the cluster in sync with what's in Git."
  info "Push a change → ArgoCD detects it → applies it to the cluster automatically."
  echo ""

  pause

  step "Creating argocd namespace..."
  run "kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -"

  step "Installing ArgoCD from the official manifest..."
  run "kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

  step "Waiting for ArgoCD server to be ready (~2 minutes)..."
  run "kubectl rollout status deployment/argocd-server -n argocd --timeout=180s"

  echo ""
  ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "not-ready-yet")
  success "ArgoCD installed"
  echo ""
  echo -e "   ${BOLD}Admin password: ${GREEN}$ARGOCD_PASS${NC}"
  echo ""
  warn "Save that password — you need it to log into the UI."

  if ! command -v argocd &>/dev/null; then
    step "Installing ArgoCD CLI..."
    ARCH=$(uname -m)
    [ "$ARCH" = "arm64" ] && ARGOCD_BIN="argocd-darwin-arm64" || ARGOCD_BIN="argocd-darwin-amd64"
    curl -sSL -o /usr/local/bin/argocd \
      "https://github.com/argoproj/argo-cd/releases/latest/download/$ARGOCD_BIN"
    chmod +x /usr/local/bin/argocd
    success "ArgoCD CLI installed"
  else
    success "ArgoCD CLI already installed"
  fi

  echo ""
  step "To open the ArgoCD UI, run this in a separate terminal:"
  echo ""
  echo -e "   ${GREEN}kubectl port-forward svc/argocd-server -n argocd 8444:443${NC}"
  echo ""
  info "Then open: https://localhost:8444  (accept the self-signed cert)"
  info "Login:     admin / $ARGOCD_PASS"
  info ""
  warn "Important: start JBoss EAP before this port-forward."
  warn "JBoss EAP also uses port 8443 for HTTPS.  Using 8444 here avoids the conflict."

  pause
fi

# =============================================================================
# STEP 5: Deploy via ArgoCD
# =============================================================================
header "STEP 5 of 5 — Deploy via ArgoCD (GitOps)"

if ! kubectl cluster-info &>/dev/null 2>&1; then
  warn "Kubernetes not reachable — skipping."
else
  ARGOCD_READY=$(kubectl get deployment argocd-server -n argocd \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

  if [ -z "$ARGOCD_READY" ] || [ "$ARGOCD_READY" = "0" ]; then
    warn "ArgoCD not ready — complete Step 4 first."
  else
    info "k8s/argocd-app.yaml tells ArgoCD:"
    info "  - Which Git repo to watch"
    info "  - Which folder contains the manifests (k8s/)"
    info "  - Which cluster and namespace to deploy into"
    echo ""
    warn "Before applying: update k8s/argocd-app.yaml with your Git repo URL."
    info "  Change: repoURL: https://github.com/YOUR_USERNAME/hello-world.git"
    echo ""

    pause

    step "Applying the ArgoCD Application manifest..."
    run "kubectl apply -f k8s/argocd-app.yaml"

    sleep 5
    step "Sync status:"
    run "kubectl get application hello-world -n argocd"

    echo ""
    info "ArgoCD will pull the manifests from Git and apply them to the cluster."
    info "selfHeal: true means manual kubectl changes get reverted to match Git."
    echo ""
    info "CLI commands to manage the app:"
    echo -e "   ${GREEN}argocd login localhost:8444 --username admin --insecure${NC}"
    echo -e "   ${GREEN}argocd app get hello-world${NC}"
    echo -e "   ${GREEN}argocd app sync hello-world${NC}"
    echo -e "   ${GREEN}argocd app wait hello-world --health${NC}"
  fi
fi

# =============================================================================
# Done
# =============================================================================
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║  Demo complete!                                              ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Covered:"
echo "    ✓ Spring Boot WAR built with Maven"
echo "    ✓ Deployed to JBoss EAP 7.4 and validated"
echo "    ✓ Docker image built and run locally"
echo "    ✓ ArgoCD installed on Docker Desktop Kubernetes"
echo "    ✓ App deployed via ArgoCD GitOps"
echo ""
echo "  Next: migrate to AWS OCP"
echo "    1. Push image to ECR"
echo "    2. Update k8s/deployment.yaml image reference"
echo "    3. Add an OpenShift Route to k8s/"
echo "    4. Point ArgoCD at the OCP cluster"
echo ""
