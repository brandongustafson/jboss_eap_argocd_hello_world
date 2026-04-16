package com.demo;

import javax.inject.Inject;
import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.QueryParam;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;

/**
 * Simple JAX-RS REST resource.
 *
 * MIGRATION NOTE:
 * JAX-RS moved from 1.1 (EAP 6.4 / Java EE 6) to 2.0 (EAP 7.4 / Java EE 7).
 *
 * Key JAX-RS 2.0 additions you can now use on EAP 7.4:
 *  - javax.ws.rs.client.Client (async client API)
 *  - Response.Status enum improvements
 *  - @BeanParam
 *  - Filters and Interceptors via ContainerRequestFilter / ContainerResponseFilter
 *
 * This resource works on both versions since it only uses JAX-RS 1.1 features.
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
        // Simple JSON response without a JSON library dependency
        String json = "{\"message\": \"" + message + "\"}";
        return Response.ok(json).build();
    }
}
