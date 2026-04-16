#!/usr/bin/env bash
# =============================================================================
# 01-build-v1-eap64.sh — Build the "before" app (EAP 6.4 style)
#
# This script:
#   1. Writes the EAP 6.4-style source files into src/
#   2. Builds the WAR with Maven
#   3. Saves it as target/eap-migration-demo-v1-eap64.war
#
# The EAP 6.4 app intentionally uses patterns that need migration:
#   ✗ RESTEasy servlet configured manually in web.xml (old way)
#   ✗ No RestApplication.java class
#   ✗ web.xml uses Servlet 3.0 schema
#   ✗ beans.xml uses CDI 1.0 schema (no bean-discovery-mode attribute)
#   ✗ jboss-web.xml uses old namespace
#   ✗ Proprietary RESTEasy annotations (resteasy-jaxrs) instead of standard JAX-RS
# =============================================================================

set -e
CYAN='\033[0;36m'; GREEN='\033[0;32m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "============================================================"
echo "  Step 1: Writing EAP 6.4-style source files"
echo "============================================================"
echo ""

# ── web.xml: Servlet 3.0 + manual RESTEasy servlet mapping ───────────────────
info "Writing web.xml (Servlet 3.0 + manual RESTEasy config)..."
cat > "$PROJECT_DIR/src/main/webapp/WEB-INF/web.xml" << 'WEBXML'
<?xml version="1.0" encoding="UTF-8"?>
<!--
  EAP 6.4 STYLE — web.xml
  ========================
  Two things to notice here that will need to change for EAP 7.4:

  1. Servlet version 3.0 (Java EE 6). EAP 7.4 supports 3.1.

  2. RESTEasy is wired up manually via a <servlet> entry pointing to
     org.jboss.resteasy.plugins.server.servlet.HttpServletDispatcher.
     This was the common EAP 6.4 pattern. On EAP 7.4, this is replaced
     by simply creating a class that extends javax.ws.rs.core.Application
     with @ApplicationPath — no web.xml entry needed at all.

  MIGRATION ACTION: Remove the RESTEasy servlet block below and create
  RestApplication.java instead (see v2 source).
-->
<web-app xmlns="http://java.sun.com/xml/ns/javaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://java.sun.com/xml/ns/javaee http://java.sun.com/xml/ns/javaee/web-app_3_0.xsd"
         version="3.0">

    <display-name>EAP Migration Demo - v1 (EAP 6.4 style)</display-name>

    <!--
      MIGRATION ISSUE: Manual RESTEasy servlet registration.
      This was required in EAP 6.4 when not using @ApplicationPath.
      In EAP 7.4, this causes a conflict if you also have a RestApplication class.
      Remove this block when migrating.
    -->
    <servlet>
        <servlet-name>resteasy-servlet</servlet-name>
        <servlet-class>org.jboss.resteasy.plugins.server.servlet.HttpServletDispatcher</servlet-class>
        <init-param>
            <param-name>javax.ws.rs.Application</param-name>
            <param-value>com.demo.LegacyRestConfig</param-value>
        </init-param>
    </servlet>
    <servlet-mapping>
        <servlet-name>resteasy-servlet</servlet-name>
        <url-pattern>/api/*</url-pattern>
    </servlet-mapping>

</web-app>
WEBXML
success "web.xml written"

# ── beans.xml: CDI 1.0 (no bean-discovery-mode) ───────────────────────────────
info "Writing beans.xml (CDI 1.0 style)..."
cat > "$PROJECT_DIR/src/main/webapp/WEB-INF/beans.xml" << 'BEANSXML'
<?xml version="1.0" encoding="UTF-8"?>
<!--
  EAP 6.4 STYLE — beans.xml (CDI 1.0)
  =====================================
  In EAP 6.4 / CDI 1.0, this file MUST exist to enable CDI injection.
  The CDI 1.0 schema does not have a bean-discovery-mode attribute —
  all classes in the archive are scanned as potential beans by default.

  MIGRATION NOTE:
  EAP 7.4 uses CDI 1.2. The new default bean-discovery-mode is "annotated",
  meaning only classes with CDI scope annotations are discovered.

  If you keep this old CDI 1.0 schema on EAP 7.4, it still works but you
  get a warning. The clean migration is to update to the CDI 1.1+ schema
  and explicitly set bean-discovery-mode="all" to preserve the old behavior.

  MIGRATION ACTION: Update to CDI 1.1 schema and add bean-discovery-mode="all"
-->
<beans xmlns="http://java.sun.com/xml/ns/javaee"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="http://java.sun.com/xml/ns/javaee http://java.sun.com/xml/ns/javaee/beans_1_0.xsd">
    <!-- CDI 1.0: empty beans.xml is enough to activate CDI -->
</beans>
BEANSXML
success "beans.xml written"

# ── jboss-web.xml: old namespace ──────────────────────────────────────────────
info "Writing jboss-web.xml (EAP 6.4 namespace)..."
cat > "$PROJECT_DIR/src/main/webapp/WEB-INF/jboss-web.xml" << 'JBOSSWEB'
<?xml version="1.0" encoding="UTF-8"?>
<!--
  EAP 6.4 STYLE — jboss-web.xml
  ================================
  The context-root works the same on both versions.

  MIGRATION NOTE — Things that break on EAP 7.4:
  1. <valve> elements: EAP 6.4 used JBoss Web (Tomcat-based), which supported
     Tomcat Valve classes. EAP 7.4 replaced JBoss Web with Undertow.
     Any <valve> referencing org.apache.catalina.* or org.jboss.web.* classes
     will cause a deployment failure on EAP 7.4.
     → Replace with Undertow handlers in standalone.xml

  2. <security-domain>: Security domain names may differ between versions
     if you're using PicketBox (EAP 6.4) vs Elytron (EAP 7.4 default).

  This file is intentionally simple to keep the demo focused.
-->
<jboss-web>
    <context-root>/demo</context-root>
</jboss-web>
JBOSSWEB
success "jboss-web.xml written"

# ── LegacyRestConfig.java: old-style Application subclass ─────────────────────
info "Writing LegacyRestConfig.java (EAP 6.4 manual REST config)..."
mkdir -p "$PROJECT_DIR/src/main/java/com/demo"
cat > "$PROJECT_DIR/src/main/java/com/demo/LegacyRestConfig.java" << 'JAVA'
package com.demo;

import javax.ws.rs.core.Application;
import java.util.HashSet;
import java.util.Set;

/**
 * EAP 6.4 STYLE — Manual JAX-RS Application class
 * =================================================
 * In EAP 6.4, when wiring RESTEasy via web.xml, you often needed to
 * explicitly list your resource classes here. This is verbose and
 * error-prone — if you add a new resource class and forget to register
 * it here, it simply won't be available.
 *
 * MIGRATION ACTION:
 * Delete this class entirely. Replace with RestApplication.java which
 * uses @ApplicationPath("/api") and an empty body — EAP 7.4 will
 * automatically scan and register all @Path classes.
 */
public class LegacyRestConfig extends Application {

    @Override
    public Set<Class<?>> getClasses() {
        Set<Class<?>> classes = new HashSet<>();
        // Every resource class must be manually registered here
        classes.add(GreetingResource.class);
        // Forgot to add a new resource? It won't work. This is the problem.
        return classes;
    }
}
JAVA
success "LegacyRestConfig.java written"

# ── GreetingResource.java: uses old RESTEasy-specific import ──────────────────
info "Writing GreetingResource.java (EAP 6.4 style)..."
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
 * EAP 6.4 STYLE — JAX-RS Resource (JAX-RS 1.1)
 * ===============================================
 * This resource uses only JAX-RS 1.1 features, which is fine.
 * The annotations are standard and work on both versions.
 *
 * What's different in EAP 6.4 vs 7.4 for JAX-RS:
 *
 * EAP 6.4 ships RESTEasy 2.x (JAX-RS 1.1)
 * EAP 7.4 ships RESTEasy 3.x (JAX-RS 2.0)
 *
 * JAX-RS 2.0 additions you can use AFTER migration:
 *   - javax.ws.rs.client.Client  (async HTTP client, no Apache HttpClient needed)
 *   - @BeanParam                 (group multiple @QueryParam/@PathParam into one object)
 *   - ContainerRequestFilter     (standard way to do auth/logging filters)
 *   - ContainerResponseFilter    (standard way to add CORS headers, etc.)
 *   - AsyncResponse              (non-blocking endpoints)
 *
 * MIGRATION ACTION: No changes required to this file for basic migration.
 * Optionally refactor to use JAX-RS 2.0 Client API if you have outbound HTTP calls.
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
        String json = "{\"message\": \"" + message + "\", \"version\": \"EAP 6.4 style\"}";
        return Response.ok(json).build();
    }
}
JAVA
success "GreetingResource.java written"

# ── GreetingService.java ──────────────────────────────────────────────────────
info "Writing GreetingService.java..."
cat > "$PROJECT_DIR/src/main/java/com/demo/GreetingService.java" << 'JAVA'
package com.demo;

import javax.enterprise.context.ApplicationScoped;

/**
 * CDI bean — works the same on EAP 6.4 and 7.4.
 * No migration action needed for this class.
 */
@ApplicationScoped
public class GreetingService {

    public String buildGreeting(String name) {
        return "Hello, " + name + "! (Running on EAP 6.4)";
    }
}
JAVA
success "GreetingService.java written"

# ── HelloServlet.java ─────────────────────────────────────────────────────────
info "Writing HelloServlet.java..."
cat > "$PROJECT_DIR/src/main/java/com/demo/HelloServlet.java" << 'JAVA'
package com.demo;

import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.PrintWriter;

/**
 * Simple servlet — works identically on EAP 6.4 and 7.4.
 * Servlet annotations have been standard since Servlet 3.0.
 * No migration action needed for this class.
 */
@WebServlet("/hello")
public class HelloServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        String name = req.getParameter("name");
        if (name == null || name.isEmpty()) name = "World";

        resp.setContentType("text/html;charset=UTF-8");
        PrintWriter out = resp.getWriter();
        out.println("<html><body style='font-family:sans-serif;max-width:600px;margin:40px auto'>");
        out.println("<h2>Hello, " + escapeHtml(name) + "!</h2>");
        out.println("<p><strong>Server:</strong> " + req.getServletContext().getServerInfo() + "</p>");
        out.println("<p><strong>Version:</strong> EAP 6.4 style app</p>");
        out.println("<p><a href='../api/greet?name=" + escapeHtml(name) + "'>Try the REST endpoint →</a></p>");
        out.println("</body></html>");
    }

    private String escapeHtml(String s) {
        return s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;");
    }
}
JAVA
success "HelloServlet.java written"

# ── Remove RestApplication.java if it exists from a previous run ──────────────
rm -f "$PROJECT_DIR/src/main/java/com/demo/RestApplication.java"
info "Removed RestApplication.java (not used in EAP 6.4 style)"

# ── Build ─────────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  Step 2: Building the EAP 6.4-style WAR"
echo "============================================================"
echo ""

cd "$PROJECT_DIR"
mvn clean package -q

cp target/eap-migration-demo.war target/eap-migration-demo-v1-eap64.war
success "Built: target/eap-migration-demo-v1-eap64.war"

echo ""
echo "============================================================"
echo -e "  \033[0;32mBuild complete!\033[0m"
echo "============================================================"
echo ""
echo "  Next: Run ./scripts/02-deploy-eap64.sh"
echo ""
