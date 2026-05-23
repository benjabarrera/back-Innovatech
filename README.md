# Back-Innovatech — Microservicios de Ventas y Despachos

Backend del proyecto **EP2 (Innovatech Chile)**. Está compuesto por **dos microservicios** REST hechos en Spring Boot y una base de datos **MySQL**, todo contenedorizado con Docker y desplegado automáticamente en una instancia **AWS EC2** mediante un pipeline de **GitHub Actions**.

---

## Arquitectura

```
                 ┌─────────────────────────────────────────┐
   Frontend ───► │  EC2 PRIVADA (este repo)                 │
  (otra EC2)     │                                          │
                 │   ventas      :8080   /api/v1/ventas      │
                 │   despachos   :8081   /api/v1/despachos   │
                 │        │            │                     │
                 │        └─────┬──────┘                     │
                 │              ▼                            │
                 │   mysql  :3306  (datos en volumen)        │
                 └─────────────────────────────────────────┘
```

- **ventas**: API de ventas. Expone `GET/POST/PUT/DELETE /api/v1/ventas`.
- **despachos**: API de despachos. Expone `GET/POST/PUT/DELETE /api/v1/despachos`.
- **mysql**: base de datos compartida. Sus datos persisten en un **volumen Docker** llamado `mysql_data`.

> Aunque la instancia tenga IP pública, su **Security Group solo permite tráfico desde el Frontend** en los puertos 8080/8081, por lo que la API **no queda expuesta a Internet**.

---

## Tecnologías

| Componente | Tecnología |
|---|---|
| Lenguaje | Java 17 |
| Framework | Spring Boot 3.4 (Spring Web, Spring Data JPA) |
| Build | Maven |
| Base de datos | MySQL 8.0 |
| Documentación API | Swagger / OpenAPI (springdoc) |
| Contenedores | Docker (Dockerfile multi-stage, usuario no-root) |
| Orquestación | Docker Compose |
| CI/CD | GitHub Actions + Docker Hub |

---

## Estructura del repositorio

```
back-Innovatech/
├── back-Ventas_SpringBoot/
│   └── Springboot-API-REST/          # microservicio Ventas
│       ├── Dockerfile                # imagen multi-stage (no-root)
│       └── src/ ...
├── back-Despachos_SpringBoot/
│   └── Springboot-API-REST-DESPACHO/ # microservicio Despachos
│       ├── Dockerfile
│       └── src/ ...
├── docker-compose.yml                # levanta mysql + ventas + despachos
└── .github/workflows/deploy.yml      # pipeline CI/CD
```

---

## Variables de entorno

Los microservicios leen la configuración de la base de datos desde variables de entorno (definidas en `docker-compose.yml`):

| Variable | Descripción | Valor por defecto |
|---|---|---|
| `DB_ENDPOINT` | Host de la base de datos | `mysql` (nombre del servicio) |
| `DB_PORT` | Puerto de MySQL | `3306` |
| `DB_NAME` | Nombre de la base de datos | `despachos_db` |
| `DB_USERNAME` | Usuario de la base de datos | `appuser` |
| `DB_PASSWORD` | Clave del usuario | `appsecret123` |
| `DB_ROOT_PASSWORD` | Clave de root de MySQL | `rootsecret123` |

> Para producción puedes sobreescribir estos valores creando un archivo `.env` junto al `docker-compose.yml`.

---

## Cómo ejecutar en local

**Requisito:** tener Docker Desktop instalado y corriendo.

```bash
# Levanta los 3 servicios (descarga las imágenes desde Docker Hub)
docker compose up -d

# Ver el estado
docker compose ps

# Ver logs
docker compose logs -f
```

Prueba que responden:

```bash
curl http://localhost:8080/api/v1/ventas       # -> []
curl http://localhost:8081/api/v1/despachos    # -> []
```

Documentación interactiva (Swagger):
- Ventas: http://localhost:8080/swagger-ui.html
- Despachos: http://localhost:8081/swagger-ui.html

Para apagar:

```bash
docker compose down       # conserva los datos del volumen
docker compose down -v    # borra también los datos
```

---

## Persistencia de datos

La base de datos usa un **volumen con nombre** (`mysql_data`) montado en `/var/lib/mysql`. Se eligió un *named volume* (en vez de un *bind mount*) porque:

- Lo gestiona Docker, es portable y no depende de rutas del host.
- **Los datos sobreviven** aunque se elimine y se vuelva a crear el contenedor de MySQL (probado con `docker compose down` + `up`).

Esto garantiza la **continuidad operativa**: la información de ventas y despachos no se pierde al actualizar o reiniciar los contenedores.

---

## Contenedorización

Cada microservicio tiene un `Dockerfile` **multi-stage**:

1. **Etapa build** (`maven:3.9-eclipse-temurin-17`): compila el proyecto y genera el `.jar`.
2. **Etapa runtime** (`eclipse-temurin:17-jre-alpine`): imagen liviana que solo contiene el JRE y el `.jar`, y corre con un **usuario sin privilegios (no-root)** por seguridad.

Esto reduce el tamaño de la imagen final y mejora la seguridad.

---

## CI/CD — Pipeline de despliegue automático

El archivo `.github/workflows/deploy.yml` se ejecuta al hacer **push a la rama `deploy`** y realiza:

1. **Build & Push**: construye las imágenes `benjabarrera/ep2-ventas` y `benjabarrera/ep2-despachos` y las publica en **Docker Hub**.
2. **Deploy**: se conecta por SSH **directo** a la EC2 del backend, copia el `docker-compose.yml` y ejecuta `docker compose pull && docker compose up -d`.

### Secrets requeridos (en *Settings → Secrets → Actions* de este repo)

| Secret | Descripción |
|---|---|
| `DOCKERHUB_TOKEN` | Access Token de Docker Hub |
| `BACK_HOST` | IP **pública** de la EC2 del Backend |
| `EC2_USER` | Usuario SSH (`ec2-user` o `ubuntu`) |
| `EC2_SSH_KEY` | Contenido de la llave privada `.pem` |

### Requisitos en la EC2
- Docker y el plugin de Docker Compose instalados.
- El Security Group debe permitir los puertos **8080** y **8081** únicamente desde el Security Group del Frontend, y **22** para el despliegue.

---

## Equipo

Proyecto desarrollado en dupla para la asignatura **ISY1101 — Introducción a Herramientas DevOps**.
