#!/usr/bin/env bash
# =============================================================================
# 05-show-diff.sh — Live walkthrough of every migration change
#
# This is your PRESENTATION SCRIPT. Run it during the demo to walk through
# each change with color-coded diffs and explanations.
#
# It also hits both live servers and shows the responses side by side.
# =============================================================================

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

pause() {
  echo ""
  echo -e "${DIM}  [ Press ENTER to continue ]${NC}"
  read -r
}

header() {
  echo ""
  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${CYAN}║  $1${NC}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

subheader() {
  echo ""
  echo -e "${BOLD}${YELLOW}  ── $1 ──${NC}"
  echo ""
}

removed() { echo -e "${RED}  - $1${NC}"; }
added()   { echo -e "${GREEN}  + $1${NC}"; }
note()    { echo -e "${CYAN}  ℹ  $1${NC}"; }
label()   { echo -e "${BOLD}  $1${NC}"; }

clear

echo ""
echo -e "${BOLD}  JBoss EAP 6.4 → 7.4 Migration Demo${NC}"
echo -e "${DIM}  Walkthrough of every change made during migration${NC}"
echo ""
echo "  We have two servers running right now:"
echo "    EAP 6.4 → http://localhost:8080/demo/"
echo "    EAP 7.4 → http://localhost:8180/demo/"
echo ""

pause

# =============================================================================
header "OVERVIEW: What changed between EAP 6.4 and EAP 7.4"
# =============================================================================

echo "  Component         EAP 6.4              EAP 7.4"
echo "  ─────────────────────────────────────────────────────"
echo "  Java EE           6                    7"
echo "  Servlet           3.0                  3.1"
echo "  JAX-RS            1.1 (RESTEasy 2.x)   2.0 (RESTEasy 3.x)"
echo "  CDI               1.0                  1.2"
echo "  JPA               2.0                  2.1"
echo "  EJB               3.1                  3.2"
echo "  Web Container     JBoss Web (Tomcat)   Undertow"
echo "  Java Support      Java 6, 7, 8         Java 8, 11"
echo ""
echo "  Files changed in this migration:"
echo "    ✓ web.xml              (Servlet version + RESTEasy config)"
echo "    ✓ beans.xml            (CDI schema + bean-discovery-mode)"
echo "    ✗ LegacyRestConfig.java  DELETED"
echo "    + RestApplication.java   CREATED"
echo "    ~ GreetingResource.java  updated"
echo "    ~ GreetingService.java   updated"

pause

# =============================================================================
header "CHANGE 1: web.xml — The biggest visible change"
# =============================================================================

subheader "EAP 6.4 version (BEFORE)"
label "Schema:"
removed 'xmlns="http://java.sun.com/xml/ns/javaee"'
removed 'version="3.0"'
echo ""
label "RESTEasy manual servlet (REMOVED in EAP 7.4):"
removed "<servlet>"
removed "  <servlet-class>org.jboss.resteasy.plugins.server.servlet.HttpServletDispatcher</servlet-class>"
removed "  <init-param>"
removed "    <param-name>javax.ws.rs.Application</param-name>"
removed "    <param-value>com.demo.LegacyRestConfig</param-value>"
removed "  </init-param>"
removed "</servlet>"
removed "<servlet-mapping>..."
echo ""

subheader "EAP 7.4 version (AFTER)"
label "Schema:"
added 'xmlns="http://xmlns.jcp.org/xml/ns/javaee"'
added 'version="3.1"'
echo ""
label "RESTEasy config:"
added "<!-- Nothing here. RestApplication.java handles it. -->"
echo ""

note "The java.sun.com namespace was deprecated when Oracle transferred"
note "Java EE to the Eclipse Foundation. xmlns.jcp.org is the correct"
note "namespace for Java EE 7 and later."
note ""
note "Servlet 3.1 adds non-blocking I/O (ReadListener/WriteListener)"
note "useful for streaming and handling slow clients efficiently."

pause

# =============================================================================
header "CHANGE 2: LegacyRestConfig.java DELETED → RestApplication.java CREATED"
# =============================================================================

subheader "EAP 6.4: LegacyRestConfig.java (DELETED)"
removed "public class LegacyRestConfig extends Application {"
removed "  @Override"
removed "  public Set<Class<?>> getClasses() {"
removed "    Set<Class<?>> classes = new HashSet<>();"
removed "    classes.add(GreetingResource.class);  // must manually list EVERY resource"
removed "    return classes;"
removed "  }"
removed "}"
echo ""
note "Problem: Every new @Path class had to be manually registered here."
note "Forget one? It silently doesn't work. No error, no warning."
echo ""

subheader "EAP 7.4: RestApplication.java (CREATED)"
added "@ApplicationPath(\"/api\")"
added "public class RestApplication extends Application {"
added "  // Empty — EAP 7.4 scans and registers all @Path classes automatically"
added "}"
echo ""
note "That's the entire file. One annotation, no maintenance burden."
note "Add a new @Path class anywhere in the project — it just works."

pause

# =============================================================================
header "CHANGE 3: beans.xml — CDI 1.0 → CDI 1.2"
# =============================================================================

subheader "EAP 6.4 (BEFORE)"
removed 'xmlns="http://java.sun.com/xml/ns/javaee"'
removed 'xsi:schemaLocation="...beans_1_0.xsd"'
removed "<!-- No bean-discovery-mode attribute in CDI 1.0 -->"
echo ""

subheader "EAP 7.4 (AFTER)"
added 'xmlns="http://xmlns.jcp.org/xml/ns/javaee"'
added 'xsi:schemaLocation="...beans_1_1.xsd"'
added 'bean-discovery-mode="all"'
echo ""

note "CDI 1.2 changed the DEFAULT bean-discovery-mode to 'annotated'."
note "This means only classes with @ApplicationScoped, @RequestScoped, etc."
note "are discovered automatically."
note ""
note "Setting it to 'all' preserves the EAP 6.4 behavior and is the"
note "safest migration path. You can tighten it later once you've"
note "audited all your CDI beans."

pause

# =============================================================================
header "LIVE DEMO: Both servers responding"
# =============================================================================

subheader "Hitting EAP 6.4 REST endpoint (port 8080)"
echo -e "${DIM}  curl http://localhost:8080/demo/api/greet?name=Customer${NC}"
echo ""
RESPONSE_64=$(curl -s "http://localhost:8080/demo/api/greet?name=Customer" 2>/dev/null || echo '{"error": "EAP 6.4 not running"}')
echo "  Response: $RESPONSE_64"
echo ""

subheader "Hitting EAP 7.4 REST endpoint (port 8180)"
echo -e "${DIM}  curl http://localhost:8180/demo/api/greet?name=Customer${NC}"
echo ""
RESPONSE_74=$(curl -s "http://localhost:8180/demo/api/greet?name=Customer" 2>/dev/null || echo '{"error": "EAP 7.4 not running"}')
echo "  Response: $RESPONSE_74"
echo ""

note "Same WAR structure, same endpoints, same behavior — just migrated."

pause

# =============================================================================
header "BONUS: What you get for free after migrating to EAP 7.4"
# =============================================================================

echo "  JAX-RS 2.0 Client API (no more Apache HttpClient boilerplate):"
echo ""
echo -e "${GREEN}    Client client = ClientBuilder.newClient();${NC}"
echo -e "${GREEN}    String result = client.target(\"http://other-service/api/data\")${NC}"
echo -e "${GREEN}                          .request(MediaType.APPLICATION_JSON)${NC}"
echo -e "${GREEN}                          .get(String.class);${NC}"
echo ""
echo "  Standard ContainerRequestFilter for auth/logging:"
echo ""
echo -e "${GREEN}    @Provider${NC}"
echo -e "${GREEN}    public class LoggingFilter implements ContainerRequestFilter {${NC}"
echo -e "${GREEN}        public void filter(ContainerRequestContext ctx) {${NC}"
echo -e "${GREEN}            System.out.println(ctx.getMethod() + \" \" + ctx.getUriInfo().getPath());${NC}"
echo -e "${GREEN}        }${NC}"
echo -e "${GREEN}    }${NC}"
echo ""
echo "  JPA 2.1 — Criteria API updates, stored procedure support,"
echo "  attribute converters, and entity graphs for fetch optimization."
echo ""
echo "  Undertow — significantly faster startup, lower memory footprint,"
echo "  built-in WebSocket support, HTTP/2 ready."

pause

# =============================================================================
header "MIGRATION TOOL: Red Hat MTA"
# =============================================================================

echo "  For real-world apps, Red Hat provides the Migration Toolkit"
echo "  for Applications (MTA) — a CLI tool that scans your WAR/EAR"
echo "  and generates a report of every migration issue."
echo ""
echo "  Download: https://developers.redhat.com/products/mta/overview"
echo ""
echo "  Basic usage:"
echo -e "${GREEN}    ./mta-cli --input my-app.war \\${NC}"
echo -e "${GREEN}              --source eap6 \\${NC}"
echo -e "${GREEN}              --target eap7 \\${NC}"
echo -e "${GREEN}              --output ./mta-report${NC}"
echo ""
echo "  It produces an HTML report with:"
echo "    - Story points (effort estimate)"
echo "    - File-by-file issues with line numbers"
echo "    - Links to migration documentation"
echo "    - Technology usage breakdown"

pause

# =============================================================================
header "CLEANUP"
# =============================================================================

echo "  To stop both servers:"
echo ""
echo "    kill \$(cat /tmp/eap64.pid)   # Stop EAP 6.4"
echo "    kill \$(cat /tmp/eap74.pid)   # Stop EAP 7.4"
echo ""
echo "  Or run: ./scripts/99-stop-all.sh"
echo ""
echo -e "${BOLD}${GREEN}  Demo complete!${NC}"
echo ""
