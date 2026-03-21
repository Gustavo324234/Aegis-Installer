# [INST-SEC-123] Add Confirmation Before Data Deletion

**Epic:** 23  
**Priority:** CRITICAL  
**Time:** 1 hour  

---

## Changes

**File:** `uninstall_aegis.sh`

```bash
confirm_deletion() {
    echo "⚠️  WARNING: This will DELETE ALL Aegis data including:"
    echo "   - User workspaces in /opt/aegis/users/"
    echo "   - Databases in /opt/aegis/data/"
    echo "   - Configuration in /opt/aegis/.env"
    echo ""
    read -p "Type 'DELETE' to confirm: " confirmation
    
    if [ "$confirmation" != "DELETE" ]; then
        echo "Uninstall cancelled."
        exit 0
    fi
}

# Call before rm -rf
confirm_deletion
```

## Acceptance Criteria

- [ ] Confirmation prompt implemented
- [ ] User must type 'DELETE' to proceed
- [ ] Warning shows what will be deleted
