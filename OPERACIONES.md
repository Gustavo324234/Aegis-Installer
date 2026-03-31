# Aegis OS — Comandos de Operación

Referencia rápida para el smoke test y mantenimiento del servidor Debian.

## Directorio base (servidor)
```bash
cd /home/diego/Documentos/Aegis/Aegis-Installer
```

---

## Durante el smoke test / desarrollo — sincronizar desde Windows

Desde `C:\Aegis\Aegis-Installer\` en Windows:

```powershell
.\aegis_sync.ps1                     # Sincronizar todo
.\aegis_sync.ps1 -Repo shell         # Solo Shell (BFF + UI) — reload ~5 seg
.\aegis_sync.ps1 -Repo ank           # Solo Kernel Rust — recompilación incremental
.\aegis_sync.ps1 -DryRun             # Ver qué se sincronizaría sin hacer nada
.\aegis_sync.ps1 -Server 192.168.1.50  # Usar un servidor distinto
```

El script sincroniza los archivos via rsync y dispara `aegis_hotreload.sh` en el servidor automáticamente. No requiere pasar por GitHub.

**Tiempos esperados:**
| Repo | Qué hace | Tiempo |
|------|----------|--------|
| `shell` | rsync + `docker restart aegis-shell` | ~5 seg |
| `ank` | rsync + `docker compose build ank-server` | ~3-8 min |
| `installer` | rsync + `docker compose up -d --force-recreate` | ~30 seg |

---

## Publicar a GitHub (después de que el smoke test pase)

```bash
# En cada repo modificado:
git add .
git commit -m "fix(shell): descripción [TICKET-ID]"
git push
```

---

## Actualizar desde GitHub (pull imagen nueva)

```bash
# Actualizar todo
docker compose pull && docker compose up -d

# Actualizar solo un servicio
docker compose pull aegis-shell && docker compose up -d aegis-shell
```

---

## Reinicio limpio (borra toda la DB)

Borra la base de datos SQLCipher — todos los tenants y el admin se eliminan.
El sistema vuelve al estado de instalación inicial.

```bash
docker compose down -v && docker compose up -d
```

---

## Logs y diagnóstico

```bash
docker logs aegis-ank   -f    # Kernel Rust en tiempo real
docker logs aegis-shell -f    # BFF Python en tiempo real
docker ps                     # Estado de containers
curl http://localhost:8000/health  # Health check
```
