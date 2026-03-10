### [INST-102] Especificación: Self-Healing One-Line Deploy

#### 1. Visión General
Implementación de un script maestro de instalación (`install_aegis.sh`) robusto y a prueba de fallos que orqueste todo el ecosistema Aegis OS mediante Docker Compose, permitiendo un despliegue rápido con un solo comando `curl`.

#### 2. Requerimientos SRE
1. **Auto-Sanación de Dependencias:** Verificar e instalar `git`, `curl`, `docker` y `docker-compose-plugin` de forma automática.
2. **Setup de Espacio de Trabajo:** Crear `/opt/aegis`, clonar los 3 repositorios (`Aegis-ANK`, `Aegis-Shell`, `Aegis-Installer`) y gestionar permisos de usuario.
3. **Guardia Citadel (.env):** Bloqueo total del despliegue si no existe un archivo `.env` configurado.
4. **Validación Activa:** El script debe confirmar que el BFF (`aegis-shell`) y el Kernel (`aegis-ank`) están operativos antes de finalizar.

#### 3. Criterios de Aceptación (DoD)
- [x] Script `install_aegis.sh` refactorizado y funcional.
- [x] README.md actualizado con instrucciones de "One-Line Deploy".
- [x] Validación exitosa de los endpoints `/health` y `/api/system/state`.
- [x] Gestión de permisos de escritura para el usuario invocador.
