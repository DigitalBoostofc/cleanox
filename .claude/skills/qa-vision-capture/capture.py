"""Generic vision-QA helper for a macOS window (no LLM calls here).

Target window is selected by PARAMETERS — never hardcoded:
    QA_TARGET_OWNER  (required)  process owner name, e.g. "Electron", "Safari"
    QA_TARGET_TITLE  (optional)  substring of the window title to disambiguate
    QA_OUT_DIR       (optional)  frames dir, default "runs/qa"

Commands:
    capture.py shot                 -> capture target window, print PNG path
    capture.py click <x> <y>        -> click at screenshot coords (logical px)
    capture.py doubleclick <x> <y>
    capture.py type "some text"
    capture.py key <return|esc|tab|space|delete|arrow-up|arrow-down|arrow-left|arrow-right>

Screenshot is resized to the LOGICAL window size (retina 2x -> 1x), so click
coords read off the image map 1:1. Frames are numbered under QA_OUT_DIR.
Only ever acts on the target window — never on other apps.
"""

import os
import subprocess
import sys

from PIL import Image
from Quartz import (CGWindowListCopyWindowInfo, kCGNullWindowID,
                    kCGWindowListOptionOnScreenOnly)

OWNER = os.environ.get("QA_TARGET_OWNER", "").strip()
TITLE = os.environ.get("QA_TARGET_TITLE", "").strip()
OUT_DIR = os.environ.get("QA_OUT_DIR", "runs/qa")
SHOT = os.path.join(OUT_DIR, "current.png")


def target_window():
    if not OWNER:
        raise SystemExit("ERRO: defina QA_TARGET_OWNER (nome do processo da janela-alvo)")
    wins = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID)
    candidates = []
    for w in wins:
        if w.get("kCGWindowOwnerName") != OWNER:
            continue
        if TITLE and TITLE.lower() not in str(w.get("kCGWindowName", "")).lower():
            continue
        b = w.get("kCGWindowBounds", {})
        if b.get("Width", 0) < 200 or b.get("Height", 0) < 200:
            continue  # skip menubar/status windows
        candidates.append(w)
    if not candidates:
        hint = f" com título contendo '{TITLE}'" if TITLE else ""
        raise SystemExit(f"ERRO: janela do owner '{OWNER}'{hint} não encontrada. App rodando?")
    w = max(candidates, key=lambda w: w["kCGWindowBounds"]["Width"])
    b = w["kCGWindowBounds"]
    return (int(w["kCGWindowNumber"]),
            int(b["X"]), int(b["Y"]), int(b["Width"]), int(b["Height"]))


def focus_target():
    subprocess.run(["osascript", "-e",
                    'tell application "System Events" to set frontmost of '
                    f'process "{OWNER}" to true'], check=True, capture_output=True)


def shot() -> str:
    win_id, _, _, w, h = target_window()
    os.makedirs(OUT_DIR, exist_ok=True)
    raw = os.path.join(OUT_DIR, "raw.png")
    subprocess.run(["screencapture", "-o", "-x", f"-l{win_id}", raw], check=True)
    img = Image.open(raw).convert("RGB")
    img = img.resize((w, h), Image.LANCZOS)  # retina 2x -> logical px
    img.save(SHOT)
    n = len([f for f in os.listdir(OUT_DIR) if f.startswith("frame_")])
    img.save(os.path.join(OUT_DIR, f"frame_{n:06d}.png"))
    return os.path.abspath(SHOT)


def to_global(x: int, y: int) -> tuple[int, int]:
    _, bx, by, w, h = target_window()
    if not (0 <= x <= w and 0 <= y <= h):
        raise SystemExit(f"ERRO: coordenada ({x},{y}) fora da janela {w}x{h}")
    return bx + x, by + y


def main() -> None:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "shot"

    if cmd == "shot":
        print(shot())
        return

    focus_target()
    if cmd in ("click", "doubleclick"):
        gx, gy = to_global(int(sys.argv[2]), int(sys.argv[3]))
        action = "dc" if cmd == "doubleclick" else "c"
        subprocess.run(["cliclick", f"{action}:{gx},{gy}"], check=True)
    elif cmd == "type":
        subprocess.run(["cliclick", "t:" + sys.argv[2]], check=True)
    elif cmd == "key":
        subprocess.run(["cliclick", "kp:" + sys.argv[2]], check=True)
    else:
        raise SystemExit(f"comando desconhecido: {cmd}")

    import time
    time.sleep(0.6)  # deixa a UI reagir antes do próximo shot
    print(shot())


if __name__ == "__main__":
    main()
