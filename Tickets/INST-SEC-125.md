# INST-SEC-125 — Escribir AEGIS_MTLS_STRICT en .env durante bootstrap

**Épica:** 23 — Security & Stability Hardening (Sprint 2)
**Repo:** Aegis-Installer
**Asignado a:** DevOps Engineer
**Prioridad:** 🔴 Crítica — bloquea smoke test y GOV-103
**Estado:** DONE
**Detectado en:** Smoke test 2026-03-31

---

## Contexto

Durante el smoke test, el Kernel arranca y se apaga inmediatamente en un bucle de reinicio.

**Causa raíz:** `main.rs` en Aegis-ANK evalúa `AEGIS_MTLS_STRICT` con default `"true"`. Si las variables `AEGIS_TLS_CERT` y `AEGIS_TLS_KEY` no están seteadas (y el Installer no las genera), el Kernel llama `anyhow::bail!()` y rechaza arrancar.

El Installer actualmente **no escribe `AEGIS_MTLS_STRICT` en el `.env`** que genera `security_guard()`. Por lo tanto, el Kernel siempre hereda el default `true` → siempre falla en instalaciones nuevas sin certificados.

**Decisión de diseño (no cambiar el default en ANK):**
El default `true` en `main.rs` es correcto para producción con certificados configurados. La responsabilidad de setear el modo inicial corresponde al Installer, que conoce el perfil de despluegue.

**Lógica correcta por perfil:**
- `HW_PROFILE=1` (Cloud/Edge) → `AEGIS_MTLS_STRICT=false` — deployment inicial sin certs
- `HW_PROFILE=2` (Local Monolith) → `AEGIS_MTLS_STRICT=false` — idem
- `HW_PROFILE=3` (Hybrid GPU) → `AEGIS_MTLS_STRICT=false` — idem

En todos los casos del Installer, el admin activa mTLS strict manualmente cuando tiene sus certificados listos. El Installer es para bootstrap inicial, no para producción hardened.

---

## Trabajo requerido

### Archivo: `install_aegis.sh` — función `security_guard()`

Leer el archivo completo antes de editar:
```javascript
read_file(repo: "Aegis-Installer", file_path: "install_aegis.sh")
```

En la función `security_guard()`, dentro del bloque `if [ ! -f "$ENV_PATH" ]` (instalación nueva), agregar `AEGIS_MTLS_STRICT=false` al `.env` generado:

**Antes (bloque de nueva instalación):**
```bash
cat <<EOT > "$ENV_PATH"
AEGIS_ROOT_KEY=$root_key
ANK_TARGET=ank-server:50051
AEGIS_FEATURES=$SELECTED_FEATURES
EOT
```

**Después:**
```bash
cat <<EOT > "$ENV_PATH"
AEGIS_ROOT_KEY=$root_key
ANK_TARGET=ank-server:50051
AEGIS_FEATURES=$SELECTED_FEATURES
# mTLS Strict Mode: set to true only when AEGIS_TLS_CERT and AEGIS_TLS_KEY are configured
AEGIS_MTLS_STRICT=false
EOT
```

Para instalaciones existentes (bloque `else`), agregar también la variable si no existe:

**Después del `sed` existente**, agregar:
```bash
if ! grep -q "^AEGIS_MTLS_STRICT=" "$ENV_PATH"; then
    echo "AEGIS_MTLS_STRICT=false" >> "$ENV_PATH"
fi
```

---

## Criterios de aceptación

- [x] `security_guard()` escribe `AEGIS_MTLS_STRICT=false` en el `.env` de nuevas instalaciones
- [x] `security_guard()` agrega `AEGIS_MTLS_STRICT=false` en `.env` existentes si la variable no está presente
- [x] El comentario en el `.env` explica cuándo activar `true`
- [ ] `shellcheck install_aegis.sh` pasa sin warnings nuevos (No disponible en el sistema)
- [x] `bash -n install_aegis.sh` pasa

---

## Notas para el agente

- Leer el archivo completo antes de editar — `security_guard()` está aproximadamente en la línea 270
- El cambio es quirúrgico: solo agregar líneas dentro de bloques existentes, no reorganizar la función
- NO cambiar el default en `main.rs` de Aegis-ANK — esa es la contraparte correcta
- NO correr el script localmente — solo `bash -n` y `shellcheck` para validar sintaxis
