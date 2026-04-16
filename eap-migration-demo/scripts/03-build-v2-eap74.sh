#!/usr/bin/env bash
# =============================================================================
# 03-build-v2-eap74.sh — Apply migration changes and build the EAP 7.4 app
#
# This is the HEART of the demo. This script applies each migration change
# one at a time, explaining what changed and why before writing each file.
#
# Changes applied:
#   1. web.xml        — Remove manual RESTEasy servlet, upgrade to Servlet 3.1
#   2. beans.xml      — Upgrade to CDI 1.2 schema with bean-discovery-mode="all"
#   3. jboss-web.xml  — Clean up (same content, updated namespace comment)
#   4. LegacyRestConfig.java — DELETE (replaced by @ApplicationPath)
#   5. RestApplication.java  — CREATE (standard Java EE 7 JAX-RS activation)
#   6. GreetingResource.java — Update version string, show JAX-RS 2.0 option
#   7. GreetingService.java  — Update version string
#   8. Build the migrated WAR
# =============================================================================

set -e
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }
step()    { echo -e "\n${BOLD}${YELLOW}━━━ $1 ━━━${NC}\n"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "============================================================"
echo "  Step 3: Applying EAP 6.4 → 7.4 Migration Changes"
echo "============================================================"

# =============================================================================
# CHANGE 1: web.xml
# =============================================================================
step "CHANGE 1 of 5: web.xml — Remove manual RESTEasy, upgrade to Servlet 3.1"

cat << 'EXPLANATION'
  BEFORE (EAP 6.4):
    - Servlet version 3.0 (Java EE 6)
    - RESTEasy HttpServletDispatcher registered manually as a <servlet>
    - Required a LegacyRestConfig class to list all resource classes

  AFTER (EAP 7.4):
    - Servlet version 3.1 (Java EE 7) — unlocks non-blocking I/O
    - RESTEasy servlet block REMOVED entirely
    - JAX-RS is now activated by RestApplication.java with @ApplicationPath
    - Cleaner, shorter, standard Java EE 7 approach

EXPLANATION

info "Writing migrated web.xml..."
cat > "$PROJECT_DIR/src/main/webapp/WEB-INF/web.xml" << 'WEBXML'
<?xml version="1.0" encoding="UTF-8"?>
<!--
  EAP 7.4 STYLE — web.xml (MIGRATED)
  =====================================
  WHAT CHANGED FROM EAP 6.4:
    1. Schema updated from java.sun.com (Servlet 3.0) to xmlns.jcp.org (Servlet 3.1)
    2. version="3.0" → version="3.1"
    3. The entire RESTEasy <servlet> and <servlet-mapping> block was REMOVED.
       JAX-RS is now activated by RestApplication.java using @ApplicationPath.

  WHY THIS MATTERS:
    Servlet 3.1 adds non-blocking I/O via ReadListener and WriteListener.
    This is useful for streaming large responses or handling slow clients
    without tying up a thread.

    The manual RESTEasy servlet config was always a workaround. The standard
    Java EE 7 way is @ApplicationPath, which is cleaner and portable across
    any Java EE 7 server (not just JBoss).
-->
<web-app xmlns="http://xmlns.jcp.org/xml/ns/javaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee http://xmlns.jcp.org/xml/ns/javaee/web-app_3_1.xsd"
         version="3.1">

    <display-name>EAP Migration Demo - v2 (EAP 7.4 migrated)</display-name>

    <!-- No RESTEasy servlet needed here anymore. See RestApplication.java. -->

</web-app>
WEBXML
success "web.xml migrated"

# =============================================================================
# CHANGE 2: beans.xml
# =============================================================================
step "CHANGE 2 of 5: beans.xml — Upgrade to CDI 1.2 schema"

cat << 'EXPLANATION'
  BEFORE (EAP 6.4 / CDI 1.0):
    - Schema: java.sun.com/xml/ns/javaee (CDI 1.0)
    - No bean-discovery-mode attribute (all classes scanned by default)
    - File must exist to enable CDI at all

  AFTER (EAP 7.4 / CDI 1.2):
    - Schema: xmlns.jcp.org/xml/ns/javaee (CDI 1.1+)
    - bean-discovery-mode="all" explicitly set to preserve EAP 6.4 behavior
    - File is now optional, but keeping it is the safe migration path

  WHY bean-discovery-mode="all" matters:
    CDI 1.2 changed the default to "annotated" — only classes with explicit
    CDI scope annotations are discovered. If your EAP 6.4 app had plain
    classes being injected without scope annotations, they would silently
    stop working on EAP 7.4 without this setting.

EXPLANATION

info "Writing migrated beans.xml..."
cat > "$PROJECT_DIR/src/main/webapp/WEB-INF/beans.xml" << 'BEANSXML'
<?xml version="1.0" encoding="UTF-8"?>
<!--
  EAP 7.4 STYLE — beans.xml (MIGRATED)
  =======================================
  WHAT CHANGED FROM EAP 6.4:
    1. Schema namespace: java.sun.com → xmlns.jcp.org
    2. Schema version: beans_1_0.xsd → beans_1_1.xsd
    3. Added: bean-discovery-mode="all"

  WHY bean-discovery-mode="all":
    CDI 1.2 (EAP 7.4) changed the default discovery mode to "annotated".
    Setting it to "all" matches the CDI 1.0 behavior from EAP 6.4, ensuring
    all classes in the archive are scanned as potential CDI beans.

    This is the safest migration path. Once you've verified everything works,
    you can switch to "annotated" and add explicit scope annotations to any
    beans that were relying on implicit discovery.
-->
<beans xmlns="http://xmlns.jcp.org/xml/ns/javaee"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee http://xmlns.jcp.org/xml/ns/javaee/beans_1_1.xsd"
       bean-discovery-mode="all">
</beans>
BEANSXML
success "beans.xml migrated"

# =============================================================================
# CHANGE 3: Delete LegacyRestConfig.java
# =============================================================================
step "CHANGE 3 of 5: Delete LegacyRestConfig.java"

cat << 'EXPLANATION'
  BEFORE (EAP 6.4):
    LegacyRestConfig.java extended Application and manually listed every
    JAX-RS resource class in getClasses(). This was required when wiring
    RESTEasy via web.xml.

  AFTER (EAP 7.4):
    This class is deleted entirely. RestApplication.java (next step) uses
    @ApplicationPath and an empty body — EAP 7.4 scans and registers all
    @Path classes automatically.

EXPLANATION

rm -f "$PROJECT_DIR/src/main/java/com/demo/LegacyRestConfig.java"
success "LegacyRestConfig.java deleted"

# =============================================================================
# CHANGE 4: Create RestApplication.java
# =============================================================================
step "CHANGE 4 of 5: Create RestApplication.java (@ApplicationPath)"

cat << 'EXPLANATION'
  This is the standard Java EE 7 way to activate JAX-RS.
  One annotation, no web.xml config, no class registration.
  EAP 7.4 (RESTEasy 3.x) scans the classpath and registers
  all classes annotated with @Path automatically.

EXPLANATION

info "Writing RestApplication.java..."
cat > "$PROJECT_DIR/src/main/java/com/demo/RestApplication.java" << 'JAVA'
package com.demo;

import javax.ws.rs.ApplicationPath;
import javax.ws.rs.core.Application;

/**
 * EAP 7.4 STYLE — JAX-RS Application activator (MIGRATED)
 * ==========================================================
 * WHAT CHANGED FROM EAP 6.4:
 *   - LegacyRestConfig.java (which manually listed resource classes) is GONE
 *   - This class replaces the <servlet> block in web.xml
 *   - @ApplicationPath("/api") sets the base URL for all REST endpoints
 *   - Empty body = EAP 7.4 auto-discovers all @Path classes via classpath scan
 *
 * BEFORE you needed in web.xml:
 *   <servlet>
 *     <servlet-class>org.jboss.resteasy.plugins.server.servlet.HttpServletDispatcher</servlet-class>
 *     <init-param>
 *       <param-name>javax.ws.rs.Application</param-name>
 *       <param-value>com.demo.LegacyRestConfig</param-value>
 *     </init-param>
 *   </servlet>
 *
 * NOW you just need this class. That's it.
 */
@ApplicationPath("/api")
public class RestApplication extends Application {
    // Empty — EAP 7.4 scans and registers all @Path classes automatically
}
JAVA
success "RestApplication.java created"

# =============================================================================
# CHANGE 5: Update GreetingService and GreetingResource
# =============================================================================
step "CHANGE 5 of 5: Update service classes (version strings + JAX-RS 2.0 note)"

info "Writing updated GreetingService.java..."
cat > "$PROJECT_DIR/src/main/java/com/demo/GreetingService.java" << 'JAVA'
package com.demo;

import javax.enterprise.context.ApplicationScoped;

/**
 * CDI bean — no migration changes required for this class.
 *
 * CDI 1.0 (EAP 6.4) vs CDI 1.2 (EAP 7.4):
 *   - @ApplicationScoped works identically in both versions
 *   - The main difference is in beans.xml (already handled)
 *   - CDI 1.2 also adds @Vetoed, improved interceptor ordering,
 *     and better integration with other Java EE 7 specs
 */
@ApplicationScoped
public class GreetingService {

    public String buildGreeting(String name) {
        return "Hello, " + name + "! Successfully migrated to EAP 7.4.";
    }
}
JAVA
success "GreetingService.java updated"

info "Writing updated GreetingResource.java..."
cat > "$PROJECT_DIR/src/main/java/com/demo/GreetingResource.java" << 'JAVA'
package com.demo;

import javax.inject.Inject;
import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.QueryParam;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;

/**
 * EAP 7.4 STYLE — JAX-RS Resource (JAX-RS 2.0)
 * ===============================================
 * No breaking changes from EAP 6.4 for this class.
 * All JAX-RS 1.1 annotations are fully compatible with JAX-RS 2.0.
 *
 * NEW capabilities available now that you're on JAX-RS 2.0 / EAP 7.4:
 *
 * 1. Client API (no more Apache HttpClient boilerplate):
 *    Client client = ClientBuilder.newClient();
 *    String result = client.target("http://other-service/api")
 *                          .request(MediaType.APPLICATION_JSON)
 *                          .get(String.class);
 *
 * 2. @BeanParam — group query/path/header params into one object:
 *    public Response greet(@BeanParam GreetingParams params) { ... }
 *
 * 3. ContainerRequestFilter — standard auth/logging (replaces RESTEasy interceptors):
 *    @Provider
 *    public class AuthFilter implements ContainerRequestFilter { ... }
 *
 * 4. Async endpoints with @Suspended AsyncResponse:
 *    public void greetAsync(@Suspended AsyncResponse ar) {
 *        CompletableFuture.supplyAsync(() -> buildResponse())
 *                         .thenAccept(ar::resume);
 *    }
 */
@Path("/greet")
public class GreetingResource {

    @Inject
    private GreetingService greetingService;

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public Response greet(@QueryParam("name") String name) {
        if (name == null || name.isEmpty()) {
            name = "World";
        }
        String message = greetingService.buildGreeting(name);
        String json = "{\"message\": \"" + message + "\", \"version\": \"EAP 7.4 migrated\"}";
        return Response.ok(json).build();
    }
}
JAVA
success "GreetingResource.java updated"

# =============================================================================
# Build
# =============================================================================
echo ""
echo "============================================================"
echo "  Building the migrated EAP 7.4 WAR"
echo "============================================================"
echo ""

cd "$PROJECT_DIR"
mvn clean package -q

cp target/eap-migration-demo.war target/eap-migration-demo-v2-eap74.war
success "Built: target/eap-migration-demo-v2-eap74.war"

echo ""
echo "============================================================"
echo -e "  \033[0;32mMigration changes applied and WAR built!\033[0m"
echo "============================================================"
echo ""
echo "  Summary of changes:"
echo "    ✓ web.xml        — Servlet 3.0 → 3.1, removed RESTEasy servlet block"
echo "    ✓ beans.xml      — CDI 1.0 → 1.2 schema, added bean-discovery-mode=all"
echo "    ✓ LegacyRestConfig.java — DELETED"
echo "    ✓ RestApplication.java  — CREATED with @ApplicationPath"
echo "    ✓ GreetingResource.java — Updated (JAX-RS 2.0 notes added)"
echo "    ✓ GreetingService.java  — Updated"
echo ""
echo "  Next: Run ./scripts/04-deploy-eap74.sh"
echo ""
