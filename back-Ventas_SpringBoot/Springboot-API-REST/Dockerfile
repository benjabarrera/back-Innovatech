# ===== Etapa 1: build (compila el JAR con Maven) =====
FROM maven:3.9.9-eclipse-temurin-17 AS build
WORKDIR /app

# Copiamos primero el pom para cachear las dependencias en una capa aparte:
# si el codigo cambia pero el pom no, Docker reutiliza esta capa y no vuelve a descargar.
COPY pom.xml .
RUN mvn -B dependency:go-offline

# Ahora el codigo fuente y empaquetamos (sin tests para acelerar el build)
COPY src ./src
RUN mvn -B clean package -DskipTests

# ===== Etapa 2: runtime (imagen liviana, solo JRE) =====
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Usuario sin privilegios (no-root) por seguridad
RUN addgroup -S spring && adduser -S spring -G spring

# Copiamos solo el JAR ya construido desde la etapa de build
COPY --from=build /app/target/*.jar app.jar

USER spring
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
