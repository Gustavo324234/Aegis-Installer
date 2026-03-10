### [INST-103] Especificación: Zero-Touch Installer (Auto-Env Generation)

#### 1. Visión General (Abstract)
El usuario final no debe editar archivos `.env` manualmente. El script `install_aegis.sh` debe ser capaz de hacer el bootstrap de las credenciales críticas del sistema de forma autónoma antes de levantar Docker, garantizando un despliegue de 1 solo comando.

#### 2. Lógica de Auto-Generación
- El script verificará si `/opt/aegis/.env` existe.
- Si NO existe, el script generará una clave aleatoria de 256 bits (ej. usando `openssl rand -hex 32` o leyendo de `/dev/urandom`).
- El script creará el archivo `.env` automáticamente e inyectará:
  `AEGIS_ROOT_KEY=<la_clave_generada>`
  `ANK_TARGET=ank-server:50051`
- Imprimirá en pantalla un mensaje glorioso: *"Despliegue finalizado. Tu llave criptográfica Root ha sido autogenerada. Ingresa a http://<IP>:8000 para configurar la Inteligencia."*

#### 3. Criterios de Aceptación (DoD)
1. Modificar `install_aegis.sh`.
2. Remover el bloque que abortaba la instalación si no había `.env`.
3. Implementar la auto-generación silenciosa.
4. Asegurar que los permisos del archivo `.env` queden en `600` (solo lectura por el dueño) por seguridad.