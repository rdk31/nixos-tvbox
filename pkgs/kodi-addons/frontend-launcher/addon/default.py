import json
import os
import subprocess

import xbmc
import xbmcgui


MANIFEST = "/etc/nixos-tvbox/frontend-launchers.json"
REQUEST_DIRECTORY = "/run/tvbox-frontend"
REQUEST = os.path.join(REQUEST_DIRECTORY, "request")


def notify(message, level=xbmcgui.NOTIFICATION_ERROR):
    xbmcgui.Dialog().notification(
        "External frontends", message, level
    )


def preflight(launcher):
    command = launcher.get("checkCommand")
    if command is None:
        return True

    dialog = xbmcgui.DialogProgress()
    dialog.create("External frontends", f"Checking {launcher['label']}…")
    try:
        result = subprocess.run(
            command,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=launcher.get("checkTimeout", 10),
            check=False,
        )
    except subprocess.TimeoutExpired:
        notify("Sunshine discovery or connection timed out")
        return False
    except OSError as error:
        notify(str(error))
        return False
    finally:
        dialog.close()

    if result.returncode == 0:
        return True

    output = result.stdout.strip().splitlines()
    notify(output[-1][:240] if output else "Moonlight preflight failed")
    return False


try:
    with open(MANIFEST, "r", encoding="utf-8") as manifest_file:
        launchers = json.load(manifest_file)

    if not launchers:
        notify("No frontends are configured")
    else:
        selected = xbmcgui.Dialog().select(
            "Launch frontend",
            [launcher["label"] for launcher in launchers],
        )
        if selected >= 0:
            launcher = launchers[selected]
            if not preflight(launcher):
                raise SystemExit

            launcher_id = launcher["id"]
            temporary_request = os.path.join(
                REQUEST_DIRECTORY, f"request.{os.getpid()}"
            )
            descriptor = os.open(
                temporary_request,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL,
                0o600,
            )
            with os.fdopen(descriptor, "w", encoding="utf-8") as request_file:
                request_file.write(launcher_id + "\n")
                request_file.flush()
                os.fsync(request_file.fileno())
            os.replace(temporary_request, REQUEST)
            xbmc.executebuiltin("Quit")
except (OSError, ValueError, KeyError, TypeError) as error:
    notify(str(error))
