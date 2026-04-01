# [INST-SEC-120] Fix set +e Not Restored in error()

**Epic:** 23 — Security & Stability Hardening
**Priority:** CRITICAL
**Estado:** DONE ✅ — 2026-03-31 (implementado en install_aegis.sh, verificado por Arquitecto IA)

---

## Contexto

`install_aegis.sh` — La función `error()` ejecuta `set +e` pero debía restaurar `set -e` al finalizar para no dejar el modo estricto desactivado.

**Impacto original:** Modo estricto desactivado permanentemente después del primer error, permitiendo ejecución parcial peligrosa.

---

## Implementación (ya en main)

La función `error()` en `install_aegis.sh` contiene:

```bash
error() {
    local old_set=$-
    set +e
    # ... dialog / echo ...
    case $old_set in
        *e*) set -e ;;
    esac
    exit 1
}
```

El estado de `set -e` se preserva en `old_set` antes de desactivarlo y se restaura correctamente antes del `exit 1`.

---

## Criterios de aceptación

- [x] `set -e` restaurado después de `set +e` en `error()`
- [x] `shellcheck install_aegis.sh` → 0 warnings
- [x] Implementado y mergeado a `main`
