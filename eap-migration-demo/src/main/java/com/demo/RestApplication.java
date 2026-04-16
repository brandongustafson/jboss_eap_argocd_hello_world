package com.demo;

import javax.ws.rs.ApplicationPath;
import javax.ws.rs.core.Application;

/**
 * JAX-RS Application activator.
 *
 * MIGRATION NOTE (important for demo):
 * In EAP 6.4, JAX-RS could be activated without this class by relying on
 * the resteasy-deployer or a <servlet-mapping> in web.xml pointing to
 * the RESTEasy servlet directly.
 *
 * In EAP 7.4, the recommended approach is to extend javax.ws.rs.core.Application
 * and annotate it with @ApplicationPath. This is the Java EE 7 standard way.
 *
 * If you're migrating from EAP 6.4 and had RESTEasy configured manually in
 * web.xml, you should replace that with this class.
 */
@ApplicationPath("/api")
public class RestApplication extends Application {
    // No body needed - EAP will scan and register all @Path classes automatically
}
