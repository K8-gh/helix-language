#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME="$(realpath "$1")"
TMP="$(mktemp --suffix=.hlx)"
TEST_DIR="$(mktemp -d '/tmp/Helix 0.8 tests.XXXXXX')"
trap 'rm -f "$TMP" "$TMP.out"; rm -rf "$TEST_DIR"' EXIT

hello="$("$RUNTIME" "$ROOT/examples/hello.hlx")"
grep -q 'Привет, Helix!' <<<"$hello"
grep -q '^42$' <<<"$hello"
grep -q '^14$' <<<"$hello"
grep -q '^43$' <<<"$hello"

app="$("$RUNTIME" "$ROOT/examples/app.hlx")"
grep -q '^Площадь прямоугольника:$' <<<"$app"
grep -q '^42$' <<<"$app"
grep -q '^26$' <<<"$app"

desktop_app="$(printf '13\n' | "$RUNTIME" "$ROOT/examples/desktop_app.hlx")"
grep -q '^Квадрат числа$' <<<"$desktop_app"
grep -q '^Введите целое число и нажмите Enter:$' <<<"$desktop_app"
grep -q '^Результат:$' <<<"$desktop_app"
grep -Fxq '169' <<<"$desktop_app"

calc="$(printf '1\n20\n5\n2\n20\n5\n3\n7\n6\n4\n20\n5\n0\n' | "$RUNTIME" "$ROOT/examples/calculator.hlx")"
grep -q '^25$' <<<"$calc"
grep -q '^15$' <<<"$calc"
grep -q '^42$' <<<"$calc"
grep -q '^4$' <<<"$calc"
grep -q '^До свидания!$' <<<"$calc"

"$RUNTIME" "$ROOT/examples/standard_library.hlx" | diff -u "$ROOT/tests/standard_library.expected" -
"$RUNTIME" "$ROOT/tests/boundaries.hlx" | diff -u "$ROOT/tests/boundaries.expected" -
printf '15\n21\n' | "$RUNTIME" "$ROOT/examples/gemini_level3.hlx" | diff -u "$ROOT/tests/gemini_level3.expected" -

"$RUNTIME" "$ROOT/examples/hardware.hlx" >/dev/null
filesystem_example="$(cd "$TEST_DIR" && "$RUNTIME" "$ROOT/examples/filesystem.hlx")"
grep -q '^Создан динамический файл\.' <<<"$filesystem_example"
grep -Eq '^score=[0-9]+$' <<<"$filesystem_example"
grep -Eq '^record_id=[0-9]+$' <<<"$filesystem_example"
"$RUNTIME" "$ROOT/examples/time_random.hlx" >/dev/null
cat > "$TMP" <<'EOF'
helix console linux
pulse cpu_count()
pulse memory_total_mb()
pulse memory_available_mb()
pulse gpu_count()
EOF
hardware="$("$RUNTIME" "$TMP")"
mapfile -t hw_values <<<"$hardware"
[[ "${#hw_values[@]}" -eq 4 ]]
[[ "${hw_values[0]}" =~ ^[0-9]+$ && "${hw_values[0]}" -ge 1 ]]
[[ "${hw_values[1]}" =~ ^[0-9]+$ && "${hw_values[1]}" -ge 1 ]]
[[ "${hw_values[2]}" =~ ^[0-9]+$ ]]
[[ "${hw_values[3]}" =~ ^[0-9]+$ ]]

cat > "$TMP" <<'EOF'
helix console linux
cell cpu_ok := limit_cpu(1)
pulse cpu_ok
pulse cpu_count()
cell memory_ok := limit_memory_mb(256)
pulse memory_ok
EOF
limits="$("$RUNTIME" "$TMP")"
[[ "$limits" == $'1\n1\n1' ]]

zero_division="$(printf '4\n12\n0\n0\n' | "$RUNTIME" "$ROOT/examples/calculator.hlx")"
grep -q '^Ошибка: делить на ноль нельзя\.$' <<<"$zero_division"
invalid_operation="$(printf '8\n0\n' | "$RUNTIME" "$ROOT/examples/calculator.hlx")"
grep -q '^Ошибка: выбери 0, 1, 2, 3 или 4\.$' <<<"$invalid_operation"

cat > "$TMP" <<'EOF'
helix console helix
pulse 7
EOF
[[ "$("$RUNTIME" "$TMP")" == "7" ]]
cat > "$TMP" <<'EOF'
helix console
pulse 7
EOF
[[ "$("$RUNTIME" "$TMP")" == "7" ]]
cat > "$TMP" <<'EOF'
helix app
pulse 7
EOF
[[ "$("$RUNTIME" "$TMP")" == "7" ]]
cat > "$TMP" <<'EOF'
helix console windows
pulse 7
EOF
if "$RUNTIME" "$TMP" >"$TMP.out" 2>&1; then
  echo 'ERROR: Windows console backend must be rejected by Linux runtime' >&2
  exit 1
fi
grep -q 'not available on this OS' "$TMP.out"
cat > "$TMP" <<'EOF'
helix console python
pulse 7
EOF
if "$RUNTIME" "$TMP" >"$TMP.out" 2>&1; then
  echo 'ERROR: removed Python backend must not be accepted' >&2
  exit 1
fi
grep -q 'header:' "$TMP.out"

cat > "$TMP" <<'EOF'
helix console
if logical_and(true, is_prime(13)) == true
    pulse "boolean-condition-ok"
else
    pulse "ERROR: boolean condition failed"
end
EOF
boolean_output="$("$RUNTIME" "$TMP")"
grep -q '^boolean-condition-ok$' <<<"$boolean_output"

cat > "$TMP" <<'EOF'
helix console
cell i := 0
cell total := 0
while 0 > 1
    pulse "ERROR: false while ran"
end
while i < 5
    if i >= 2
        total := total + i
    else
        total := total + 0
    end
    i := i + 1
end
if total == 9
    pulse "flow-eq-ok"
else
    pulse "ERROR: equality failed"
end
if total != 9
    pulse "ERROR: not-equal failed"
else
    pulse "flow-ne-ok"
end
if total > 8
    pulse "flow-gt-ok"
end
if total <= 9
    pulse "flow-le-ok"
end
if total >= 9
    pulse "flow-ge-ok"
end
EOF
flow="$("$RUNTIME" "$TMP")"
for expected in flow-eq-ok flow-ne-ok flow-gt-ok flow-le-ok flow-ge-ok; do
  grep -q "^$expected$" <<<"$flow"
done
if grep -q 'ERROR:' <<<"$flow"; then
  echo 'ERROR: a control-flow assertion failed' >&2
  exit 1
fi

cat > "$TMP" <<'EOF'
helix console
cell running := 1
if true
    pulse "truthy-true-ok"
end
if false
    pulse "ERROR: false branch ran"
else
    pulse "truthy-false-ok"
end
while running
    pulse "truthy-loop-ok"
    running := 0
end
EOF
truthy_output="$("$RUNTIME" "$TMP")"
for expected in truthy-true-ok truthy-false-ok truthy-loop-ok; do
  grep -qx "$expected" <<<"$truthy_output"
done
if grep -q 'ERROR:' <<<"$truthy_output"; then
  echo 'ERROR: truthy condition regression failed' >&2
  exit 1
fi

printf 'not-a-helix-header\npulse 1\n' > "$TMP"
if "$RUNTIME" "$TMP" >/dev/null 2>&1; then
  echo 'ERROR: missing Helix mode header must be rejected' >&2
  exit 1
fi
printf 'helix console\nprint(1)\n' > "$TMP"
if "$RUNTIME" "$TMP" >/dev/null 2>&1; then
  echo 'ERROR: Python-like print syntax must be rejected' >&2
  exit 1
fi
printf 'helix console\ncell a := 7 / 0\npulse a\n' > "$TMP"
if "$RUNTIME" "$TMP" >/dev/null 2>&1; then
  echo 'ERROR: division by zero must be rejected' >&2
  exit 1
fi
printf 'helix console\npulse -9223372036854775808 / -1\n' > "$TMP"
if "$RUNTIME" "$TMP" >/dev/null 2>&1; then
  echo 'ERROR: signed division overflow must be rejected' >&2
  exit 1
fi
printf 'helix console\nif 1 == 1\npulse 1\n' > "$TMP"
if "$RUNTIME" "$TMP" >/dev/null 2>&1; then
  echo 'ERROR: unclosed if block must be rejected' >&2
  exit 1
fi
printf 'helix console\nend\n' > "$TMP"
if "$RUNTIME" "$TMP" >/dev/null 2>&1; then
  echo 'ERROR: unmatched end must be rejected' >&2
  exit 1
fi
printf 'helix console\nsense value\npulse value\n' > "$TMP"
if printf 'abc\n' | "$RUNTIME" "$TMP" >/dev/null 2>&1; then
  echo 'ERROR: non-numeric sense input must be rejected' >&2
  exit 1
fi
printf 'helix console\npulse abs(1, 2)\n' > "$TMP"
if "$RUNTIME" "$TMP" >/dev/null 2>&1; then
  echo 'ERROR: invalid built-in arity must be rejected' >&2
  exit 1
fi
printf 'helix console\npulse cpu_count(1)\n' > "$TMP"
if "$RUNTIME" "$TMP" >/dev/null 2>&1; then
  echo 'ERROR: zero-argument builtin arity must be checked' >&2
  exit 1
fi
printf 'helix console\npulse mystery(1)\n' > "$TMP"
if "$RUNTIME" "$TMP" >/dev/null 2>&1; then
  echo 'ERROR: unknown built-in must be rejected' >&2
  exit 1
fi
printf 'helix console\npulse sqrt(-1)\n' > "$TMP"
if "$RUNTIME" "$TMP" >/dev/null 2>&1; then
  echo 'ERROR: out-of-range built-in input must be rejected' >&2
  exit 1
fi
printf 'helix console\npulse limit_cpu(0)\n' > "$TMP"
if "$RUNTIME" "$TMP" >/dev/null 2>&1; then
  echo 'ERROR: zero CPU limit must be rejected' >&2
  exit 1
fi
printf 'helix console\npulse limit_memory_mb(16)\n' > "$TMP"
if "$RUNTIME" "$TMP" >/dev/null 2>&1; then
  echo 'ERROR: memory limit below minimum must be rejected' >&2
  exit 1
fi

cat > "$TMP" <<EOF
helix console
spawn dir nested "$TEST_DIR"
spawn file log.txt "$TEST_DIR/nested" "первая строка\\nвторая строка\\n"
append file "$TEST_DIR/nested/log.txt" "третья строка\\n"
pulse file_exists("$TEST_DIR/nested/log.txt")
pulse file_exists("$TEST_DIR/missing.txt")
read file "$TEST_DIR/nested/log.txt"
cell start_ms := time_ms()
pulse sleep_ms(15)
cell elapsed_ms := time_ms() - start_ms
pulse elapsed_ms
pulse random(-5, 5)
pulse random(7, 7)
if 0 == 1
    spawn dir must_not_exist "$TEST_DIR"
end
EOF
fs_output="$("$RUNTIME" "$TMP")"
grep -q '^Создано:' <<<"$fs_output"
grep -q '^Записано в файл:' <<<"$fs_output"
grep -q '^1$' <<<"$fs_output"
grep -q '^0$' <<<"$fs_output"
grep -Fq $'первая строка\nвторая строка\nтретья строка' <<<"$fs_output"
[[ -f "$TEST_DIR/nested/log.txt" ]]
[[ ! -e "$TEST_DIR/must_not_exist" ]]
mapfile -t fs_lines <<<"$fs_output"
[[ "${fs_lines[-4]}" == "0" ]]
[[ "${fs_lines[-3]}" =~ ^[0-9]+$ && "${fs_lines[-3]}" -ge 10 ]]
[[ "${fs_lines[-2]}" =~ ^-?[0-9]+$ && "${fs_lines[-2]}" -ge -5 && "${fs_lines[-2]}" -le 5 ]]
[[ "${fs_lines[-1]}" == "7" ]]

cat > "$TMP" <<EOF
helix console
spawn file log.txt "$TEST_DIR/nested" "OVERWRITE"
EOF
duplicate_output="$("$RUNTIME" "$TMP")"
grep -q 'spawn не выполнен' <<<"$duplicate_output"
[[ "$(cat "$TEST_DIR/nested/log.txt")" == $'первая строка\nвторая строка\nтретья строка' ]]

cat > "$TMP" <<EOF
helix console
remove file "$TEST_DIR/nested/log.txt"
pulse file_exists("$TEST_DIR/nested/log.txt")
EOF
remove_output="$("$RUNTIME" "$TMP")"
grep -q '^Удалён файл:' <<<"$remove_output"
[[ "$(tail -n 1 <<<"$remove_output")" == "0" ]]
[[ ! -e "$TEST_DIR/nested/log.txt" ]]

cat > "$TMP" <<'EOF'
helix console
cell id := 7
cell value := -42
spawn dir "demo_{id}" .
spawn file "record_{id}.txt" "demo_{id}" "value={value}\n"
append file "demo_{id}/record_{id}.txt" "id={id}; json={{\"n\": {value}}}\n"
pulse file_exists("demo_{id}/record_{id}.txt")
read file "demo_{id}/record_{id}.txt"
remove file "demo_{id}/record_{id}.txt"
pulse file_exists("demo_{id}/record_{id}.txt")
EOF
template_output="$(cd "$TEST_DIR" && "$RUNTIME" "$TMP")"
grep -q '^Создано:' <<<"$template_output"
grep -Fxq 'value=-42' <<<"$template_output"
grep -Fxq 'id=7; json={"n": -42}' <<<"$template_output"
grep -Fxq '1' <<<"$template_output"
grep -Fxq '0' <<<"$template_output"
[[ ! -e "$TEST_DIR/demo_7/record_7.txt" ]]

cat > "$TMP" <<'EOF'
helix console
pulse file_exists("missing_{undefined}")
EOF
if "$RUNTIME" "$TMP" >"$TMP.out" 2>&1; then
  echo 'ERROR: unknown template cell must be rejected' >&2
  exit 1
fi
grep -q 'unknown variable' "$TMP.out"

cat > "$TEST_DIR/index.hlx" <<'EOF'
helix console
pulse "module-ok"
EOF
cat > "$TEST_DIR/main.hlx" <<'EOF'
helix console
bridge helix "index.hlx"
pulse "main-ok"
EOF
module_output="$(cd "$TEST_DIR" && "$RUNTIME" main.hlx)"
grep -Fxq 'module-ok' <<<"$module_output"
grep -Fxq 'main-ok' <<<"$module_output"
cat > "$TMP" <<'EOF'
helix console
cell result := 1
dialog result "Title" "Message"
pulse result
EOF
dialog_fallback="$($RUNTIME "$TMP")"
grep -q 'requires a graphical Helix App host' <<<"$dialog_fallback"
grep -Fxq '0' <<<"$dialog_fallback"

echo 'Helix 0.9.2 tests: OK'
