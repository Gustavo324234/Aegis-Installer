# [INST-SEC-122] Add Strict Mode to aegis_diag.sh

**Epic:** 23  
**Priority:** CRITICAL  
**Time:** 30 min  

---

## Changes

Add strict mode to `aegis_diag.sh`:

```bash
#!/bin/bash
set -euo pipefail  # ADD THIS LINE

# ... rest of script
```

## Acceptance Criteria

- [ ] `set -euo pipefail` added
- [ ] shellcheck → pass
