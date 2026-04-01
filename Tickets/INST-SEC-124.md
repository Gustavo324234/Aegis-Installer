# [INST-SEC-124] Verify Checksums of Downloaded Binaries

**Epic:** 23 — Security & Stability Hardening
**Priority:** CRITICAL
**Estado:** DONE ✅ — 2026-03-31 (implementado en install_aegis.sh, verificado por Arquitecto IA)

---

## Contexto

El script descargaba Docker Compose sin verificar la integridad del binario, lo que permitía un ataque de sustitución si la descarga era interceptada.

---

## Implementación (ya en main)

`install_aegis.sh` contiene `download_with_verification()`:

```bash
DOCKER_COMPOSE_SHA256="6d2d6c66b658a9ec68f67d8c7a97e78253ae04e4c7f08d5ed7a3a6e1e86e17cf"

download_with_verification() {
    local url="$1" dest="$2" expected_sha256="$3"
    local max_retries=3
    for attempt in $(seq 1 $max_retries); do
        if curl -L --fail --silent "$url" -o "$dest"; then
            local actual_sha256
            actual_sha256=$(sha256sum "$dest" | cut -d' ' -f1)
            if [ "$actual_sha256" = "$expected_sha256" ]; then
                return 0
            fi
            rm -f "$dest"
        fi
        sleep 5
    done
    error "Failed to download and verify after $max_retries attempts"
}
```

- SHA256 real del binario Docker Compose v2.24.0 linux-x86_64 hardcodeado
- Retry con 3 intentos y 5s de delay
- Falla con `error()` si el checksum no coincide

---

## Criterios de aceptación

- [x] SHA256 verificado post-descarga
- [x] Retry logic implementada (3 intentos)
- [x] Instalación falla con error claro si checksum no coincide
- [x] Implementado y mergeado a `main`
