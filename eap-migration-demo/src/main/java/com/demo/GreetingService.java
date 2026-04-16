package com.demo;

import javax.enterprise.context.ApplicationScoped;

/**
 * CDI bean - demonstrates that CDI works the same on both EAP 6.4 and 7.4.
 *
 * MIGRATION NOTE:
 * CDI 1.0 (EAP 6.4) vs CDI 1.2 (EAP 7.4).
 * The main practical difference: CDI 1.2 enables CDI by default in all
 * bean archives. In EAP 6.4, you needed a beans.xml file to activate CDI
 * even if it was empty. In EAP 7.4 with bean-discovery-mode="annotated"
 * (the new default), beans with scope annotations are discovered automatically.
 *
 * See src/main/webapp/WEB-INF/beans.xml for the explicit config used here
 * to ensure compatibility with both versions.
 */
@ApplicationScoped
public class GreetingService {

    public String buildGreeting(String name) {
        return "Hello, " + name + "! Migrated successfully to EAP 7.4.";
    }
}
