# Changelog

## [1.0.0] - 2026-03-06
### Added
- **[INST-101] Aegis Core Containerization**:
    - **Docker Compose**: Se introdujo configuración oficial para orquestar `ank-server` y `aegis-shell` bajo una misma red privada, exponiendo únicamente el puerto `8000` de the Shell hacia el exterior, siguiendo el concepto Zero-Trust.
    - **Aceleración C++ / CUDA**: La imagen del `ank-server` utiliza `nvidia/cuda:12.2.2` delegando compilación por layers y preparando el terreno nativo para llama.cpp y whisper.cpp.
    - **Privilegios Restringidos**: Contenedor del Kernel forzado en SRE isolation a través de la creación y switch a un usuario sin privilegios `aegis` (`useradd aegis`).
    - **Volúmenes y Env**: Configurado el almacenamiento persistente nativo para `/app/users` (bases de datos de enclave) y `/app/models`. Agregado baseline `.env.example`.
