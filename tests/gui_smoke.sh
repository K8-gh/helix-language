#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GUI="${HELIX_GUI:-$ROOT/dist/helix-terminal-linux}"
CORE="${HELIX_CORE:-$ROOT/dist/helix-linux-x86_64}"
SAMPLE="$ROOT/examples/desktop_app.hlx"
TMP="$(mktemp -d '/tmp/Helix GUI smoke.XXXXXX')"
trap 'rm -rf "$TMP"' EXIT

for tool in xvfb-run xdotool pgrep; do
  command -v "$tool" >/dev/null || { echo "Missing GUI test tool: $tool" >&2; exit 2; }
done
test -x "$GUI" || { echo "Missing GUI runner: $GUI" >&2; exit 2; }
test -x "$CORE" || { echo "Missing Helix runtime: $CORE" >&2; exit 2; }

xvfb-run -a bash -c '
  set -euo pipefail
  gui="$1"; core="$2"; sample="$3"
  export HELIX_CORE="$core"
  "$gui" "$sample" >/tmp/helix-gui-enter-smoke.log 2>&1 &
  gui_pid=$!
  cleanup() { kill "$gui_pid" 2>/dev/null || true; wait "$gui_pid" 2>/dev/null || true; }
  trap cleanup EXIT

  window=""
  for _ in $(seq 1 80); do
    window="$(xdotool search --onlyvisible --name "Helix App" 2>/dev/null | head -n 1 || true)"
    [ -n "$window" ] && break
    sleep 0.1
  done
  test -n "$window" || { cat /tmp/helix-gui-enter-smoke.log >&2; echo "App window did not open" >&2; exit 1; }
  title="$(xdotool getwindowname "$window")"
  case "$title" in *"Helix App"*) ;; *) echo "Unexpected app title: $title" >&2; exit 1 ;; esac

  child=""
  for _ in $(seq 1 80); do
    child="$(pgrep -P "$gui_pid" | head -n 1 || true)"
    [ -n "$child" ] && break
    sleep 0.1
  done
  test -n "$child" || { echo "Helix runtime child did not start" >&2; exit 1; }
  xdotool windowfocus --sync "$window"
  xdotool type --clearmodifiers --delay 10 "13"
  xdotool key Return
  still_running=1
  for _ in $(seq 1 80); do
    if ! kill -0 "$child" 2>/dev/null; then still_running=0; break; fi
    sleep 0.1
  done
  [ "$still_running" -eq 0 ] || { echo "Enter did not finish the sense-driven app" >&2; exit 1; }
  echo "Helix app window + Enter input: OK"
  cleanup
  trap - EXIT
' bash "$GUI" "$CORE" "$SAMPLE"

cat > "$TMP/buttons.hlx" <<'EOF'
helix app
app title "Helix Button Smoke Test"
app size 680 480
app button 7 "Create marker"
cell event := 0
cell running := 1
while true
    sense event
    if event == 7
        spawn file "button-hit.txt" "." "button event received\n"
    end
end
EOF

xvfb-run -a bash -c '
  set -euo pipefail
  gui="$1"; core="$2"; sample="$3"; tmp="$4"
  export HELIX_CORE="$core"
  cd "$tmp"
  "$gui" "$sample" >/tmp/helix-gui-button-smoke.log 2>&1 &
  gui_pid=$!
  window=""
  child=""
  cleanup() {
    if [ -n "$window" ]; then xdotool windowclose "$window" 2>/dev/null || true; fi
    kill "$gui_pid" 2>/dev/null || true
    if [ -n "$child" ]; then kill "$child" 2>/dev/null || true; fi
    wait "$gui_pid" 2>/dev/null || true
  }
  trap cleanup EXIT

  for _ in $(seq 1 80); do
    window="$(xdotool search --onlyvisible --name "Helix Button Smoke Test" 2>/dev/null | head -n 1 || true)"
    [ -n "$window" ] && break
    sleep 0.1
  done
  test -n "$window" || { cat /tmp/helix-gui-button-smoke.log >&2; echo "Button app window did not open" >&2; exit 1; }
  geometry="$(xdotool getwindowgeometry "$window")"
  grep -q "680x480" <<<"$geometry" || { echo "App size declaration was not applied: $geometry" >&2; exit 1; }
  for _ in $(seq 1 80); do
    child="$(pgrep -P "$gui_pid" | head -n 1 || true)"
    [ -n "$child" ] && break
    sleep 0.1
  done
  test -n "$child" || { echo "Helix button-app runtime did not start" >&2; exit 1; }

  xdotool windowfocus --sync "$window"
  xdotool mousemove --window "$window" 80 58 click 1
  for _ in $(seq 1 80); do
    [ -f "$tmp/button-hit.txt" ] && break
    sleep 0.1
  done
  test -f "$tmp/button-hit.txt" || { cat /tmp/helix-gui-button-smoke.log >&2; echo "Button click did not reach Helix sense/action" >&2; exit 1; }
  grep -qx "button event received" "$tmp/button-hit.txt"
  echo "Helix app native button + event action: OK"
  xdotool windowclose "$window"
  window=""
  trap - EXIT
  cleanup
' bash "$GUI" "$CORE" "$TMP/buttons.hlx" "$TMP"

cat > "$TMP/dialog.hlx" <<'EOF'
helix app
cell answer := 0
dialog answer "Native Dialog Smoke" "Select Yes to continue."
if answer == 1
    spawn file dialog-yes.txt "." "yes"
else
    spawn file dialog-no.txt "." "no"
end
EOF

xvfb-run -a bash -c '
  set -euo pipefail
  gui="$1"; core="$2"; sample="$3"; tmp="$4"
  export HELIX_CORE="$core"
  cd "$tmp"
  "$gui" "$sample" >/tmp/helix-gui-dialog-smoke.log 2>&1 &
  gui_pid=$!
  trap "kill $gui_pid 2>/dev/null || true; child=\$(pgrep -P $gui_pid | head -n 1 || true); [ -z \"\$child\" ] || kill \"\$child\" 2>/dev/null || true" EXIT
  dialog=""
  for _ in $(seq 1 100); do
    dialog="$(xdotool search --onlyvisible --name "Native Dialog Smoke" 2>/dev/null | head -n 1 || true)"
    [ -n "$dialog" ] && break
    sleep 0.1
  done
  test -n "$dialog" || { cat /tmp/helix-gui-dialog-smoke.log >&2; echo "Native dialog did not open" >&2; exit 1; }
  xdotool windowfocus --sync "$dialog"
  xdotool key Right Return
  for _ in $(seq 1 100); do
    [ -f "$tmp/dialog-yes.txt" ] && break
    sleep 0.1
  done
  test -f "$tmp/dialog-yes.txt" || { echo "Dialog Yes response was not stored in the result cell" >&2; exit 1; }
  echo "Helix app native Yes/No dialog + result cell: OK"
' bash "$GUI" "$CORE" "$TMP/dialog.hlx" "$TMP"
