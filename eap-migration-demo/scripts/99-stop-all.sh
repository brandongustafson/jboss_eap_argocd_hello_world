#!/usr/bin/env bash
# =============================================================================
# 99-stop-all.sh — Stop both EAP servers
# =============================================================================

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo ""
echo "Stopping JBoss EAP servers..."

if [ -f /tmp/eap64.pid ]; then
  PID=$(cat /tmp/eap64.pid)
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    echo -e "${GREEN}  ✓ EAP 6.4 stopped (PID $PID)${NC}"
  else
    echo -e "${YELLOW}  EAP 6.4 was not running${NC}"
  fi
  rm -f /tmp/eap64.pid
fi

if [ -f /tmp/eap74.pid ]; then
  PID=$(cat /tmp/eap74.pid)
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    echo -e "${GREEN}  ✓ EAP 7.4 stopped (PID $PID)${NC}"
  else
    echo -e "${YELLOW}  EAP 7.4 was not running${NC}"
  fi
  rm -f /tmp/eap74.pid
fi

# Belt-and-suspenders: kill any stragglers
pkill -f "jboss-eap-6.4" 2>/dev/null && echo -e "${GREEN}  ✓ Cleaned up EAP 6.4 processes${NC}" || true
pkill -f "jboss-eap-7.4" 2>/dev/null && echo -e "${GREEN}  ✓ Cleaned up EAP 7.4 processes${NC}" || true

echo ""
echo "Done."
echo ""
