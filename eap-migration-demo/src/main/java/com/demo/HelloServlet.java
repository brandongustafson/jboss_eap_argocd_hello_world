package com.demo;

import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.PrintWriter;

/**
 * Simple servlet - works on both EAP 6.4 and 7.4.
 *
 * MIGRATION NOTE:
 * EAP 6.4 used JBoss Web (based on Tomcat) as the web container.
 * EAP 7.4 uses Undertow. Servlet annotations like @WebServlet work
 * the same way, but JBoss Web-specific config in jboss-web.xml
 * may need updating (see src/main/webapp/WEB-INF/jboss-web.xml).
 */
@WebServlet("/hello")
public class HelloServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        String name = req.getParameter("name");
        if (name == null || name.isEmpty()) {
            name = "World";
        }

        resp.setContentType("text/html;charset=UTF-8");
        PrintWriter out = resp.getWriter();
        out.println("<html><body>");
        out.println("<h1>Hello, " + escapeHtml(name) + "!</h1>");
        out.println("<p>Running on: " + req.getServletContext().getServerInfo() + "</p>");
        out.println("<p><a href='../api/greet?name=" + escapeHtml(name) + "'>Try the REST endpoint</a></p>");
        out.println("</body></html>");
    }

    private String escapeHtml(String input) {
        return input.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
    }
}
