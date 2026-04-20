# =============================================================================
# Multi-stage Dockerfile
# =============================================================================
# Stage 1 (build): compiles the app with Maven
# Stage 2 (runtime): runs the WAR with a minimal JRE
#
# Multi-stage keeps the final image small — the Maven cache and source code
# are discarded. Only the compiled WAR ends up in the runtime image.
#
# Platform note:
#   Built on ARM (Apple Silicon). The base images below are multi-arch,
#   so `docker build` will pull the correct variant automatically.
#   When pushing to a registry for OpenShift (x86_64), use:
#     docker buildx build --platform linux/amd64 -t <image> --push .
# =============================================================================

# ── Stage 1: Build ────────────────────────────────────────────────────────────
# Use the official Maven image which includes both JDK 11 and Maven.
FROM maven:3.9-eclipse-temurin-11 AS build

WORKDIR /workspace

# Copy dependency descriptors first — Docker caches this layer separately.
# If only source code changes (not pom.xml), Maven dependencies are not re-downloaded.
COPY pom.xml .
RUN mvn dependency:go-offline -B -q 2>/dev/null || true

# Copy source and build
COPY src ./src
RUN mvn clean package -DskipTests -B -q

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM eclipse-temurin:11-jre

# Non-root user — required by OpenShift (runs containers as arbitrary UIDs by default)
# and a security best practice in general.
RUN groupadd -r appgroup && useradd -r -g appgroup appuser

WORKDIR /app

# Copy only the WAR from the build stage
COPY --from=build /workspace/target/hello-world.war app.war

# Give ownership to the non-root user
RUN chown -R appuser:appgroup /app
USER appuser

# Document the port (doesn't actually publish it — that's done at runtime)
EXPOSE 8080

# Health check — Docker Desktop and Kubernetes use this to know when the app is ready
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Run the WAR as a standalone Spring Boot app (embedded Tomcat).
# The WAR is executable because spring-boot-maven-plugin repackages it.
ENTRYPOINT ["java", "-jar", "app.war"]
