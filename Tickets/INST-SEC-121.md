# [INST-SEC-121] Add set -euo pipefail to uninstall_aegis.sh

**Epic:** 23  
**Priority:** CRITICAL  
**Time:** 30 min  

---

## Changes

Add strict mode to `uninstall_aegis.sh`:

```bash
#!/bin/bash
set -euo pipefail  # ADD THIS LINE

# ... rest of script
```

## Acceptance Criteria

- [ ] `set -euo pipefail` at top of script
- [ ] shellcheck → pass
