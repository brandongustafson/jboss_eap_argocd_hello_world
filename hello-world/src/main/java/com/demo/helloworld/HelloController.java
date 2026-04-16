package com.demo.helloworld;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * MVC controller — handles GET / and returns the hello.html template.
 *
 * @Controller (not @RestController) tells Spring to resolve the return value
 * as a Thymeleaf template name, not a raw response body.
 */
@Controller
public class HelloController {

    @GetMapping("/")
    public String hello(Model model) {
        model.addAttribute("message", "HELLO WORLD");
        model.addAttribute("server", System.getProperty("jboss.server.name", "standalone"));
        return "hello";  // resolves to src/main/resources/templates/hello.html
    }
}
