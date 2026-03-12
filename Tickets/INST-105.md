###[INST-105] Especificación: TUI TTY Allocation Fix (Bootstrapper Hardening) `[DONE]`

#### 1. Visión General (Abstract)
El Aegis Bootstrapper (TUI) implementado en `[ANK-2001]` utiliza `whiptail` para la selección interactiva de perfiles. Sin embargo, cuando el script es invocado mediante el método estándar de despliegue (`curl -sSL ... | sudo bash`), la entrada estándar (`stdin`) es secuestrada por el pipe. Esto provoca que `whiptail` no pueda procesar eventos de teclado (flechas direccionales), imprimiendo códigos ANSI en crudo y bloqueando la instalación.

#### 2. Modificación del Bootstrapper (`install_aegis.sh`)
- **Forzado de TTY:** Todas las invocaciones a `whiptail` dentro del script deben redirigir su entrada estándar explícitamente hacia el terminal físico del usuario utilizando `< /dev/tty`.
- **Ejemplo de refactorización:**
  ```bash
  PROFILE=$(whiptail --title "Aegis OS Bootstrapper" --menu "Select Deployment Profile:" 15 60 2 \
  "1" "Microkernel (Cloud/Edge) - Lightweight" \
  "2" "Monolith (Local GPU) - Heavy" \
  3>&1 1>&2 2>&3 < /dev/tty)