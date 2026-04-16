# Java Demo Projects

Two demo projects for customer presentations covering JBoss EAP deployment,
Docker containerization, OpenShift, and ArgoCD GitOps.

---

## Projects

### [`hello-world/`](./hello-world)
A Spring Boot Hello World app that walks through the full modern Java deployment pipeline:
- Build a WAR with Maven
- Deploy to JBoss EAP 7.4
- Containerize with Docker
- Deploy to OpenShift
- GitOps delivery with ArgoCD

**Start here:** `hello-world/README.md`

### [`eap-migration-demo/`](./eap-migration-demo)
A demo showing how to migrate a Java EE app from JBoss EAP 6.4 to 7.4.
Covers web.xml, CDI, JAX-RS, and the JBoss Web → Undertow transition.

**Start here:** `eap-migration-demo/README.md`

---

## Quick Start

```bash
# Clone
git clone <this-repo-url>
cd <repo-name>

# Hello World demo
cd hello-world
./scripts/demo.sh

# EAP migration demo
cd eap-migration-demo
./scripts/00-setup.sh
```

See each project's README for prerequisites and download links.
