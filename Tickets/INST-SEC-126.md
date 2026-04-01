# INST-SEC-126 — Documentar acceso inicial via túnel SSH (InitializeMasterAdmin)

**Épica:** 23 — Security & Stability Hardening (Sprint 2)
**Repo:** Aegis-Installer (README)
**Asignado a:** Arquitecto IA / Documentación
**Prioridad:** 🟡 Media — UX de primer arranque, no bloquea CI
**Estado:** TODO
**Detectado en:** Smoke test 2026-03-31

---

## Contexto

`InitializeMasterAdmin` en el Kernel rechaza peticiones que no vengan de `127.0.0.1` o redes privadas Docker (ADR-016, ANK-SEC-008). Esto es comportamiento **correcto e intencional** — evita que un atacante robe el servidor antes de que el administrador lo configure.

El problema es de **UX y documentación**: cuando un usuario accede por primera vez al servidor desde su browser usando la IP pública, el setup falla silenciosamente con "Fallo de conexión con Ring 0" sin explicar por qué ni cómo resolverlo.

**Soluciones válidas para el usuario (ninguna requiere cambio de código):**

1. **SSH Tunnel (recomendado):** Abrir un túnel local al puerto 8000 del servidor y acceder desde `localhost:8000` en el browser del operador.
   ```bash
   ssh -L 8000:localhost:8000 aegis@<server-ip>
   ```
   Luego abrir `http://localhost:8000` — el BFF ve la petición como local.

2. **Acceder desde el servidor mismo:** Si hay browser disponible en el servidor, `localhost:8000` funciona directamente.

3. **Misma LAN:** Si el operador está en la misma red local que el servidor, la IP privada (`192.168.x.x`) es aceptada por el Kernel.

---

## Trabajo requerido

### Archivo: `README.md` de Aegis-Installer

Leer primero:
```javascript
read_file(repo: "Aegis-Installer", file_path: "README.md")
```

Agregar una sección **"First-Time Setup"** o **"Initial Access"** (antes de "Troubleshooting" si existe, o al final de la sección de uso) con este contenido:

```markdown
## Initial Access — Master Admin Setup

After deployment, the Aegis Shell will be available at `http://<server-ip>:8000`.

**Important:** The first-time Master Admin setup (`InitializeMasterAdmin`) is restricted to
local or private network access for security reasons. Accessing it from a public IP will fail.

**Recommended: SSH tunnel**

Open a local tunnel to the server before opening the browser:

\`\`\`bash
ssh -L 8000:localhost:8000 <user>@<server-ip>
\`\`\`

Then open `http://localhost:8000` in your browser. The setup wizard will work normally.

Once the Master Admin account is created, you can access Aegis from any IP.
```

---

## Criterios de aceptación

- [ ] `README.md` tiene sección de acceso inicial con el comando SSH tunnel
- [ ] La sección explica brevemente por qué existe la restricción (seguridad, no bug)
- [ ] Comando copiable y correcto
- [ ] El README sigue siendo en inglés

---

## Notas

- Este ticket es de documentación pura — no requiere cambios de código
- La restricción de localhost es correcta y no debe removerse (ADR-016)
- El mensaje de error en la UI (Shell) también podría mejorar, pero eso es un ticket separado post-launch
