### [INST-104] Especificación: Hardening del Instalador - Auto-Healing & Pre-flight
 
#### 1. Visión General (Abstract)
El despliegue de Aegis debe ser resiliente a configuraciones de permisos incompletas en el host (específicamente Docker) y proporcionar retroalimentación inmediata sobre la idoneidad del hardware para perfiles de alto rendimiento (GPU).

#### 2. Requerimientos de Hardening
- **Auto-Healing de Docker**: Detectar fallos de conexión al socket de Docker por falta de permisos. Si el usuario no pertenece al grupo `docker`, el script debe agregarlo automáticamente usando privilegios de root.
- **Validación de Hardware (Pre-flight)**: Verificar la disponibilidad y operatividad de `nvidia-smi`. Advertir explícitamente si se selecciona el perfil `Monolith` pero el hardware no cuenta con drivers NVIDIA funcionales.
- **Orquestación Garantizada**: Implementar un fallback de ejecución directa por root si la sesión actual del usuario no reconoce los cambios de grupo aplicados, asegurando que el despliegue no se detenga.

#### 3. Criterios de Aceptación (DoD)
1. Implementar función `preflight_hardening` en `install_aegis.sh`.
2. Validar `docker ps` como el usuario invocador.
3. Ejecutar `usermod -aG docker $USER` si es necesario.
4. Mostrar advertencia crítica si `Monolith` es seleccionado sin GPU activa.
5. Garantizar el despliegue Zero-Touch mediante orquestación resiliente.
