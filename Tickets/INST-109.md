### [INST-109] Especificación: Zero-Touch Log Permission Fix

#### 1. Visión General (Abstract)
El comando oficial de instalación de una sola línea (`curl ... | sudo bash`) falla cuando el archivo `/tmp/aegis_install.log` ya existe y tiene permisos restrictivos (ej. pertenece a otro usuario o se creó sin permisos de escritura global). Esto bloquea el despliegue inicial y degrada la experiencia del usuario final.

#### 2. Protocolo de Saneamiento SRE
- **Inicialización Atómica:** El script debe garantizar que el archivo de log sea escribible por el proceso actual independientemente de su estado previo.
- **Permisos Universales:** Se establece `chmod 666` sobre el log. Al ser un archivo temporal en `/tmp`, esto garantiza que los subprocesos y el proceso principal (incluso si hay cambios de contexto `sudo`) puedan registrar trazas sin fricción.
- **Destrucción de Herencia:** Se realiza un `rm -f` preventivo para eliminar cualquier lock o propiedad persistente de sesiones fallidas anteriores.

#### 3. Criterios de Aceptación (DoD)
1. El bloque de saneamiento debe ejecutarse al inicio absoluto del script, antes de cualquier interacción visual.
2. Todas las funciones de logging (`info`, `success`, `warn`, `error`) deben utilizar la variable `$LOG_FILE`.
3. El script no debe emitir errores por STDOUT/STDERR si el archivo de log no existe o tiene problemas de borrado (silenciamiento vía `/dev/null`).
