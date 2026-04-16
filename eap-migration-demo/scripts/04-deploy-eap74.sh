#!/usr/bin/env bash
# =============================================================================
# 04-deploy-eap74.sh — Start EAP 7.4 and deploy the migrated app
#
# EAP 7.4 runs on port OFFSET +100 so both servers can run simultaneously:
#   HTTP:  8180  (instead of 8080)
#   HTTPS: 8543  (instead of 8443)
#   Admin: 10090 (instead of 9990)
#
# This lets you show both versions side by side in the browser.
# =============================================================================

set -e
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
EAP74_HOME="$HOME/jboss-demo/jboss-eap-7.4"
WAR="$PROJECT_DIR/target/eap-migration-demo-v2-eap74.war"
DEPLOY_DIR="$EAP74_HOME/standalone/deployments"
LOG="$EAP74_HOME/standalone/log/server.log"
PORT_OFFSET=100

echo ""
echo "============================================================"
echo "  Step 4: Deploy migrated app to JBoss EAP 7.4"
echo "============================================================"
echo ""

# ── Preflight checks ──────────────────────────────────────────────────────────
[ -d "$EAP74_HOME" ] || error "EAP 7.4 not found at $EAP74_HOME\n  Run ./scripts/00-setup.sh first."
[ -f "$WAR" ]        || error "WAR not found at $WAR\n  Run ./scripts/03-build-v2-eap74.sh first."

# ── Kill any existing EAP 7.4 process ─────────────────────────────────────────
if pgrep -f "jboss-eap-7.4" > /dev/null 2>&1; then
  warn "Stopping existing EAP 7.4 process..."
  pkill -f "jboss-eap-7.4" || true
  sleep 3
fi

# ── Start EAP 7.4 on offset ports ─────────────────────────────────────────────
info "Starting JBoss EAP 7.4 on port 8180 (offset +100)..."
rm -f "$LOG"

"$EAP74_HOME/bin/standalone.sh" \
  -Djboss.socket.binding.port-offset=$PORT_OFFSET \
  > /dev/null 2>&1 &
EAP74_PID=$!
echo $EAP74_PID > /tmp/eap74.pid
info "EAP 7.4 started with PID $EAP74_PID"

# ── Wait for server to be ready ───────────────────────────────────────────────
info "Waiting for EAP 7.4 to be ready..."
TIMEOUT=90
ELAPSED=0
until grep -q "WildFly.*started\|JBoss EAP.*started" "$LOG" 2>/dev/null; do
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  echo -n "."
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo ""
    error "Timed out waiting for EAP 7.4 to start. Check $LOG for errors."
  fi
done
echo ""

# Show startup time from log — this is a great demo point (Undertow is faster)
STARTUP_TIME=$(grep -o "in [0-9]*ms" "$LOG" | tail -1 || echo "")
success "EAP 7.4 is up and running $STARTUP_TIME"

# ── Deploy the WAR ────────────────────────────────────────────────────────────
info "Deploying eap-migration-demo-v2-eap74.war..."
cp "$WAR" "$DEPLOY_DIR/eap-migration-demo.war"

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
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8180/demo/hello?name=Demo" || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  success "Servlet endpoint responding (HTTP $HTTP_CODE)"
else
  warn "Servlet returned HTTP $HTTP_CODE"
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8180/demo/api/greet?name=Demo" || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  success "REST endpoint responding (HTTP $HTTP_CODE)"
else
  warn "REST endpoint returned HTTP $HTTP_CODE"
fi

# ── Side-by-side comparison ───────────────────────────────────────────────────
echo ""
echo "============================================================"
echo -e "  \033[0;32mBoth servers are now running!\033[0m"
echo "============================================================"
echo ""
echo "  ┌─────────────────────────────────────────────────────┐"
echo "  │  EAP 6.4 (v1 — original)      EAP 7.4 (v2 — migrated) │"
echo "  ├─────────────────────────────────────────────────────┤"
echo "  │  http://localhost:8080/demo/   http://localhost:8180/demo/  │"
echo "  │  Admin: localhost:9990         Admin: localhost:10090        │"
echo "  └─────────────────────────────────────────────────────┘"
echo ""
echo "  REST comparison:"
echo "    EAP 6.4: curl http://localhost:8080/demo/api/greet?name=You"
echo "    EAP 7.4: curl http://localhost:8180/demo/api/greet?name=You"
echo ""
echo "  Next: Run ./scripts/05-show-diff.sh to walk through what changed"
echo ""
