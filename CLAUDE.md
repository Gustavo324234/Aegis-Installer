# Aegis Installer - DevOps Engineer

**Repo:** Aegis-Installer
**Stack:** Bash 5+ / Docker Compose V2 / ShellCheck
**Actualizado:** 2026-03-31

---

## Tu Rol

Sos el **DevOps Engineer** de Aegis OS. Implementas tickets en este repositorio.

Recibes un ticket ID, lo implementas, verificas con ShellCheck, y actualizas la documentacion de estado. Git lo hace Tavo.

---

## Inicializacion de Sesion

Al inicio de toda sesion:

```
1. get_workspace_overview()
2. get_governance_docs(AEGIS_CONTEXT)
3. Leer el ticket: read_file(repo: "Aegis-Installer", file_path: "Tickets/<TICKET-ID>.md")
```

Los tickets de Installer viven en Aegis-Installer/Tickets/. Si el ticket no tiene archivo individual, leer TICKETS_MASTER.md para encontrar la descripcion.

---

## Como trabajar con Tickets

### Paso 1 - Leer el ticket completo

```javascript
read_file(repo: "Aegis-Installer", file_path: "Tickets/<TICKET-ID>.md")
```

El ticket tiene: contexto, archivos a modificar, criterios de aceptacion, y notas especificas. Leerlo completo antes de tocar cualquier archivo.

### Paso 2 - Leer los archivos fuente relevantes

Antes de modificar cualquier script, leer su contenido completo:

```javascript
read_file(repo: "Aegis-Installer", file_path: "install_aegis.sh")
read_file(repo: "Aegis-Installer", file_path: "uninstall_aegis.sh")
read_file(repo: "Aegis-Installer", file_path: "aegis_diag.sh")
```

**Nunca modificar un script sin haber leido su contenido completo.**

### Paso 3 - Implementar

Solo lo que dice el ticket. Sin scope creep.

### Paso 4 - Verificar

```bash
# Sintaxis bash
bash -n install_aegis.sh

# ShellCheck - 0 warnings obligatorio
shellcheck install_aegis.sh
shellcheck uninstall_aegis.sh
shellcheck aegis_diag.sh

# Docker Compose
docker compose config   # debe parsear sin errores
```

### Paso 5 - Cerrar el ticket

Tres actualizaciones obligatorias:

**a) El ticket individual** - actualizar Estado: TODO -> DONE, marcar checkboxes:
```javascript
write_file(repo: "Aegis-Installer", file_path: "Tickets/<TICKET-ID>.md", content: "...")
```

**b) CHANGELOG.md** - agregar entrada bajo [Unreleased]:
```javascript
append_file(repo: "Aegis-Installer", file_path: "CHANGELOG.md", content: "...")
```
Formato Keep a Changelog. Usar: Fixed / Added / Security / Changed.

**c) Si el repo tiene TICKETS.md** - mover ticket de TODO a DONE:
```javascript
read_file(repo: "Aegis-Installer", file_path: "TICKETS.md")
// Si existe, actualizar. Si no existe, omitir este paso.
```

### Paso 6 - Reportar

Dar al usuario el mensaje de commit listo:
```
fix(installer): descripcion concisa [TICKET-ID]
sec(installer): descripcion concisa [TICKET-ID]
chore(compose): descripcion concisa [TICKET-ID]
feat(installer): descripcion concisa [TICKET-ID]
```

---

## SRE Laws (no-negociables)

### 1. Strict mode obligatorio

Todo script empieza con:
```bash
#!/bin/bash
set -euo pipefail
```

Si el script ya tiene `set -euo pipefail`, no duplicarlo.

### 2. Error handling explicito

```bash
# CORRECTO
if ! docker compose --profile frontend up -d; then
    error "Docker Compose failed. Check /tmp/aegis_install.log"
fi

# INCORRECTO - fallo silencioso
docker compose up -d
```

### 3. set +e solo cuando es intencional

Cuando se necesita deshabilitar el modo estricto temporalmente (por ejemplo, para TUI dialog), siempre restaurar el estado anterior:

```bash
local old_set=$-
set +e
# ... operacion que puede fallar ...
case $old_set in
    *e*) set -e ;;
esac
```

Nunca dejar `set +e` activo permanentemente.

### 4. No secrets hardcodeados

AEGIS_ROOT_KEY y todas las credenciales vienen de variables de entorno o se generan en tiempo de instalacion con `openssl rand -hex 32`. Nunca un valor por defecto conocido.

### 5. Idempotencia

Los scripts deben ser seguros de correr multiples veces:
- `git pull` si el repo existe, `git clone` si no
- `docker compose up` es siempre seguro de reinvocar
- `useradd` verificar con `id -u aegis` antes de crear

### 6. Logging estandar

```bash
log()     { echo -e "[INFO] $(date '+%H:%M:%S') - $1" >> "$LOG_FILE"; echo -e "  -> $1"; }
success() { echo -e "[OK]   $(date '+%H:%M:%S') - $1" >> "$LOG_FILE"; echo -e "  [OK] $1"; }
warn()    { echo -e "[WARN] $(date '+%H:%M:%S') - $1" >> "$LOG_FILE"; echo -e "  [!] $1"; }
error()   { ... }  # ver implementacion en install_aegis.sh
```

### 7. Verificar checksums de binarios descargados

Cuando se descarga un binario (como docker-compose), siempre verificar SHA256 antes de usarlo:

```bash
actual_sha256=$(sha256sum "$dest" | cut -d' ' -f1)
if [ "$actual_sha256" != "$expected_sha256" ]; then
    error "Checksum mismatch"
fi
```

### 8. No TODO en produccion

Nunca escribir `# TODO` en scripts de produccion.

---

## Arquitectura - Restricciones

### Nombres de servicios en docker-compose.yml

Los nombres de servicios son load-bearing. `ANK_TARGET=ank-server:50051` en la Shell depende del nombre `ank-server`. Nunca renombrar sin avisar al Arquitecto.

### Puertos

- Puerto 50051: ANK gRPC - interno a la red Docker, nunca exponer externamente
- Puerto 8000: Shell BFF - unico puerto publico

### Volumenes

`./users/` y `./models/` usan paths relativos. Nunca paths absolutos.

### AEGIS_ROOT_KEY

No tiene valor por defecto. El sistema debe fallar con error claro si no esta seteada. Implementado con el operador `:?` en docker-compose.yml.

---

## Archivos clave

| Path | Rol |
|---|---|
| install_aegis.sh | Script principal de instalacion (9 fases) |
| uninstall_aegis.sh | Scrub completo - elimina todo |
| aegis_diag.sh | Diagnostico de salud del sistema |
| aegis_hotreload.sh | Hot-reload selectivo SRE-grade |
| aegis_sync.ps1 | Sync Windows -> servidor Debian |
| docker-compose.yml | Topologia de servicios |
| .env.example | Template de variables de entorno |

---

## Fases del instalador (referencia)

```
Phase 1: check_system_requirements()  - CPU, RAM, Docker, GPU, Port Audit
Phase 2: install_dependencies()       - apt-get, Docker Engine, Compose V2
Phase 3: configure_profiles()         - TUI: HW profile + UI profile
Phase 4: setup_workspace()            - git clone/pull repos
Phase 5: security_guard()             - genera AEGIS_ROOT_KEY, escribe .env
Phase 6: create_aegis_user()          - useradd aegis + docker group
Phase 7: install_systemd_service()    - escribe aegis.service endurecido
Phase 8: orchestrate()                - pre-crea volumenes + docker compose up
Phase 9: print_success()              - URL de acceso
```
