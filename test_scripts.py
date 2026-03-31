import os
import re


def test_uninstall_script_has_strict_mode():
    """
    [Contract] INST-SEC-121: Ensure all installer and uninstaller scripts
    use strict bash mode (set -euo pipefail) to prevent partial executions.
    """
    script_path = os.path.join(os.path.dirname(__file__), "uninstall_aegis.sh")
    with open(script_path, "r", encoding="utf-8") as f:
        content = f.read()

    assert (
        "set -euo pipefail" in content
    ), "Strict mode is missing in uninstall_aegis.sh!"


def test_install_script_has_strict_mode():
    script_path = os.path.join(os.path.dirname(__file__), "install_aegis.sh")
    with open(script_path, "r", encoding="utf-8") as f:
        content = f.read()

    assert "set -euo pipefail" in content, "Strict mode is missing in install_aegis.sh!"
