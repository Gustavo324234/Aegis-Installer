# TAREA: REDISEÑO TOTAL DE AEGIS BOOTSTRAPPER (CLI PROFESSIONAL) [INST-106]

## 📋 Descripción
El instalador actual presenta inestabilidades en la gestión del TTY al usar `whiptail` a través de tuberías. Esta tarea consiste en una refactorización integral hacia `dialog`, implementando una arquitectura resiliente y una estética de grado "Professional Linux".

## 🎯 Objetivos (Leyes de Ingeniería)
1.  **Migración a `dialog`**: Sustituir `whiptail` por `dialog` para una mejor gestión nativa del TTY.
2.  **Arquitectura "Zero-Error"**: 
    - Implementar redirección de descriptores de archivo (`exec 3>&1 1>&2 2>&3`) para asegurar que `dialog` capture el TTY correctamente.
    - Añadir banner minimalista ASCII "Aegis-CLI".
3.  **Modo Dual**:
    - **Interactivo**: Activado si se detecta TTY.
    - **Scripted**: Activado vía flag `--no-tui` o si no hay TTY (HEADLESS/CI).
4.  **Validación Pre-flight**:
    - Generar tabla de estado (CPU, RAM, Docker, NVIDIA).
    - Abortar con `msgbox` en caso de fallo crítico de requisitos.
5.  **Estética Premium**: Uso de barras de progreso reales y pantalla de éxito formateada.

## 🛠️ Especificaciones Técnicas
- **Lenguaje**: Bash (v4+).
- **Dependencia Crítica**: `dialog`.
- **TTY Handler**: `/dev/tty`.

## ✅ Criterios de Aceptación
- [ ] El script se ejecuta sin errores ANSI en instalaciones vía `curl | bash`.
- [ ] `dialog` se instala automáticamente si no está disponible.
- [ ] El modo scripted admite parámetros de configuración por defecto.
- [ ] Las barras de progreso reflejan el estado real de la descarga de repositorios.
- [ ] CHANGELOG.md actualizado.
