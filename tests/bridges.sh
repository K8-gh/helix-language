#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME="$(realpath "$1")"
TMP="$(mktemp -d '/tmp/Helix bridge tests.XXXXXX')"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/mock-bin"

cat >"$TMP/index.html" <<'EOF'
<!doctype html>
<html><head><link rel="stylesheet" href="style.css"><script src="app.js"></script></head><body>Helix bridge</body></html>
EOF
printf 'body { color: #123; }\n' >"$TMP/style.css"
printf 'console.log("js bridge ok")\n' >"$TMP/app.js"
cat >"$TMP/mock-bin/xdg-open" <<'EOF'
#!/bin/sh
printf 'open\t%s\n' "$1" >> "$BRIDGE_LOG"
EOF
cat >"$TMP/mock-bin/node" <<'EOF'
#!/bin/sh
printf 'node\t%s\n' "$1" >> "$BRIDGE_LOG"
printf 'js bridge ok\n'
EOF
chmod +x "$TMP/mock-bin/xdg-open" "$TMP/mock-bin/node"

cat >"$TMP/program.c" <<'EOF'
#include <stdio.h>
int main(void) { puts("c bridge ok"); return 0; }
EOF
cat >"$TMP/program.cpp" <<'EOF'
#include <iostream>
int main() { std::cout << "cpp bridge ok" << std::endl; }
EOF

{
  printf 'helix console\n'
  printf 'bridge html "%s"\n' "$TMP/index.html"
  printf 'bridge css "%s"\n' "$TMP/style.css"
  printf 'bridge js "%s"\n' "$TMP/app.js"
  if command -v cc >/dev/null 2>&1; then printf 'bridge c "%s"\n' "$TMP/program.c"; fi
  if command -v c++ >/dev/null 2>&1; then printf 'bridge cpp "%s"\n' "$TMP/program.cpp"; fi
} >"$TMP/bridge-test.hlx"

BRIDGE_LOG="$TMP/bridge.log" PATH="$TMP/mock-bin:$PATH" "$RUNTIME" "$TMP/bridge-test.hlx" >"$TMP/output.txt"
grep -qx 'js bridge ok' "$TMP/output.txt"
grep -qx "open$(printf '\t')$TMP/index.html" "$TMP/bridge.log"
grep -qx "open$(printf '\t')$TMP/style.css" "$TMP/bridge.log"
grep -qx "node$(printf '\t')$TMP/app.js" "$TMP/bridge.log"
if command -v cc >/dev/null 2>&1; then grep -qx 'c bridge ok' "$TMP/output.txt"; fi
if command -v c++ >/dev/null 2>&1; then grep -qx 'cpp bridge ok' "$TMP/output.txt"; fi

mkdir -p "$TMP/empty-path"
printf 'helix console\nbridge js "%s"\npulse "runtime continued"\n' "$TMP/app.js" >"$TMP/missing-tool.hlx"
PATH="$TMP/empty-path" "$RUNTIME" "$TMP/missing-tool.hlx" >"$TMP/missing-tool.out"
grep -q 'bridge tool is missing' "$TMP/missing-tool.out"
grep -qx 'runtime continued' "$TMP/missing-tool.out"

echo 'Helix external bridges (HTML/CSS/JavaScript/C/C++): OK'
