# Innovatech Chile — Backend

Backend de la plataforma Innovatech Chile, compuesto por dos microservicios desarrollados en **Spring Boot**: **Ventas** y **Despachos**. Junto con el frontend y una base de datos relacional MySQL, forma parte de una plataforma con un ciclo de integración y entrega continua (CI/CD) totalmente automatizado, desplegada en producción sobre **Amazon ECS (Fargate)**.

Repositorio del frontend: [front-Innovatech](https://github.com/benjabarrera/front-Innovatech.git)

---

## Arquitectura

Los microservicios se conectan a la base de datos MySQL mediante el alias interno `mysql:3306`, y son alcanzados por el frontend a través de rutas de reverse-proxy (`/api/v1/ventas`, `/api/v1/despachos`). Ninguno de los dos microservicios está expuesto directamente a Internet.
Frontend (Nginx) ──/api/v1/ventas──▶ Servicio Ventas     (:8080)
──/api/v1/despachos──▶ Servicio Despachos (:8081)
Servicio Ventas ────┐
├──▶ MySQL 8 (mysql:3306)
Servicio Despachos ──┘

El descubrimiento de servicios se resuelve mediante **ECS Service Connect** en producción (alias DNS `ventas`, `despachos`, `mysql`) y mediante la red interna de **Docker Compose** en el entorno de desarrollo local, sin diferencias de código entre ambos entornos.

---

## Stack tecnológico

| Componente          | Tecnología                              |
|----------------------|------------------------------------------|
| Framework            | Spring Boot                             |
| Base de datos        | MySQL 8                                 |
| Contenerización      | Docker (build multietapa)               |
| Imagen base          | Eclipse Temurin JRE (Alpine)            |
| CI/CD                | GitHub Actions                          |
| Registro de imágenes | Amazon ECR                              |
| Orquestación         | Amazon ECS (Fargate)                    |
| Gestión de secretos  | AWS SSM Parameter Store (SecureString)  |

---

## Estructura del proyecto
.
├── ventas/                     # Microservicio de Ventas (puerto 8080)
│   ├── src/
│   ├── Dockerfile
│   └── .dockerignore
├── despachos/                   # Microservicio de Despachos (puerto 8081)
│   ├── src/
│   ├── Dockerfile
│   └── .dockerignore
├── docker-compose.yml            # Orquestación local (mysql + ventas + despachos)
└── .github/
└── workflows/
└── deploy.yml             # Pipeline CI/CD

---

## Requisitos previos

- Java 17+ y Maven/Gradle (solo para desarrollo local sin Docker)
- Docker y Docker Compose
- Cuenta de AWS con acceso a ECR/ECS (para despliegue)

---

## Ejecución local con Docker Compose

```bash
# Clonar ambos repositorios (backend y frontend) en la misma carpeta de trabajo
git clone https://github.com/benjabarrera/back-Innovatech.git
git clone https://github.com/benjabarrera/front-Innovatech.git

# Levantar el stack completo (mysql, ventas, despachos y frontend)
docker-compose up --build
```

Endpoints disponibles en desarrollo local:

- Ventas: `http://localhost:8080/api/v1/ventas`
- Despachos: `http://localhost:8081/api/v1/despachos`

La persistencia de la base de datos se mantiene mediante el volumen nombrado `mysql_data`, definido en `docker-compose.yml`.

Para detener y limpiar los contenedores:

```bash
docker-compose down
```

---

## Variables de entorno

| Variable      | Descripción                                  |
|---------------|-----------------------------------------------|
| `DB_ENDPOINT` | Host de la base de datos (`mysql` en local)   |
| `DB_PORT`     | Puerto de la base de datos (`3306`)           |
| `DB_NAME`     | Nombre de la base de datos                    |
| `DB_USERNAME` | Usuario de conexión a la base de datos        |

Las contraseñas y credenciales sensibles **no** se definen como variables de entorno planas: en producción se almacenan en **AWS SSM Parameter Store** como parámetros `SecureString` (cifrados con KMS) y ECS los inyecta en tiempo de ejecución mediante el campo `secrets` de la Task Definition. En el pipeline, las credenciales de AWS se gestionan como GitHub Secrets.

---

## Build de las imágenes Docker

Cada microservicio se empaqueta con un `Dockerfile` multietapa: una etapa compila la aplicación (`mvn package` / `gradle build`) y otra, basada en una imagen JRE minimalista (Alpine), ejecuta el `.jar` resultante como usuario no-root.

```bash
# Ventas
docker build -t innovatech-ventas ./ventas
docker run -p 8080:8080 innovatech-ventas

# Despachos
docker build -t innovatech-despachos ./despachos
docker run -p 8081:8081 innovatech-despachos
```

---

## Pipeline de CI/CD

El workflow de GitHub Actions (`.github/workflows/deploy.yml`) se dispara automáticamente con cada `push` a la rama `deploy`, ejecutando:

1. **Build** — construye las imágenes Docker de ambos microservicios.
2. **Test** — valida el empaquetado de la aplicación.
3. **Push** — autentica contra Amazon ECR y publica las imágenes etiquetadas (`innovatech-ventas`, `innovatech-despachos`).
4. **Deploy** — fuerza una actualización de los servicios en ECS (`aws ecs update-service --force-new-deployment`), logrando un despliegue gradual sin interrupción del servicio.

La autenticación con AWS se realiza mediante `aws-actions/configure-aws-credentials`, usando credenciales temporales almacenadas como GitHub Secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`).

---

## Despliegue en producción (AWS ECS)

- **Registro de imágenes:** Amazon ECR (`innovatech-ventas`, `innovatech-despachos`)
- **Orquestación:** Amazon ECS con Fargate, dentro del clúster `innovatech-cluster`
- **Descubrimiento de servicios:** ECS Service Connect, con alias DNS internos (`ventas:8080`, `despachos:8081`, `mysql:3306`)
- **Escalabilidad:** autoescalado de tipo Target Tracking sobre el servicio `ventas` (capacidad 1 a 4 tareas, objetivo de CPU 50%)
- **Resiliencia:** autorecuperación gestionada por ECS ante la caída de una tarea (el scheduler mantiene el `desiredCount`)
- **Observabilidad:** logs enviados a Amazon CloudWatch mediante el driver `awslogs`; métricas de CPU/memoria que alimentan las alarmas de autoescalado

---

## Seguridad

- Imágenes base minimalistas (Eclipse Temurin JRE Alpine), construidas en etapas para reducir la superficie de ataque.
- Contenedores ejecutados como usuario no-root.
- Security Groups restrictivos: los microservicios solo reciben tráfico desde el frontend/ALB, nunca directamente desde Internet.
- Gestión de secretos bajo el principio de mínimo privilegio (AWS SSM Parameter Store + IAM).
- Escaneo de vulnerabilidades habilitado sobre las imágenes publicadas en Amazon ECR.

---

## Equipo

Proyecto desarrollado para la asignatura **ISY1101 — Introducción a Herramientas DevOps**, Duoc UC.

- Carlo Bettancourt
- Benjamin Barrera
- Cristian Bravo
