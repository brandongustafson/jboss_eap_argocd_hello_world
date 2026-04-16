#!/usr/bin/env bash
# =============================================================================
# 02-deploy-eap64.sh — Start EAP 6.4 and deploy the v1 app
#
# This script:
#   1. Starts JBoss EAP 6.4 in the background
#   2. Waits for it to be ready
#   3. Deploys the v1 WAR via file copy (hot deploy)
#   4. Verifies the app is accessible
#   5. Prints the URLs to test
# =============================================================================

set -e
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
EAP64_HOME="$HOME/jboss-demo/jboss-eap-6.4"
WAR="$PROJECT_DIR/target/eap-migration-demo-v1-eap64.war"
DEPLOY_DIR="$EAP64_HOME/standalone/deployments"
LOG="$EAP64_HOME/standalone/log/server.log"

echo ""
echo "============================================================"
echo "  Step 2: Deploy v1 app to JBoss EAP 6.4"
echo "============================================================"
echo ""

# ── Preflight checks ──────────────────────────────────────────────────────────
[ -d "$EAP64_HOME" ] || error "EAP 6.4 not found at $EAP64_HOME\n  Run ./scripts/00-setup.sh first."
[ -f "$WAR" ]        || error "WAR not found at $WAR\n  Run ./scripts/01-build-v1-eap64.sh first."

# ── Kill any existing EAP 6.4 process ─────────────────────────────────────────
if pgrep -f "jboss-eap-6.4" > /dev/null 2>&1; then
  warn "Stopping existing EAP 6.4 process..."
  pkill -f "jboss-eap-6.4" || true
  sleep 3
fi

# ── Start EAP 6.4 ─────────────────────────────────────────────────────────────
info "Starting JBoss EAP 6.4 on port 8080..."
# Clear old log so we can watch for startup
rm -f "$LOG"

"$EAP64_HOME/bin/standalone.sh" > /dev/null 2>&1 &
EAP64_PID=$!
echo $EAP64_PID > /tmp/eap64.pid
info "EAP 6.4 started with PID $EAP64_PID"

# ── Wait for server to be ready ───────────────────────────────────────────────
info "Waiting for EAP 6.4 to be ready (watching server.log)..."
TIMEOUT=90
ELAPSED=0
until grep -q "JBoss EAP.*started" "$LOG" 2>/dev/null; do
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  echo -n "."
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo ""
    error "Timed out waiting for EAP 6.4 to start. Check $LOG for errors."
  fi
done
echo ""
success "EAP 6.4 is up and running"

# ── Deploy the WAR ────────────────────────────────────────────────────────────
info "Deploying eap-migration-demo-v1-eap64.war..."
cp "$WAR" "$DEPLOY_DIR/eap-migration-demo.war"

# Wait for deployment marker
ELAPSED=0
until [ -f "$DEPLOY_DIR/eap-migration-demo.war.deployed" ]; do
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  echo -n "."
  if [ $ELAPSED -ge 30 ]; then
    echo ""
    if [ -f "$DEPLOY_DIR/eap-migration-demo.war.failed" ]; then
      error "Deployment FAILED. Check $LOG for details."
    fi
    error "Timed out waiting for deployment."
  fi
done
echo ""
success "App deployed successfully"

# ── Verify with curl ──────────────────────────────────────────────────────────
info "Verifying app is responding..."
sleep 2
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/demo/hello?name=Demo" || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  success "Servlet endpoint responding (HTTP $HTTP_CODE)"
else
  warn "Servlet returned HTTP $HTTP_CODE — check the server log if unexpected"
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/demo/api/greet?name=Demo" || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  success "REST endpoint responding (HTTP $HTTP_CODE)"
else
  warn "REST endpoint returned HTTP $HTTP_CODE"
fi

# ── Print results ─────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo -e "  \033[0;32mEAP 6.4 is running with the v1 app deployed!\033[0m"
echo "============================================================"
echo ""
echo "  App URLs (EAP 6.4 — port 8080):"
echo "    Home page:  http://localhost:8080/demo/"
echo "    Servlet:    http://localhost:8080/demo/hello?name=YourName"
echo "    REST:       http://localhost:8080/demo/api/greet?name=YourName"
echo ""
echo "  Admin console: http://localhost:9990"
echo "  Credentials:   admin / Admin1234!"
echo ""
echo "  Server log:    $LOG"
echo "  Stop server:   kill \$(cat /tmp/eap64.pid)"
echo ""
echo "  Next: Run ./scripts/03-build-v2-eap74.sh"
echo ""
