###[INST-101] Especificación: Aegis Core Containerization (Docker)

#### 1. Visión General (Abstract)
Para asegurar una Developer Experience (DevEx) impecable y despliegues predecibles en producción, Aegis OS será empaquetado en contenedores Docker OCI-compliant. Utilizaremos `docker-compose` para orquestar la red interna entre la Shell y el Kernel, asegurando aislamiento (solo la Shell expone puertos al exterior) y persistencia segura de datos.

#### 2. Topología de Contenedores
1. **Contenedor `ank-server` (Rust):**
   - **Base Image:** `nvidia/cuda:12.2.2-devel-ubuntu22.04` (Para compilación) -> `nvidia/cuda:12.2.2-runtime-ubuntu22.04` (Para ejecución). *Nota: Requerimos soporte CUDA nativo para llama.cpp y whisper.cpp.*
   - **Volúmenes:** `/app/users` (Para las DBs SQLCipher y workspaces), `/app/models` (Para cachear los `.gguf` y no descargarlos cada vez).
   - **Red:** Expone `50051` solo a la red interna de Docker (`aegis_net`).

2. **Contenedor `aegis-shell` (Python + React):**
   - **Multi-stage Build:** 
     - Stage 1 (Node): Compila `ui/` con Vite.
     - Stage 2 (Python): Instala dependencias del BFF, copia el `dist/` de Vite al directorio estático de FastAPI.
   - **Base Image (Runtime):** `python:3.11-slim`.
   - **Red:** Expone el puerto `8000` al Host. Se comunica con el Kernel usando el hostname interno de Docker (`target="ank-server:50051"`).

#### 3. Orquestación (docker-compose.yml)
- Definir un `docker-compose.yml` en la raíz de `Aegis-Installer`.
- Configurar el passthrough de GPU (`deploy.resources.reservations.devices`).
- Crear un archivo `.env.example` con las variables críticas (`AEGIS_ROOT_KEY`, `AEGIS_WHISPER_MODEL`).

#### 4. Criterios de Aceptación (DoD)
1. `Dockerfile` optimizado y multi-stage en `Aegis-ANK`.
2. `Dockerfile` optimizado y multi-stage en `Aegis-Shell`.
3. `docker-compose.yml` funcional en `Aegis-Installer`.
4. El contenedor del Kernel no arranca como `root` (Seguridad SRE: crear un usuario `aegis` dentro del Dockerfile para la ejecución).