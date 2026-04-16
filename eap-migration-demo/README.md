# JBoss EAP 6.4 → 7.4 Migration Demo

A complete, runnable demo showing how to migrate a Java EE application from
JBoss EAP 6.4 to JBoss EAP 7.4. Designed for live customer presentations.

---

## What This Demo Shows

The app starts as an EAP 6.4-style project with intentional "old" patterns,
then the migration scripts apply each change one at a time with explanations.
Both servers run simultaneously so you can compare them side by side.

**Migration changes covered:**
- `web.xml` — Servlet 3.0 → 3.1, remove manual RESTEasy servlet config
- `beans.xml` — CDI 1.0 → 1.2 schema, add `bean-discovery-mode="all"`
- `LegacyRestConfig.java` — deleted (manual resource registration)
- `RestApplication.java` — created (`@ApplicationPath` standard approach)
- JAX-RS 1.1 → 2.0 new capabilities explained
- JBoss Web (Tomcat) → Undertow explained

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Java | 8 or 11 | `brew install openjdk@11` |
| Maven | 3.x | `brew install maven` |
| Red Hat account | free | https://access.redhat.com |

---

## Step 0: Download the EAP ZIPs (manual — requires Red Hat login)

This is the only step that can't be automated. Both files are free to download
with a Red Hat developer account.

1. Go to: https://access.redhat.com/jbossnetwork/restricted/listSoftware.html
2. Product: **JBoss Enterprise Application Platform**
3. Download both:
   - Version **6.4** → `jboss-eap-6.4.0.zip`
   - Version **7.4** → `jboss-eap-7.4.0.zip`
4. Save both to `~/Downloads/`

---

## Demo Flow (run these in order)

```
scripts/
  00-setup.sh           ← Extract both EAPs, add admin users
  01-build-v1-eap64.sh  ← Write EAP 6.4-style source, build WAR
  02-deploy-eap64.sh    ← Start EAP 6.4, deploy, verify
  03-build-v2-eap74.sh  ← Apply migration changes, build WAR
  04-deploy-eap74.sh    ← Start EAP 7.4 (port +100), deploy, verify
  05-show-diff.sh       ← PRESENTATION: walk through every change live
  99-stop-all.sh        ← Stop both servers
```

---

## Running the Demo

### 1. Setup (one time)

```bash
cd eap-migration-demo
./scripts/00-setup.sh
```

This extracts both ZIPs to `~/jboss-demo/` and creates an `admin` user
on each server (password: `Admin1234!`).

### 2. Build and deploy the EAP 6.4 app

```bash
./scripts/01-build-v1-eap64.sh
./scripts/02-deploy-eap64.sh
```

Open http://localhost:8080/demo/ — this is the "before" state.

### 3. Apply migration and deploy to EAP 7.4

```bash
./scripts/03-build-v2-eap74.sh
./scripts/04-deploy-eap74.sh
```

Open http://localhost:8180/demo/ — this is the "after" state.
Both servers are now running simultaneously.

### 4. Walk through the changes (presentation mode)

```bash
./scripts/05-show-diff.sh
```

This is your live presenter script. It walks through each change with
color-coded diffs, explanations, and live curl calls to both servers.

### 5. Cleanup

```bash
./scripts/99-stop-all.sh
```

---

## URLs at a Glance

| | EAP 6.4 | EAP 7.4 |
|---|---------|---------|
| App home | http://localhost:8080/demo/ | http://localhost:8180/demo/ |
| Servlet | http://localhost:8080/demo/hello?name=You | http://localhost:8180/demo/hello?name=You |
| REST | http://localhost:8080/demo/api/greet?name=You | http://localhost:8180/demo/api/greet?name=You |
| Admin console | http://localhost:9990 | http://localhost:10090 |
| Admin credentials | admin / Admin1234! | admin / Admin1234! |

---

## The Migration Changes Explained

### web.xml

The most visible change. EAP 6.4 apps often wired up RESTEasy manually:

```xml
<!-- EAP 6.4 — BEFORE -->
<servlet>
  <servlet-class>org.jboss.resteasy.plugins.server.servlet.HttpServletDispatcher</servlet-class>
  <init-param>
    <param-name>javax.ws.rs.Application</param-name>
    <param-value>com.demo.LegacyRestConfig</param-value>
  </init-param>
</servlet>
```

On EAP 7.4 this entire block is removed. A single class handles it:

```java
// EAP 7.4 — AFTER
@ApplicationPath("/api")
public class RestApplication extends Application { }
```

The Servlet version also moves from 3.0 to 3.1, which adds non-blocking I/O
via `ReadListener` and `WriteListener`.

### beans.xml

CDI 1.0 (EAP 6.4) required this file to exist to enable CDI at all.
CDI 1.2 (EAP 7.4) changed the default `bean-discovery-mode` to `annotated`,
meaning only classes with explicit CDI scope annotations are discovered.

Setting `bean-discovery-mode="all"` preserves the EAP 6.4 behavior and is
the safest migration path. Tighten it later once you've audited your beans.

```xml
<!-- EAP 6.4 — CDI 1.0 schema, no bean-discovery-mode -->
<beans xmlns="http://java.sun.com/xml/ns/javaee" ...>

<!-- EAP 7.4 — CDI 1.2 schema, explicit discovery mode -->
<beans xmlns="http://xmlns.jcp.org/xml/ns/javaee" ...
       bean-discovery-mode="all">
```

### LegacyRestConfig.java → RestApplication.java

`LegacyRestConfig` extended `Application` and manually listed every JAX-RS
resource class. Forget to register a new class? It silently doesn't work.

`RestApplication` uses `@ApplicationPath` and an empty body. EAP 7.4 scans
and registers all `@Path` classes automatically. No maintenance required.

### JBoss Web → Undertow

EAP 6.4 used JBoss Web (a Tomcat fork) as its web container.
EAP 7.4 replaced it with Undertow, which is non-blocking by design.

**Impact on migration:**
- Tomcat `Valve` classes in `jboss-web.xml` will cause deployment failures
  on EAP 7.4. Replace them with Undertow handlers in `standalone.xml`.
- Startup time is noticeably faster with Undertow.
- HTTP/2 and WebSocket support are built in.

---

## For Real-World Migrations: Red Hat MTA

The Migration Toolkit for Applications (MTA) scans your WAR/EAR and generates
a detailed HTML report of every migration issue with effort estimates.

Download: https://developers.redhat.com/products/mta/overview

```bash
./mta-cli --input my-app.war \
          --source eap6 \
          --target eap7 \
          --output ./mta-report
```

The report includes story points (effort estimate), file-by-file issues with
line numbers, and links to the relevant migration documentation.
