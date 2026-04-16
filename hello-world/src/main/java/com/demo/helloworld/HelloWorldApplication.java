package com.demo.helloworld;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.servlet.support.SpringBootServletInitializer;

/**
 * Main application class — serves two purposes:
 *
 * 1. Standalone execution (Docker / local dev):
 *    SpringApplication.run() starts the embedded Tomcat server.
 *    Run with: java -jar hello-world.war
 *
 * 2. WAR deployment to JBoss EAP 7.4:
 *    SpringBootServletInitializer is the bridge between the Servlet 3.0
 *    container (JBoss Undertow) and Spring Boot. When JBoss deploys the WAR,
 *    it finds this class via the ServiceLoader mechanism and calls configure()
 *    to bootstrap the Spring application context — no web.xml needed.
 *
 * This dual-mode approach means the SAME WAR artifact works in both
 * JBoss EAP and as a standalone Docker container.
 */
@SpringBootApplication
public class HelloWorldApplication extends SpringBootServletInitializer {

    /**
     * Entry point for standalone execution (java -jar).
     */
    public static void main(String[] args) {
        SpringApplication.run(HelloWorldApplication.class, args);
    }

    /**
     * Entry point for WAR deployment to an external servlet container.
     * JBoss EAP calls this method to initialize the Spring context.
     */
    @Override
    protected SpringApplicationBuilder configure(SpringApplicationBuilder builder) {
        return builder.sources(HelloWorldApplication.class);
    }
}
