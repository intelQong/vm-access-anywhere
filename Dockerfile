FROM tomcat:9-jre11-slim

# Install curl
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Download official Apache Guacamole Client WAR
RUN curl -fsSL -o /usr/local/tomcat/webapps/guacamole.war \
    https://archive.apache.org/dist/guacamole/1.5.5/binary/guacamole-1.5.5.war

# Create Guacamole configuration directory
RUN mkdir -p /root/.guacamole

EXPOSE 8080
