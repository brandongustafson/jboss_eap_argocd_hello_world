#!/usr/bin/env bash
# =============================================================================
# 00-setup.sh — One-time environment setup for the EAP migration demo
#
# What this script does:
#   1. Creates the ~/jboss-demo working directory
#   2. Checks for required tools (Java, Maven)
#   3. Extracts EAP 6.4 and EAP 7.4 from ZIPs you downloaded manually
#   4. Adds a management user to each server (needed for the web console)
#   5. Verifies both servers start correctly
#
# BEFORE RUNNING:
#   Download both ZIPs from https://access.redhat.com (free account required):
#     - jboss-eap-6.4.0.zip
#     - jboss-eap-7.4.0.zip
#   Place them in ~/Downloads/
# =============================================================================

set -e  # Exit immediately on any error

# ── Colors for readable output ────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

DEMO_DIR="$HOME/jboss-demo"
DOWNLOADS="$HOME/Downloads"
EAP64_ZIP="$DOWNLOADS/jboss-eap-6.4.0.zip"
EAP74_ZIP="$DOWNLOADS/jboss-eap-7.4.0.zip"
EAP64_HOME="$DEMO_DIR/jboss-eap-6.4"
EAP74_HOME="$DEMO_DIR/jboss-eap-7.4"

echo ""
echo "============================================================"
echo "  JBoss EAP Migration Demo — Environment Setup"
echo "============================================================"
echo ""

# ── Step 1: Check prerequisites ───────────────────────────────────────────────
info "Checking prerequisites..."

if ! command -v java &>/dev/null; then
  error "Java not found. Install Java 8 or 11 first.\n  brew install openjdk@11"
fi
JAVA_VER=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
success "Java found: $JAVA_VER"

if ! command -v mvn &>/dev/null; then
  error "Maven not found. Install it first.\n  brew install maven"
fi
MVN_VER=$(mvn -version 2>&1 | head -1)
success "Maven found: $MVN_VER"

if ! command -v unzip &>/dev/null; then
  error "unzip not found. Install it first.\n  brew install unzip"
fi

# ── Step 2: Check downloads exist ─────────────────────────────────────────────
info "Checking for EAP ZIP files in $DOWNLOADS..."

if [ ! -f "$EAP64_ZIP" ]; then
  echo ""
  echo -e "${RED}  ✗ Missing: $EAP64_ZIP${NC}"
  echo ""
  echo "  Download JBoss EAP 6.4 from:"
  echo "  https://access.redhat.com/jbossnetwork/restricted/listSoftware.html"
  echo "  → Product: JBoss Enterprise Application Platform"
  echo "  → Version: 6.4"
  echo "  → File:    jboss-eap-6.4.0.zip"
  echo ""
  error "Please download the file and re-run this script."
fi
success "Found EAP 6.4 ZIP"

if [ ! -f "$EAP74_ZIP" ]; then
  echo ""
  echo -e "${RED}  ✗ Missing: $EAP74_ZIP${NC}"
  echo ""
  echo "  Download JBoss EAP 7.4 from:"
  echo "  https://access.redhat.com/jbossnetwork/restricted/listSoftware.html"
  echo "  → Product: JBoss Enterprise Application Platform"
  echo "  → Version: 7.4"
  echo "  → File:    jboss-eap-7.4.0.zip"
  echo ""
  error "Please download the file and re-run this script."
fi
success "Found EAP 7.4 ZIP"

# ── Step 3: Create demo directory and extract ──────────────────────────────────
info "Creating demo directory at $DEMO_DIR..."
mkdir -p "$DEMO_DIR"

if [ -d "$EAP64_HOME" ]; then
  warn "EAP 6.4 already extracted at $EAP64_HOME — skipping."
else
  info "Extracting EAP 6.4 (this may take a moment)..."
  unzip -q "$EAP64_ZIP" -d "$DEMO_DIR"
  success "EAP 6.4 extracted to $EAP64_HOME"
fi

if [ -d "$EAP74_HOME" ]; then
  warn "EAP 7.4 already extracted at $EAP74_HOME — skipping."
else
  info "Extracting EAP 7.4 (this may take a moment)..."
  unzip -q "$EAP74_ZIP" -d "$DEMO_DIR"
  success "EAP 7.4 extracted to $EAP74_HOME"
fi

# ── Step 4: Add management users ──────────────────────────────────────────────
# This lets you log into the web admin console at http://localhost:9990 (EAP 6.4)
# and http://localhost:10090 (EAP 7.4, offset by 100)
info "Adding management user 'admin' to EAP 6.4..."
"$EAP64_HOME/bin/add-user.sh" -u admin -p Admin1234! -s 2>/dev/null || \
  warn "User may already exist on EAP 6.4 — continuing."
success "EAP 6.4 management user ready (admin / Admin1234!)"

info "Adding management user 'admin' to EAP 7.4..."
"$EAP74_HOME/bin/add-user.sh" -u admin -p Admin1234! -s 2>/dev/null || \
  warn "User may already exist on EAP 7.4 — continuing."
success "EAP 7.4 management user ready (admin / Admin1234!)"

# ── Step 5: Make all scripts executable ───────────────────────────────────────
chmod +x "$EAP64_HOME/bin/"*.sh
chmod +x "$EAP74_HOME/bin/"*.sh

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo -e "  ${GREEN}Setup complete!${NC}"
echo "============================================================"
echo ""
echo "  EAP 6.4 home: $EAP64_HOME"
echo "  EAP 7.4 home: $EAP74_HOME"
echo ""
echo "  Next steps:"
echo "    1. Run ./scripts/01-build-v1-eap64.sh   — build the EAP 6.4 app"
echo "    2. Run ./scripts/02-deploy-eap64.sh      — start EAP 6.4 and deploy"
echo "    3. Run ./scripts/03-build-v2-eap74.sh    — apply migration changes"
echo "    4. Run ./scripts/04-deploy-eap74.sh      — start EAP 7.4 and deploy"
echo "    5. Run ./scripts/05-show-diff.sh         — show what changed"
echo ""
