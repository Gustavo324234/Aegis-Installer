### [INST-108] Especificación: TUI Buffer Cleanup & Output Silencing

#### 1. Visión General (Abstract)
La migración a `dialog` [INST-106] mejoró la estabilidad, pero introdujo artefactos visuales ("Ghosting"). Los cuadros de diálogo se apilan en la terminal porque la salida estándar (`stdout/stderr`) de comandos subyacentes (`git`, `echo`) contamina el buffer de video, y no se está limpiando la pantalla entre transiciones.

#### 2. Arquitectura de Limpieza Visual
- **Silenciamiento de STDOUT/STDERR:** Cualquier comando que se ejecute mientras la TUI está activa (ej. `git clone`, `apt-get`) debe ser redirigido a un archivo de log (`/tmp/aegis_install.log`) o a `/dev/null`. Prohibido usar `echo` por fuera de las cajas de `dialog` mientras se está en modo interactivo.
- **Clear Canvas:** Toda invocación a `dialog` debe incluir el flag `--clear` al final de sus parámetros para que limpie su propio rastro al terminar.
- **Transiciones:** Inyectar el comando `clear` nativo de bash entre fases lógicas importantes para asegurar un lienzo negro puro.

#### 3. Criterios de Aceptación (DoD)
1. El progreso de descarga/clonación debe usar `dialog --gauge` recibiendo ÚNICAMENTE números enteros por el pipe, sin fugas de texto de `git`.
2. Al finalizar un cuadro (ej. Selección de Perfil), la pantalla debe limpiarse por completo antes de mostrar el siguiente.
3. Al terminar la instalación, el terminal debe quedar limpio, mostrando solo el mensaje glorioso final.