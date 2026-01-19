package com.noteapp.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {
    
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOrigins(
                    "http://localhost:3000",              // Development
                    "https://devops-midterm.online",      // Production (no www)
                    "http://devops-midterm.online",       // Production HTTP (no www)
                    "https://www.devops-midterm.online",  // Production (with www)
                    "http://www.devops-midterm.online"    // Production HTTP (with www)
                )
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .allowCredentials(true);
    }
}
