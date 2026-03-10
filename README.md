<div align="center">

# 🛡️ Aegis OS
**El primer Sistema Operativo Cognitivo de código abierto, determinista y Zero-Knowledge para IAs locales.**

[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![Rust: 1.80+](https://img.shields.io/badge/Rust-1.80%2B-orange.svg)](https://www.rust-lang.org/)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![SRE Certified](https://img.shields.io/badge/SRE-Zero--Panic-brightgreen.svg)]()

</div>

---

## 🌌 Visión General
Aegis OS no es un chatbot, es un **Kernel Operativo** diseñado para orquestar modelos de Lenguaje y Audio de forma determinista bajo políticas estrictas de Site Reliability Engineering (SRE). Abandona la nube, recupera tu privacidad y ejecuta IA de clase mundial localmente en tu propio hardware.

### Filosofía Core
- **Ring 0 (Kernel en Rust):** Motor concurrente de alto rendimiento bajo `tokio` implementando un *Cognitive Scheduler* que delega tareas a *Virtual ALUs*. 
- **VCM (Vectorized Cognitive Memory):** Reemplazo de contextos fugaces por memoria a largo plazo unificada.
- **Citadel Protocol:** Control de acceso gRPC Zero-Trust. Multi-tenant real nativo de la caja; nadie (ni el administrador) puede interceptar contextos foráneos.
- **Zero-Panic SRE:** Código protegido por la más alta calidad arquitectónica del ecosistema Rust. Errores se propagan y atrapan silenciosamente; el Kernel *nunca crashea*.

## 🏗️ Arquitectura
Aegis funciona bajo un diseño distribuido de múltiples repositorios, centralizados mediante Docker Compose.

```mermaid
graph TD
    UI[Aegis-Shell (React UI)] -->|WebSocket| BFF[Backend For Frontend (FastAPI)]
    BFF -->|gRPC Citadel Protocol| ANK((Aegis Neural Kernel))
    
    ANK -->|Scheduler| LLM[Llama-cpp Local]
    ANK -->|Siren Protocol| ASR[Whisper Local]
    ANK -->|Plugins| WASM[Aegis SDK Wasm Modules]
    
    classDef cyber fill:#0d1117,stroke:#58a6ff,stroke-width:2px,color:#c9d1d9;
    class UI,BFF cyber
    classDef kernel fill:#1a0f2e,stroke:#bf4b8a,stroke-width:2px,color:#ffffff;
    class ANK kernel
    classDef local fill:#0f1a1a,stroke:#3fb950,stroke-width:2px,color:#e6fffa;
    class LLM,ASR,WASM local
```

## 🚀 Quickstart: One-Line Deploy (SRE Grade)

El despliegue de Aegis OS es ahora totalmente automatizado. Puedes instalar dependencias, clonar el ecosistema completo y configurar el orquestador con un solo comando:

```bash
curl -sSL https://raw.githubusercontent.com/Gustavo324234/Aegis-Installer/main/install_aegis.sh | sudo bash
```

### 🛡️ Configuración de Seguridad (Guardia .env)

Por diseño de seguridad (**Protocolo Citadel**), el orquestador se detendrá si no detecta tus credenciales maestras. Sigue estos pasos para completar el despliegue:

1. **Obtén tu .env:** Tras el primer intento fallido de despliegue (o tras clonar), navega al directorio del instalador:
   ```bash
   cd /opt/aegis/Aegis-Installer
   cp .env.example .env
   ```
2. **Configura tus llaves:** Edita el archivo `.env` y define una `AEGIS_ROOT_KEY` robusta. Esta llave es el ancla criptográfica de todo el sistema.
3. **Relanza el despliegue:** Vuelve a ejecutar el comando inicial o usa el script local:
   ```bash
   sudo ./install_aegis.sh
   ```

### ✅ Validación del Nexo

Una vez que el script confirme el despliegue, verifica la salud del sistema:

```bash
# Verificar túnel BFF online
curl -s http://localhost:8000/health

# Verificar estado operacional del Kernel (ANK)
curl -s http://localhost:8000/api/system/state
```

---

## 🛠️ Administración del Enclave
Accede directamente a la terminal administrativa para gestionar usuarios (tenants) vía Ring 0:

```bash
docker exec -it aegis-ank aegis admin create-tenant MiUsuario
```

Guarda el Payload seguro que te imprimirá la consola (Contiene el `Tenant ID`, el `Puerto asignado` y el `Temporal Passphrase`).

Dirígete a tu navegador para entrar a la Shell:
👉 [http://localhost:8000](http://localhost:8000)

Ingresa usando el **Tenant ID** y tu **Passphrase**. El Ecosistema despertará.

---

## 🤝 Súmate a la Rebelión Cognitiva
Si eres ingeniero en sistemas, DevOps o devoto de C++/Rust y crees en la IA libre, el Kernel necesita tu talento. Por favor, lee estrictamente nuestras [Normas de Contribución SRE (CONTRIBUTING.md)](CONTRIBUTING.md) antes de proponer cambios arquitectónicos.

¿Buscas respaldo corporativo empresarial? Consulta la política *Aegis Citadel Enterprise* en nuestro [Manifiesto de Financiamiento (FUNDING.md)](FUNDING.md).
