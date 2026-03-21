# [INST-SEC-120] Fix set +e Not Restored in error()

**Epic:** 23 — Security & Stability Hardening  
**Priority:** CRITICAL  
**Complexity:** MEDIUM  
**Estimated Time:** 2 hours  
**Assigned:** DevOps Engineer  

---

## Context

`install_aegis.sh:62` — La función `error()` ejecuta `set +e` pero nunca restaura `set -e`.

**Impact:** Modo estricto desactivado permanentemente después del primer error, permitiendo ejecución parcial peligrosa.

**Source:** AUDIT_MASTER.md — Finding #7 CRITICAL

---

## Required Changes

**File:** `install_aegis.sh`

```bash
error() {
    # Guardar estado actual de set
    local old_set=$-
    set +e
    
    # Dialog error message
    dialog --msgbox "ERROR: $1" 10 60
    
    # Restaurar estado anterior
    case $old_set in
        *e*) set -e ;;
    esac
    
    exit 1
}
```

---

## Testing

```bash
shellcheck install_aegis.sh
bash -n install_aegis.sh  # Syntax check
```

---

## Acceptance Criteria

- [ ] `set -e` restaurado después de `set +e`
- [ ] shellcheck → 0 warnings
- [ ] Modo estricto verificado con tests

---

**Created:** 2026-03-21
