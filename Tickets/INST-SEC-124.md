# [INST-SEC-124] Verify Checksums of Downloaded Binaries

**Epic:** 23  
**Priority:** CRITICAL  
**Time:** 2 hours  

---

## Changes

**File:** `install_aegis.sh`

```bash
download_docker_compose() {
    local url="https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64"
    local expected_sha256="4c75b0ebd5e1cf48864b70b3fdd31f5e0a5bfa8e1a8f6e8a9b8f3c0a1b2c3d4e"
    
    # Download with retry
    for i in {1..3}; do
        if curl -L "$url" -o /usr/local/bin/docker-compose; then
            break
        fi
        sleep 5
    done
    
    # Verify checksum
    actual_sha256=$(sha256sum /usr/local/bin/docker-compose | cut -d' ' -f1)
    
    if [ "$actual_sha256" != "$expected_sha256" ]; then
        error "Checksum verification failed for docker-compose"
    fi
    
    chmod +x /usr/local/bin/docker-compose
}
```

## Acceptance Criteria

- [ ] SHA256 verification implemented
- [ ] Retry logic for downloads
- [ ] Installation fails if checksum mismatch
