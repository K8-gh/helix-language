; Helix bootstrap 0.9.2 — x86-64 assembly interpreter.
; The language scanner/parser/runtime below are written in NASM, not C/C++/Python.
; C runtime calls are used only as OS/file/console adapters.

default rel
%ifidn __OUTPUT_FORMAT__, win64
    %define ENTRY wmain
    %define WIN_BUILD 1
%else
    %define ENTRY main
%endif

global ENTRY
extern printf
extern sprintf
extern fwrite
extern fflush
extern getenv
extern fgets
extern fclose
extern getchar
extern ftell
extern fseek
extern exit
extern rand
extern srand
extern time
%ifdef WIN_BUILD
extern _wfopen
extern SetConsoleOutputCP
extern SetConsoleCP
extern GetCurrentProcess
extern GetProcessAffinityMask
extern SetProcessAffinityMask
extern GlobalMemoryStatusEx
extern EnumDisplayDevicesW
extern CreateJobObjectW
extern SetInformationJobObject
extern AssignProcessToJobObject
extern CloseHandle
extern CreateDirectoryW
extern CreateFileW
extern GetFileAttributesW
extern DeleteFileW
extern WriteFile
extern MultiByteToWideChar
extern GetTickCount64
extern Sleep
extern ShellExecuteW
extern CreateProcessW
extern WaitForSingleObject
extern GetExitCodeProcess
extern GetStdHandle
extern GetTempPathW
extern GetTempFileNameW
extern MessageBoxW
%else
extern fopen
extern mkdir
extern open
extern write
extern close
extern unlink
extern clock_gettime
extern nanosleep
extern sched_getaffinity
extern sched_setaffinity
extern sysinfo
extern setrlimit
extern access
extern fork
extern execvp
extern _exit
extern waitpid
extern mkstemp
extern getpid
extern strcpy
%endif

%macro PROLOGUE 0
    push rbp
    mov rbp, rsp
    %ifdef WIN_BUILD
        push rdi
        push rsi
        push rbx
        sub rsp, 40                 ; shadow space plus alignment
    %endif
%endmacro
%macro EPILOGUE 0
    %ifdef WIN_BUILD
        add rsp, 40
        pop rbx
        pop rsi
        pop rdi
    %endif
    mov rsp, rbp
    pop rbp
    ret
%endmacro
%macro FATAL_ALIGN 0
    and rsp, -16
    %ifdef WIN_BUILD
        sub rsp, 32                 ; Windows x64 shadow space
    %endif
%endmacro

section .rodata
mode_rb:        db 'rb', 0
mode_ab:        db 'ab', 0
mode_rb_w:      dw 'r', 'b', 0
mode_ab_w:      dw 'a', 'b', 0
header_console: db 'helix console', 0
header_app:     db 'helix app', 0
console_backend_helix: db 'helix', 0
console_backend_windows: db 'windows', 0
console_backend_linux: db 'linux', 0
gpu_sysfs_prefix: db '/sys/class/drm/card', 0
gpu_sysfs_suffix: db '/device', 0
fmt_usage:      db 'Helix ASM 0.9.2', 10, 'Usage: helix <program.hlx>', 10, 0
fmt_error:      db 'Helix: ', 0
msg_file:       db 'cannot open source file', 10, 0
msg_header:     db 'header: helix console [helix|windows|linux] or helix app', 10, 0
msg_platform:   db 'requested console backend is not available on this OS', 10, 0
msg_syntax:     db 'syntax error: check cell/pulse/sense and matching if/else/end or while/end blocks', 10, 0
msg_unknown:    db 'unknown variable', 10, 0
msg_toomany:    db 'variable limit exceeded (64)', 10, 0
msg_divzero:    db 'division by zero', 10, 0
msg_input:      db 'expected a signed whole number after sense', 10, 0
msg_function:   db 'unknown built-in function', 10, 0
msg_arity:      db 'wrong number of function arguments', 10, 0
msg_range:      db 'argument outside supported range', 10, 0
msg_bridge_missing: db 'Helix: bridge tool is missing or could not be launched; install it with your OS package manager.', 10, 0
msg_bridge_failed: db 'Helix: external bridge command returned an error.', 10, 0
msg_bridge_source: db 'Helix: bridge source file does not exist or is inaccessible.', 10, 0
msg_dialog_unavailable: db 'Helix: dialog requires a graphical Helix App host.', 10, 0
dialog_host_env: db 'HELIX_DIALOG_HOST',0
dialog_protocol_prefix: db 0x1e,'HELIX_DIALOG',9,0
dialog_info_code: db 'I',9,0
dialog_question_code: db 'Q',9,0
dialog_hex_digits: db '0123456789ABCDEF'
fmt_string:     db '%s', 10, 0
fmt_raw_string: db '%s', 0
fmt_number:     db '%lld', 10, 0
fmt_template_integer: db '%lld', 0
fmt_spawn_ok:   db 'Создано: %s', 10, 0
fmt_spawn_fail: db 'Helix: spawn не выполнен (путь недоступен или объект уже существует).', 10, 0
fmt_file_io_fail: db 'Helix: файловая операция не выполнена.', 10, 0
fmt_file_io_ok: db 'Записано в файл: %s', 10, 0
fmt_file_remove_ok: db 'Удалён файл: %s', 10, 0
bi_abs: db 'abs',0
bi_sign: db 'sign',0
bi_min: db 'min',0
bi_max: db 'max',0
bi_clamp: db 'clamp',0
bi_pow: db 'pow',0
bi_mod: db 'mod',0
bi_gcd: db 'gcd',0
bi_lcm: db 'lcm',0
bi_sqrt: db 'sqrt',0
bi_factorial: db 'factorial',0
bi_fibonacci: db 'fibonacci',0
bi_is_even: db 'is_even',0
bi_is_odd: db 'is_odd',0
bi_is_prime: db 'is_prime',0
bi_logical_not: db 'logical_not',0
bi_logical_and: db 'logical_and',0
bi_logical_or: db 'logical_or',0
bi_logical_xor: db 'logical_xor',0
bi_bit_and: db 'bit_and',0
bi_bit_or: db 'bit_or',0
bi_bit_xor: db 'bit_xor',0
bi_bit_not: db 'bit_not',0
bi_shift_left: db 'shift_left',0
bi_shift_right: db 'shift_right',0
bi_popcount: db 'popcount',0
bi_digit_sum: db 'digit_sum',0
bi_reverse_digits: db 'reverse_digits',0
bi_is_palindrome: db 'is_palindrome',0
bi_digit_count: db 'digit_count',0
bi_is_power_of_two: db 'is_power_of_two',0
bi_distance: db 'distance',0
bi_average: db 'average',0
bi_ceil_div: db 'ceil_div',0
bi_midpoint: db 'midpoint',0
bi_is_zero: db 'is_zero',0
bi_is_positive: db 'is_positive',0
bi_is_negative: db 'is_negative',0
bi_max3: db 'max3',0
bi_min3: db 'min3',0
bi_sum3: db 'sum3',0
bi_product3: db 'product3',0
bi_clamp01: db 'clamp01',0
bi_square: db 'square',0
bi_cube: db 'cube',0
bi_triangular: db 'triangular',0
bi_choose: db 'choose',0
bi_divisor_count: db 'divisor_count',0
bi_is_perfect_square: db 'is_perfect_square',0
bi_floor_log2: db 'floor_log2',0
kw_true: db 'true',0
kw_false: db 'false',0
bridge_html: db 'html',0
bridge_css: db 'css',0
bridge_js: db 'js',0
bridge_c: db 'c',0
bridge_cpp: db 'cpp',0
bridge_helix: db 'helix',0
bridge_tool_xdg: db 'xdg-open',0
bridge_tool_node: db 'node',0
bridge_tool_cc: db 'cc',0
bridge_tool_cxx: db 'c++',0
bridge_option_output: db '-o',0
bridge_temp_template: db '/tmp/helix-bridge-XXXXXX',0
%ifdef WIN_BUILD
bridge_shell_open_w: dw 'o','p','e','n',0
bridge_tool_node_w: dw 'n','o','d','e','.','e','x','e',0
bridge_tool_cc_w: dw 'g','c','c','.','e','x','e',0
bridge_tool_cxx_w: dw 'g','+','+','.','e','x','e',0
bridge_temp_prefix_w: dw 'h','l','x',0
%endif
bi_cpu_count: db 'cpu_count',0
bi_memory_total_mb: db 'memory_total_mb',0
bi_memory_available_mb: db 'memory_available_mb',0
bi_gpu_count: db 'gpu_count',0
bi_limit_cpu: db 'limit_cpu',0
bi_limit_memory_mb: db 'limit_memory_mb',0
bi_file_exists: db 'file_exists',0
bi_random: db 'random',0
bi_time_ms: db 'time_ms',0
bi_sleep_ms: db 'sleep_ms',0

section .bss
argc_value:     resq 1
argv_value:     resq 1
file_value:     resq 1
line_buffer:    resb 4096
cursor:         resq 1
id_buffer:      resb 32
target_buffer:  resb 32
var_names:      resb 2048         ; 64 slots * 32 bytes
var_values:     resq 64
var_count:      resq 1
pending_value:  resq 1
string_pointer: resq 1
stack_left:     resq 1
operator:       resb 1
input_value:    resq 1
input_sign:     resq 1
input_state:    resq 1
if_depth:       resq 1
if_frame_index: resq 1
condition_left: resq 1
condition_right: resq 1
line_start_offset: resq 1
condition_operator: resb 1
active_flag:    resb 1
console_mode:   resq 1
if_parent:      resb 64
if_condition:   resb 64
if_else_seen:   resb 64
if_type:        resb 64
while_line_offset: resq 64
affinity_current: resb 128
affinity_target: resb 128
sysinfo_buffer: resb 112
memory_status_buffer: resb 64
gpu_device_buffer: resb 840
gpu_path_buffer: resb 64
resource_limit_buffer: resb 144
rlimit_buffer: resq 2
process_affinity_mask: resq 1
system_affinity_mask: resq 1
new_affinity_mask: resq 1
resource_count: resq 1
gpu_index: resq 1
gpu_count_result: resq 1
memory_job_handle: resq 1
memory_job_assigned: resq 1
spawn_arg_dest: resq 1
spawn_arg_capacity: resq 1
spawn_arg_length: resq 1
spawn_parse_escapes: resq 1
template_input_ptr: resq 1
template_input_length: resq 1
template_input_index: resq 1
template_output_length: resq 1
template_variable_length: resq 1
template_number_length: resq 1
template_number_value: resq 1
template_saved_rsp: resq 1
template_output_buffer: resb 4096
template_number_buffer: resb 32
spawn_content_length: resq 1
spawn_kind: resq 1
spawn_name_buffer: resb 512
spawn_parent_buffer: resb 4096
spawn_content_buffer: resb 4096
spawn_target_buffer: resb 4096
spawn_wide_buffer: resw 4096
file_io_handle: resq 1
file_io_buffer: resb 4096
file_io_count: resq 1
file_io_success: resq 1
time_buffer: resb 16
sleep_buffer: resb 16
sleep_remaining_buffer: resb 16
rng_seeded:    resq 1
bridge_mode:   resq 1
bridge_pid:    resq 1
bridge_status: resd 1
bridge_temp_fd:resd 1
bridge_temp_path: resb 64
bridge_argv:   resq 5
dialog_title_buffer: resb 512
dialog_message_buffer: resb 4096
dialog_packet_buffer: resb 10000
dialog_packet_cursor: resq 1
dialog_result_slot: resq 1
dialog_answer: resq 1
dialog_host_flag: resq 1
dialog_read_first: resq 1
dialog_hex_source: resq 1
dialog_hex_cursor: resq 1
dialog_hex_value: resq 1
%ifdef WIN_BUILD
bridge_temp_directory_w: resw 1024
bridge_temp_path_w: resw 1024
dialog_title_wide: resw 512
dialog_message_wide: resw 4096
bridge_command_line_w: resw 8192
bridge_tool_pointer: resq 1
bridge_command_kind: resq 1
bridge_startup_info: resb 104
bridge_process_info: resb 24
bridge_exit_code: resd 1
%endif

section .text

ENTRY:
    PROLOGUE
    mov byte [active_flag], 1
%ifdef WIN_BUILD
    mov [argc_value], ecx
    mov [argv_value], rdx
    mov ecx, 65001
    call SetConsoleOutputCP
    mov ecx, 65001
    call SetConsoleCP
%else
    mov [argc_value], edi
    mov [argv_value], rsi
%endif
    cmp qword [argc_value], 2
    jae .have_arg
    lea rdi, [fmt_usage]
%ifdef WIN_BUILD
    mov rcx, rdi
%else
    mov rdi, rdi
%endif
    xor eax, eax
    call printf
    xor eax, eax
    jmp .return
.have_arg:
    mov rax, [argv_value]
    mov rdi, [rax + 8]
%ifdef WIN_BUILD
    lea rdx, [mode_rb_w]
    mov rcx, rdi
    mov rdx, rdx
    call _wfopen
%else
    lea rsi, [mode_rb]
    call fopen
%endif
    test rax, rax
    jnz .file_open
    lea rdi, [fmt_error]
%ifdef WIN_BUILD
    mov rcx, rdi
%else
    mov rdi, rdi
%endif
    xor eax, eax
    call printf
    lea rdi, [msg_file]
%ifdef WIN_BUILD
    mov rcx, rdi
%else
    mov rdi, rdi
%endif
    xor eax, eax
    call printf
    mov eax, 1
    jmp .return
.file_open:
    mov [file_value], rax
    call read_line
    test rax, rax
    jz .bad_header
    ; `helix app` is accepted as the default Helix runner mode.
    lea rdi, [line_buffer]
    lea rsi, [header_app]
    mov ecx, 9
    cld
    repe cmpsb
    jne .try_console_header
    mov qword [dialog_host_flag], 1
    lea rax, [line_buffer+9]
    cmp byte [rax], 10
    je .header_platform_check
    cmp byte [rax], 13
    je .header_platform_check
    cmp byte [rax], 0
    je .header_platform_check
    jmp .bad_header
.try_console_header:
    lea rdi, [line_buffer]
    lea rsi, [header_console]
    mov ecx, 13
    cld
    repe cmpsb
    jne .bad_header
    mov qword [console_mode], 0
    cmp byte [line_buffer+13], 10
    je .header_platform_check
    cmp byte [line_buffer+13], 13
    je .header_platform_check
    cmp byte [line_buffer+13], 0
    je .header_platform_check
    cmp byte [line_buffer+13], ' '
    jne .bad_header
    lea rdi, [line_buffer+14]
    lea rsi, [console_backend_helix]
    mov ecx, 5
    cld
    repe cmpsb
    je .check_helix_end
    lea rdi, [line_buffer+14]
    lea rsi, [console_backend_windows]
    mov ecx, 7
    cld
    repe cmpsb
    je .check_windows_end
    lea rdi, [line_buffer+14]
    lea rsi, [console_backend_linux]
    mov ecx, 5
    cld
    repe cmpsb
    je .check_linux_end
    jmp .bad_header
.check_helix_end:
    cmp byte [line_buffer+19], 10
    je .header_platform_check
    cmp byte [line_buffer+19], 13
    je .header_platform_check
    cmp byte [line_buffer+19], 0
    je .header_platform_check
    jmp .bad_header
.check_windows_end:
    cmp byte [line_buffer+21], 10
    je .set_windows_mode
    cmp byte [line_buffer+21], 13
    je .set_windows_mode
    cmp byte [line_buffer+21], 0
    jne .bad_header
.set_windows_mode:
    mov qword [console_mode], 1
    jmp .header_platform_check
.check_linux_end:
    cmp byte [line_buffer+19], 10
    je .set_linux_mode
    cmp byte [line_buffer+19], 13
    je .set_linux_mode
    cmp byte [line_buffer+19], 0
    jne .bad_header
.set_linux_mode:
    mov qword [console_mode], 2
.header_platform_check:
%ifdef WIN_BUILD
    cmp qword [console_mode], 2
    je .wrong_platform
%else
    cmp qword [console_mode], 1
    je .wrong_platform
%endif
    jmp .header_ok
.wrong_platform:
    lea rdi, [fmt_error]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
    lea rdi, [msg_platform]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
    mov rdi, [file_value]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    call fclose
    mov eax, 1
    jmp .return
.bad_header:
    lea rdi, [fmt_error]
%ifdef WIN_BUILD
    mov rcx, rdi
%else
    mov rdi, rdi
%endif
    xor eax, eax
    call printf
    lea rdi, [msg_header]
%ifdef WIN_BUILD
    mov rcx, rdi
%else
    mov rdi, rdi
%endif
    xor eax, eax
    call printf
    mov rdi, [file_value]
%ifdef WIN_BUILD
    mov rcx, rdi
%else
    mov rdi, rdi
%endif
    call fclose
    mov eax, 1
    jmp .return
.header_ok:
.read_next:
    mov rdi, [file_value]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    call ftell
    mov [line_start_offset], rax
    call read_line
    test rax, rax
    jz .done
    call process_line
    jmp .read_next
.done:
    cmp qword [if_depth], 0
    jne error_syntax
    mov rdi, [file_value]
%ifdef WIN_BUILD
    mov rcx, rdi
%else
    mov rdi, rdi
%endif
    call fclose
    xor eax, eax
.return:
    EPILOGUE

; fgets(line_buffer, sizeof(line_buffer), file_value)
read_line:
    PROLOGUE
%ifdef WIN_BUILD
    lea rcx, [line_buffer]
    mov edx, 4096
    mov r8, [file_value]
%else
    lea rdi, [line_buffer]
    mov esi, 4096
    mov rdx, [file_value]
%endif
    call fgets
    EPILOGUE

skip_spaces:
    mov rax, [cursor]
.loop:
    cmp byte [rax], ' '
    je .advance
    cmp byte [rax], 9
    je .advance
    cmp byte [rax], 13
    je .advance
    mov [cursor], rax
    ret
.advance:
    inc rax
    jmp .loop

; Copies an ASCII identifier at cursor to id_buffer. Returns length in eax.
parse_identifier:
    lea rdi, [id_buffer]
    xor eax, eax
    mov ecx, 32
    cld
    rep stosb
    mov rsi, [cursor]
    lea rdi, [id_buffer]
    xor ecx, ecx
.first:
    mov al, [rsi]
    cmp al, '_'
    je .copy
    cmp al, 'A'
    jb .invalid_first
    cmp al, 'Z'
    jbe .copy
    cmp al, 'a'
    jb .invalid_first
    cmp al, 'z'
    jbe .copy
.invalid_first:
    test ecx, ecx
    jz .bad
    jmp .finish
.copy:
    cmp ecx, 31
    jae .bad
    mov [rdi], al
    inc rsi
    inc rdi
    inc ecx
    jmp .next
.next:
    mov al, [rsi]
    cmp al, '_'
    je .copy
    cmp al, 'A'
    jb .digit
    cmp al, 'Z'
    jbe .copy
    cmp al, 'a'
    jb .digit
    cmp al, 'z'
    jbe .copy
.digit:
    cmp al, '0'
    jb .finish
    cmp al, '9'
    jbe .copy
.finish:
    mov [cursor], rsi
    mov eax, ecx
    ret
.bad:
    xor eax, eax
    ret

; Find id_buffer. Returns slot index or -1 in rax.
lookup_variable:
    xor r10d, r10d
.loop:
    cmp r10, [var_count]
    jae .missing
    mov rax, r10
    shl rax, 5
    lea r11, [rel var_names]
    lea rdi, [r11 + rax]
    lea rsi, [id_buffer]
    mov ecx, 32
    cld
    repe cmpsb
    je .found
    inc r10
    jmp .loop
.found:
    mov rax, r10
    ret
.missing:
    mov rax, -1
    ret

; Store pending_value in the variable named by id_buffer (create if needed).
set_variable:
    call lookup_variable
    cmp rax, -1
    jne .store
    mov rax, [var_count]
    cmp rax, 64
    jae error_toomany
    inc qword [var_count]
    mov rdx, rax
    shl rdx, 5
    lea r11, [rel var_names]
    lea rdi, [r11 + rdx]
    lea rsi, [id_buffer]
    mov ecx, 32
    cld
    rep movsb
.store:
    mov rdx, [pending_value]
    lea r11, [rel var_values]
    mov [r11 + rax*8], rdx
    ret

; parse_atom -> integer in rax; handles signed decimal literals and variable names.
parse_atom:
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], '('
    je .parenthesized
    xor r8d, r8d
    mov r9d, 1
    cmp byte [rsi], '-'
    jne .check_digit
    mov r9, -1
    inc rsi
.check_digit:
    cmp byte [rsi], '0'
    jb .maybe_identifier
    cmp byte [rsi], '9'
    ja .maybe_identifier
    xor eax, eax
.number_loop:
    movzx edx, byte [rsi]
    cmp dl, '0'
    jb .number_done
    cmp dl, '9'
    ja .number_done
    imul rax, rax, 10
    sub rdx, '0'
    add rax, rdx
    inc rsi
    jmp .number_loop
.number_done:
    imul rax, r9
    mov [cursor], rsi
    ret
.maybe_identifier:
    mov [cursor], rsi
    call parse_identifier
    test eax, eax
    jz error_syntax
    lea rsi, [rel id_buffer]
    lea rdi, [rel kw_true]
    mov ecx, 5
    cld
    repe cmpsb
    je .boolean_true
    lea rsi, [rel id_buffer]
    lea rdi, [rel kw_false]
    mov ecx, 6
    cld
    repe cmpsb
    je .boolean_false
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], '('
    je .builtin_call
    call lookup_variable
    cmp rax, -1
    je error_unknown
    lea r11, [rel var_values]
    mov rax, [r11 + rax*8]
    ret
.builtin_call:
    lea rsi, [rel id_buffer]
    lea rdi, [rel bi_file_exists]
    mov ecx, 12
    cld
    repe cmpsb
    je .file_exists_call
    call eval_builtin
    ret
.file_exists_call:
    call eval_file_exists
    ret
.boolean_true:
    mov eax, 1
    ret
.boolean_false:
    xor eax, eax
    ret
.parenthesized:
    inc rsi
    mov [cursor], rsi
    call eval_expr
    mov [stack_left], rax
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], ')'
    jne error_syntax
    inc rsi
    mov [cursor], rsi
    mov rax, [stack_left]
    ret

; Built-ins are evaluated in a stack-local frame, so nested calls are safe.
%macro MATCH_BI 3
    lea rsi, [rbp-128]
    lea rdi, [rel %2]
    mov ecx, %3
    cld
    repe cmpsb
    je .do_%1
%endmacro
%macro REQUIRE_ARITY 1
    cmp qword [rbp-96], %1
    jne error_arity
%endmacro

eval_builtin:
    PROLOGUE
    sub rsp, 256
    mov qword [rbp-72], 0
    mov qword [rbp-80], 0
    mov qword [rbp-88], 0
    mov qword [rbp-96], 0
    lea rsi, [rel id_buffer]
    lea rdi, [rbp-128]
    mov ecx, 32
    cld
    rep movsb
    mov rsi, [cursor]
    cmp byte [rsi], '('
    jne error_arity
    inc qword [cursor]
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], ')'
    je .zero_args
    call eval_expr
    mov [rbp-72], rax
    mov qword [rbp-96], 1
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], ','
    jne .close_args
    inc qword [cursor]
    call eval_expr
    mov [rbp-80], rax
    mov qword [rbp-96], 2
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], ','
    jne .close_args
    inc qword [cursor]
    call eval_expr
    mov [rbp-88], rax
    mov qword [rbp-96], 3
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], ','
    je error_arity
.close_args:
    mov rsi, [cursor]
    cmp byte [rsi], ')'
    jne error_arity
    inc qword [cursor]
.dispatch:

    MATCH_BI abs, bi_abs, 4
    MATCH_BI sign, bi_sign, 5
    MATCH_BI min, bi_min, 4
    MATCH_BI max, bi_max, 4
    MATCH_BI clamp, bi_clamp, 6
    MATCH_BI pow, bi_pow, 4
    MATCH_BI mod, bi_mod, 4
    MATCH_BI gcd, bi_gcd, 4
    MATCH_BI lcm, bi_lcm, 4
    MATCH_BI sqrt, bi_sqrt, 5
    MATCH_BI factorial, bi_factorial, 10
    MATCH_BI fibonacci, bi_fibonacci, 10
    MATCH_BI is_even, bi_is_even, 8
    MATCH_BI is_odd, bi_is_odd, 7
    MATCH_BI is_prime, bi_is_prime, 9
    MATCH_BI logical_not, bi_logical_not, 12
    MATCH_BI logical_and, bi_logical_and, 12
    MATCH_BI logical_or, bi_logical_or, 11
    MATCH_BI logical_xor, bi_logical_xor, 12
    MATCH_BI bit_and, bi_bit_and, 8
    MATCH_BI bit_or, bi_bit_or, 7
    MATCH_BI bit_xor, bi_bit_xor, 8
    MATCH_BI bit_not, bi_bit_not, 8
    MATCH_BI shift_left, bi_shift_left, 11
    MATCH_BI shift_right, bi_shift_right, 12
    MATCH_BI popcount, bi_popcount, 9
    MATCH_BI digit_sum, bi_digit_sum, 10
    MATCH_BI reverse_digits, bi_reverse_digits, 15
    MATCH_BI is_palindrome, bi_is_palindrome, 14
    MATCH_BI digit_count, bi_digit_count, 12
    MATCH_BI is_power_of_two, bi_is_power_of_two, 16
    MATCH_BI distance, bi_distance, 9
    MATCH_BI average, bi_average, 8
    MATCH_BI ceil_div, bi_ceil_div, 9
    MATCH_BI midpoint, bi_midpoint, 9
    MATCH_BI is_zero, bi_is_zero, 8
    MATCH_BI is_positive, bi_is_positive, 12
    MATCH_BI is_negative, bi_is_negative, 12
    MATCH_BI max3, bi_max3, 5
    MATCH_BI min3, bi_min3, 5
    MATCH_BI sum3, bi_sum3, 5
    MATCH_BI product3, bi_product3, 9
    MATCH_BI clamp01, bi_clamp01, 8
    MATCH_BI square, bi_square, 7
    MATCH_BI cube, bi_cube, 5
    MATCH_BI triangular, bi_triangular, 11
    MATCH_BI choose, bi_choose, 7
    MATCH_BI divisor_count, bi_divisor_count, 14
    MATCH_BI is_perfect_square, bi_is_perfect_square, 18
    MATCH_BI floor_log2, bi_floor_log2, 11
    MATCH_BI cpu_count, bi_cpu_count, 10
    MATCH_BI memory_total_mb, bi_memory_total_mb, 16
    MATCH_BI memory_available_mb, bi_memory_available_mb, 20
    MATCH_BI gpu_count, bi_gpu_count, 10
    MATCH_BI limit_cpu, bi_limit_cpu, 10
    MATCH_BI limit_memory_mb, bi_limit_memory_mb, 16
    MATCH_BI random, bi_random, 7
    MATCH_BI time_ms, bi_time_ms, 8
    MATCH_BI sleep_ms, bi_sleep_ms, 9
    jmp error_function
.zero_args:
    inc qword [cursor]
    jmp .dispatch

.do_abs:
    REQUIRE_ARITY 1
    mov rax, [rbp-72]
    test rax, rax
    jns .return
    neg rax
    js error_range
    jmp .return
.do_sign:
    REQUIRE_ARITY 1
    mov rax, [rbp-72]
    xor edx, edx
    test rax, rax
    setg dl
    test rax, rax
    setl al
    movzx eax, al
    sub edx, eax
    movsxd rax, edx
    jmp .return
.do_min:
    REQUIRE_ARITY 2
    mov rax, [rbp-72]
    cmp rax, [rbp-80]
    cmovg rax, [rbp-80]
    jmp .return
.do_max:
    REQUIRE_ARITY 2
    mov rax, [rbp-72]
    cmp rax, [rbp-80]
    cmovl rax, [rbp-80]
    jmp .return
.do_clamp:
    REQUIRE_ARITY 3
    mov rax, [rbp-80]
    cmp rax, [rbp-88]
    jg error_range
    mov rax, [rbp-72]
    cmp rax, [rbp-80]
    cmovl rax, [rbp-80]
    cmp rax, [rbp-88]
    cmovg rax, [rbp-88]
    jmp .return
.do_pow:
    REQUIRE_ARITY 2
    mov rcx, [rbp-80]
    test rcx, rcx
    js error_range
    cmp rcx, 63
    ja error_range
    mov r8, [rbp-72]
    mov r9, 1
.pow_loop:
    test rcx, 1
    jz .pow_skip_mul
    imul r9, r8
.pow_skip_mul:
    shr rcx, 1
    jz .pow_done
    imul r8, r8
    jmp .pow_loop
.pow_done:
    mov rax, r9
    jmp .return
.do_mod:
    REQUIRE_ARITY 2
    mov rax, [rbp-72]
    mov r10, [rbp-80]
    test r10, r10
    jz error_divzero
    mov r11, 0x8000000000000000
    cmp rax, r11
    jne .mod_safe
    cmp r10, -1
    je error_range
.mod_safe:
    cqo
    idiv r10
    mov rax, rdx
    jmp .return
.do_gcd:
    REQUIRE_ARITY 2
    mov rax, [rbp-72]
    test rax, rax
    jns .gcd_abs_b
    neg rax
    js error_range
.gcd_abs_b:
    mov r10, [rbp-80]
    test r10, r10
    jns .gcd_loop
    neg r10
    js error_range
.gcd_loop:
    test r10, r10
    jz .gcd_done
    xor edx, edx
    div r10
    mov rax, r10
    mov r10, rdx
    jmp .gcd_loop
.gcd_done:
    jmp .return
.do_lcm:
    REQUIRE_ARITY 2
    mov rax, [rbp-72]
    mov r10, [rbp-80]
    test rax, rax
    jz .lcm_zero
    test r10, r10
    jz .lcm_zero
    mov [rbp-104], rax
    mov [rbp-112], r10
    test rax, rax
    jns .lcm_abs_b
    neg rax
    js error_range
.lcm_abs_b:
    test r10, r10
    jns .lcm_gcd
    neg r10
    js error_range
.lcm_gcd:
    test r10, r10
    jz .lcm_calc
    xor edx, edx
    div r10
    mov rax, r10
    mov r10, rdx
    jmp .lcm_gcd
.lcm_calc:
    mov r10, rax
    mov rax, [rbp-104]
    cqo
    idiv r10
    imul rax, [rbp-112]
    test rax, rax
    jns .return
    neg rax
    jmp .return
.lcm_zero:
    xor eax, eax
    jmp .return
.do_sqrt:
    REQUIRE_ARITY 1
    mov r10, [rbp-72]
    test r10, r10
    js error_range
    cmp r10, 2
    jb .sqrt_small
    mov [rbp-104], r10
.sqrt_loop:
    mov rax, [rbp-72]
    xor edx, edx
    div qword [rbp-104]
    add rax, [rbp-104]
    shr rax, 1
    cmp rax, [rbp-104]
    jae .sqrt_done
    mov [rbp-104], rax
    jmp .sqrt_loop
.sqrt_done:
    mov rax, [rbp-104]
    jmp .return
.sqrt_small:
    mov rax, r10
    jmp .return
.do_factorial:
    REQUIRE_ARITY 1
    mov rcx, [rbp-72]
    test rcx, rcx
    js error_range
    cmp rcx, 20
    ja error_range
    mov rax, 1
.fact_loop:
    test rcx, rcx
    jz .return
    imul rax, rcx
    dec rcx
    jmp .fact_loop
.do_fibonacci:
    REQUIRE_ARITY 1
    mov rcx, [rbp-72]
    test rcx, rcx
    js error_range
    cmp rcx, 92
    ja error_range
    xor r8d, r8d
    mov r9d, 1
    xor r10d, r10d
.fib_loop:
    cmp r10, rcx
    jae .fib_done
    mov r11, r8
    add r11, r9
    mov r8, r9
    mov r9, r11
    inc r10
    jmp .fib_loop
.fib_done:
    mov rax, r8
    jmp .return
.do_is_even:
    REQUIRE_ARITY 1
    mov rax, [rbp-72]
    and eax, 1
    xor eax, 1
    jmp .return
.do_is_odd:
    REQUIRE_ARITY 1
    mov rax, [rbp-72]
    and eax, 1
    jmp .return
.do_is_prime:
    REQUIRE_ARITY 1
    mov r10, [rbp-72]
    cmp r10, 2
    jl .prime_false
    cmp r10, 2
    je .prime_true
    mov r11, 1000000000000
    cmp r10, r11
    ja error_range
    test r10, 1
    jz .prime_false
    mov qword [rbp-104], 3
.prime_loop:
    mov r10, [rbp-72]
    mov r11, [rbp-104]
    mov rax, r10
    xor edx, edx
    div r11
    cmp r11, rax
    ja .prime_true
    test rdx, rdx
    jz .prime_false
    add qword [rbp-104], 2
    jmp .prime_loop
.prime_true:
    mov eax, 1
    jmp .return
.prime_false:
    xor eax, eax
    jmp .return
.do_logical_not:
    REQUIRE_ARITY 1
    cmp qword [rbp-72], 0
    sete al
    movzx eax, al
    jmp .return
.do_logical_and:
    REQUIRE_ARITY 2
    xor eax, eax
    cmp qword [rbp-72], 0
    setne al
    cmp qword [rbp-80], 0
    setne dl
    and al, dl
    movzx eax, al
    jmp .return
.do_logical_or:
    REQUIRE_ARITY 2
    xor eax, eax
    cmp qword [rbp-72], 0
    setne al
    cmp qword [rbp-80], 0
    setne dl
    or al, dl
    movzx eax, al
    jmp .return
.do_logical_xor:
    REQUIRE_ARITY 2
    xor eax, eax
    cmp qword [rbp-72], 0
    setne al
    cmp qword [rbp-80], 0
    setne dl
    xor al, dl
    movzx eax, al
    jmp .return
.do_bit_and:
    REQUIRE_ARITY 2
    mov rax, [rbp-72]
    and rax, [rbp-80]
    jmp .return
.do_bit_or:
    REQUIRE_ARITY 2
    mov rax, [rbp-72]
    or rax, [rbp-80]
    jmp .return
.do_bit_xor:
    REQUIRE_ARITY 2
    mov rax, [rbp-72]
    xor rax, [rbp-80]
    jmp .return
.do_bit_not:
    REQUIRE_ARITY 1
    mov rax, [rbp-72]
    not rax
    jmp .return
.do_shift_left:
    REQUIRE_ARITY 2
    mov rcx, [rbp-80]
    cmp rcx, 0
    jl error_range
    cmp rcx, 63
    jg error_range
    mov rax, [rbp-72]
    shl rax, cl
    jmp .return
.do_shift_right:
    REQUIRE_ARITY 2
    mov rcx, [rbp-80]
    cmp rcx, 0
    jl error_range
    cmp rcx, 63
    jg error_range
    mov rax, [rbp-72]
    shr rax, cl
    jmp .return
.do_popcount:
    REQUIRE_ARITY 1
    mov r10, [rbp-72]
    xor r8d, r8d
.pop_loop:
    test r10, r10
    jz .pop_done
    shr r10, 1
    adc r8, 0
    jmp .pop_loop
.pop_done:
    mov rax, r8
    jmp .return
.do_digit_sum:
    REQUIRE_ARITY 1
    mov r10, [rbp-72]
    test r10, r10
    js error_range
    xor r8d, r8d
    mov r11, 10
.digit_sum_loop:
    test r10, r10
    jz .digit_sum_done
    mov rax, r10
    xor edx, edx
    div r11
    add r8, rdx
    mov r10, rax
    jmp .digit_sum_loop
.digit_sum_done:
    mov rax, r8
    jmp .return
.do_reverse_digits:
    REQUIRE_ARITY 1
    mov r10, [rbp-72]
    test r10, r10
    js error_range
    xor r8d, r8d
    mov r11, 10
.reverse_loop:
    test r10, r10
    jz .reverse_done
    mov rax, r10
    xor edx, edx
    div r11
    mov r10, rax
    imul r8, r8, 10
    add r8, rdx
    jmp .reverse_loop
.reverse_done:
    mov rax, r8
    jmp .return
.do_is_palindrome:
    REQUIRE_ARITY 1
    mov r10, [rbp-72]
    test r10, r10
    js error_range
    mov [rbp-104], r10
    xor r8d, r8d
    mov r11, 10
.pal_loop:
    test r10, r10
    jz .pal_done
    mov rax, r10
    xor edx, edx
    div r11
    mov r10, rax
    imul r8, r8, 10
    add r8, rdx
    jmp .pal_loop
.pal_done:
    xor eax, eax
    cmp r8, [rbp-104]
    sete al
    jmp .return
.do_digit_count:
    REQUIRE_ARITY 1
    mov r10, [rbp-72]
    test r10, r10
    js error_range
    mov r8, 1
.count_loop:
    cmp r10, 10
    jb .count_done
    mov rax, r10
    xor edx, edx
    mov r11, 10
    div r11
    mov r10, rax
    inc r8
    jmp .count_loop
.count_done:
    mov rax, r8
    jmp .return
.do_is_power_of_two:
    REQUIRE_ARITY 1
    mov rax, [rbp-72]
    cmp rax, 1
    jl .false_result
    lea r10, [rax-1]
    test rax, r10
    sete al
    movzx eax, al
    jmp .return
.do_distance:
    REQUIRE_ARITY 2
    mov rax, [rbp-72]
    sub rax, [rbp-80]
    test rax, rax
    jns .return
    neg rax
    jmp .return
.do_average:
    REQUIRE_ARITY 2
    mov rax, [rbp-72]
    add rax, [rbp-80]
    cqo
    mov r10, 2
    idiv r10
    jmp .return
.do_midpoint:
    REQUIRE_ARITY 2
    mov r11, 2
    mov rax, [rbp-72]
    cqo
    idiv r11
    mov r8, rax
    mov r9, rdx
    mov rax, [rbp-80]
    cqo
    idiv r11
    add r8, rax
    add r9, rdx
    mov rax, r9
    cqo
    idiv r11
    add rax, r8
    jmp .return
.do_ceil_div:
    REQUIRE_ARITY 2
    mov rax, [rbp-72]
    mov r10, [rbp-80]
    test r10, r10
    jz error_divzero
    mov r11, 0x8000000000000000
    cmp rax, r11
    jne .ceil_safe
    cmp r10, -1
    je error_range
.ceil_safe:
    mov r11, rax
    cqo
    idiv r10
    test rdx, rdx
    jz .return
    xor r11, r10
    test r11, r11
    js .return
    inc rax
    jmp .return
.do_is_zero:
    REQUIRE_ARITY 1
    xor eax, eax
    cmp qword [rbp-72], 0
    sete al
    jmp .return
.do_is_positive:
    REQUIRE_ARITY 1
    xor eax, eax
    cmp qword [rbp-72], 0
    setg al
    jmp .return
.do_is_negative:
    REQUIRE_ARITY 1
    xor eax, eax
    cmp qword [rbp-72], 0
    setl al
    jmp .return
.do_max3:
    REQUIRE_ARITY 3
    mov rax, [rbp-72]
    cmp rax, [rbp-80]
    cmovl rax, [rbp-80]
    cmp rax, [rbp-88]
    cmovl rax, [rbp-88]
    jmp .return
.do_min3:
    REQUIRE_ARITY 3
    mov rax, [rbp-72]
    cmp rax, [rbp-80]
    cmovg rax, [rbp-80]
    cmp rax, [rbp-88]
    cmovg rax, [rbp-88]
    jmp .return
.do_sum3:
    REQUIRE_ARITY 3
    mov rax, [rbp-72]
    add rax, [rbp-80]
    add rax, [rbp-88]
    jmp .return
.do_product3:
    REQUIRE_ARITY 3
    mov rax, [rbp-72]
    imul rax, [rbp-80]
    imul rax, [rbp-88]
    jmp .return
.do_clamp01:
    REQUIRE_ARITY 1
    mov rax, [rbp-72]
    cmp rax, 0
    jge .clamp01_high
    xor eax, eax
    jmp .return
.clamp01_high:
    cmp rax, 1
    jle .return
    mov eax, 1
    jmp .return
.do_square:
    REQUIRE_ARITY 1
    mov rax, [rbp-72]
    imul rax, rax
    jmp .return
.do_cube:
    REQUIRE_ARITY 1
    mov rax, [rbp-72]
    imul rax, rax
    imul rax, [rbp-72]
    jmp .return
.do_triangular:
    REQUIRE_ARITY 1
    mov rax, [rbp-72]
    test rax, rax
    js error_range
    lea r10, [rax+1]
    test al, 1
    jnz .tri_even_b
    shr rax, 1
    imul rax, r10
    jmp .return
.tri_even_b:
    shr r10, 1
    imul rax, r10
    jmp .return
.do_choose:
    REQUIRE_ARITY 2
    mov rax, [rbp-72]
    mov r10, [rbp-80]
    test rax, rax
    js error_range
    test r10, r10
    js error_range
    cmp rax, 60
    jg error_range
    cmp r10, rax
    jg error_range
    mov [rbp-104], rax
    mov [rbp-112], r10
    mov r11, rax
    sub r11, r10
    cmp r10, r11
    cmovg r10, r11
    mov [rbp-120], r10
    mov qword [rbp-136], 1
    mov qword [rbp-144], 1
.choose_loop:
    mov r10, [rbp-144]
    cmp r10, [rbp-120]
    ja .choose_done
    mov rax, [rbp-104]
    sub rax, [rbp-120]
    add rax, r10
    imul rax, [rbp-136]
    xor edx, edx
    div r10
    mov [rbp-136], rax
    inc qword [rbp-144]
    jmp .choose_loop
.choose_done:
    mov rax, [rbp-136]
    jmp .return
.do_divisor_count:
    REQUIRE_ARITY 1
    mov r10, [rbp-72]
    test r10, r10
    jle error_range
    mov r11, 1000000000000
    cmp r10, r11
    ja error_range
    mov [rbp-104], r10
    mov qword [rbp-112], 1
    mov qword [rbp-120], 0
.divisor_loop:
    mov r10, [rbp-112]
    mov rax, [rbp-104]
    xor edx, edx
    div r10
    cmp r10, rax
    ja .divisor_done
    test rdx, rdx
    jnz .divisor_next
    inc qword [rbp-120]
    cmp r10, rax
    je .divisor_next
    inc qword [rbp-120]
.divisor_next:
    inc qword [rbp-112]
    jmp .divisor_loop
.divisor_done:
    mov rax, [rbp-120]
    jmp .return
.do_is_perfect_square:
    REQUIRE_ARITY 1
    mov r10, [rbp-72]
    test r10, r10
    js .false_result
    cmp r10, 2
    jb .perfect_small
    mov [rbp-104], r10
.perfect_sqrt_loop:
    mov rax, [rbp-72]
    xor edx, edx
    div qword [rbp-104]
    add rax, [rbp-104]
    shr rax, 1
    cmp rax, [rbp-104]
    jae .perfect_sqrt_done
    mov [rbp-104], rax
    jmp .perfect_sqrt_loop
.perfect_sqrt_done:
    mov rax, [rbp-104]
    imul rax, rax
    xor edx, edx
    cmp rax, [rbp-72]
    sete dl
    movzx eax, dl
    jmp .return
.perfect_small:
    xor eax, eax
    cmp r10, 1
    sete al
    jmp .return
.do_floor_log2:
    REQUIRE_ARITY 1
    mov r10, [rbp-72]
    test r10, r10
    jle error_range
    xor r8d, r8d
.log2_loop:
    cmp r10, 1
    jbe .log2_done
    shr r10, 1
    inc r8
    jmp .log2_loop
.log2_done:
    mov rax, r8
    jmp .return
.do_random:
    REQUIRE_ARITY 2
    mov rax, [rbp-72]
    mov r10, [rbp-80]
    cmp r10, rax
    jl error_range
    mov [rbp-112], rax
    sub r10, rax
    jo error_range
    inc r10
    jo error_range
    mov r11, 2147483648
    cmp r10, r11
    ja error_range
    mov [rbp-104], r10
    cmp qword [rng_seeded], 0
    jne .random_ready
%ifdef WIN_BUILD
    xor ecx, ecx
%else
    xor edi, edi
%endif
    call time
    mov r11d, eax
    rdtsc
    xor eax, edx
    xor eax, r11d
%ifdef WIN_BUILD
    mov ecx, eax
%else
    mov edi, eax
%endif
    call srand
    mov qword [rng_seeded], 1
.random_ready:
    call rand
    test eax, eax
    js error_range
    xor edx, edx
    mov rcx, [rbp-104]
    div rcx
    mov rax, rdx
    add rax, [rbp-112]
    jmp .return
.do_time_ms:
    REQUIRE_ARITY 0
%ifdef WIN_BUILD
    call GetTickCount64
%else
    mov edi, 1
    lea rsi, [rel time_buffer]
    call clock_gettime
    test eax, eax
    jnz .time_failed
    mov rax, [time_buffer]
    imul rax, 1000
    mov rcx, [time_buffer+8]
    xor edx, edx
    mov r8d, 1000000
    mov r9, rax
    mov rax, rcx
    div r8
    add rax, r9
    jmp .return
.time_failed:
    xor eax, eax
%endif
    jmp .return
.do_sleep_ms:
    REQUIRE_ARITY 1
    mov rax, [rbp-72]
    test rax, rax
    js error_range
    cmp rax, 86400000
    ja error_range
%ifdef WIN_BUILD
    mov ecx, eax
    call Sleep
%else
    xor edx, edx
    mov ecx, 1000
    div rcx
    mov [sleep_buffer], rax
    imul rdx, rdx, 1000000
    mov [sleep_buffer+8], rdx
.sleep_retry:
    lea rdi, [rel sleep_buffer]
    lea rsi, [rel sleep_remaining_buffer]
    mov qword [sleep_remaining_buffer], 0
    mov qword [sleep_remaining_buffer+8], 0
    call nanosleep
    test eax, eax
    jz .sleep_done
    mov rax, [sleep_remaining_buffer]
    or rax, [sleep_remaining_buffer+8]
    jz .sleep_done
    mov rax, [sleep_remaining_buffer]
    mov [sleep_buffer], rax
    mov rax, [sleep_remaining_buffer+8]
    mov [sleep_buffer+8], rax
    jmp .sleep_retry
.sleep_done:
%endif
    xor eax, eax
    jmp .return
.do_cpu_count:
    REQUIRE_ARITY 0
%ifdef WIN_BUILD
    call GetCurrentProcess
    mov rcx, rax
    lea rdx, [rel process_affinity_mask]
    lea r8, [rel system_affinity_mask]
    call GetProcessAffinityMask
    test eax, eax
    jz .hardware_zero
    mov rax, [process_affinity_mask]
    xor r8d, r8d
.cpu_count_win_loop:
    test rax, rax
    jz .cpu_count_done
    lea rdx, [rax-1]
    and rax, rdx
    inc r8
    jmp .cpu_count_win_loop
%else
    xor edi, edi
    mov esi, 128
    lea rdx, [rel affinity_current]
    call sched_getaffinity
    test eax, eax
    js .hardware_zero
    lea rsi, [rel affinity_current]
    mov r9d, 16
    xor r8d, r8d
.cpu_count_linux_word:
    mov rax, [rsi]
.cpu_count_linux_bit:
    test rax, rax
    jz .cpu_count_linux_next
    lea rdx, [rax-1]
    and rax, rdx
    inc r8
    jmp .cpu_count_linux_bit
.cpu_count_linux_next:
    add rsi, 8
    dec r9d
    jnz .cpu_count_linux_word
%endif
.cpu_count_done:
    mov rax, r8
    jmp .return
.do_memory_total_mb:
    REQUIRE_ARITY 0
%ifdef WIN_BUILD
    mov dword [memory_status_buffer], 64
    lea rcx, [rel memory_status_buffer]
    call GlobalMemoryStatusEx
    test eax, eax
    jz .hardware_zero
    mov rax, [memory_status_buffer+8]
    shr rax, 20
%else
    lea rdi, [rel sysinfo_buffer]
    call sysinfo
    test eax, eax
    jnz .hardware_zero
    mov rax, [sysinfo_buffer+32]
    mov ecx, [sysinfo_buffer+104]
    test ecx, ecx
    jnz .memory_total_unit_ready
    mov ecx, 1
.memory_total_unit_ready:
    mul rcx
    shrd rax, rdx, 20
%endif
    jmp .return
.do_memory_available_mb:
    REQUIRE_ARITY 0
%ifdef WIN_BUILD
    mov dword [memory_status_buffer], 64
    lea rcx, [rel memory_status_buffer]
    call GlobalMemoryStatusEx
    test eax, eax
    jz .hardware_zero
    mov rax, [memory_status_buffer+16]
    shr rax, 20
%else
    lea rdi, [rel sysinfo_buffer]
    call sysinfo
    test eax, eax
    jnz .hardware_zero
    mov rax, [sysinfo_buffer+40]
    mov ecx, [sysinfo_buffer+104]
    test ecx, ecx
    jnz .memory_avail_unit_ready
    mov ecx, 1
.memory_avail_unit_ready:
    mul rcx
    shrd rax, rdx, 20
%endif
    jmp .return
.do_gpu_count:
    REQUIRE_ARITY 0
%ifdef WIN_BUILD
    mov qword [gpu_index], 0
    mov qword [gpu_count_result], 0
.gpu_count_win_loop:
    cmp qword [gpu_index], 32
    jae .gpu_count_done
    mov dword [gpu_device_buffer], 840
    xor ecx, ecx
    mov edx, [gpu_index]
    lea r8, [rel gpu_device_buffer]
    xor r9d, r9d
    call EnumDisplayDevicesW
    test eax, eax
    jz .gpu_count_done
    test dword [gpu_device_buffer+324], 8
    jnz .gpu_count_win_next
    inc qword [gpu_count_result]
.gpu_count_win_next:
    inc qword [gpu_index]
    jmp .gpu_count_win_loop
%else
    mov qword [gpu_index], 0
    mov qword [gpu_count_result], 0
.gpu_count_linux_loop:
    cmp qword [gpu_index], 32
    jae .gpu_count_done
    lea rsi, [rel gpu_sysfs_prefix]
    lea rdi, [rel gpu_path_buffer]
    mov ecx, 19
    cld
    rep movsb
    mov eax, [gpu_index]
    xor edx, edx
    mov ecx, 10
    div ecx
    test eax, eax
    jz .gpu_one_digit
    add al, '0'
    mov [rdi], al
    inc rdi
    mov eax, edx
    add al, '0'
    mov [rdi], al
    inc rdi
    jmp .gpu_append_suffix
.gpu_one_digit:
    mov eax, edx
    add al, '0'
    mov [rdi], al
    inc rdi
.gpu_append_suffix:
    lea rsi, [rel gpu_sysfs_suffix]
.gpu_suffix_loop:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz .gpu_suffix_loop
    lea rdi, [rel gpu_path_buffer]
    xor esi, esi
    call access
    test eax, eax
    jnz .gpu_count_linux_next
    inc qword [gpu_count_result]
.gpu_count_linux_next:
    inc qword [gpu_index]
    jmp .gpu_count_linux_loop
%endif
.gpu_count_done:
    mov rax, [gpu_count_result]
    jmp .return
.do_limit_cpu:
    REQUIRE_ARITY 1
    mov rax, [rbp-72]
    test rax, rax
    jle error_range
%ifdef WIN_BUILD
    cmp rax, 64
    ja error_range
%else
    cmp rax, 1024
    ja error_range
%endif
    mov [resource_count], rax
%ifdef WIN_BUILD
    call GetCurrentProcess
    mov rcx, rax
    lea rdx, [rel process_affinity_mask]
    lea r8, [rel system_affinity_mask]
    call GetProcessAffinityMask
    test eax, eax
    jz .resource_false
    mov qword [new_affinity_mask], 0
    xor r8d, r8d
    xor r9d, r9d
.limit_cpu_win_scan:
    cmp r9d, 64
    jae .resource_false
    bt qword [process_affinity_mask], r9
    jnc .limit_cpu_win_next
    cmp r8, [resource_count]
    jae .limit_cpu_win_next
    bts qword [new_affinity_mask], r9
    inc r8
    cmp r8, [resource_count]
    jae .limit_cpu_win_apply
.limit_cpu_win_next:
    inc r9d
    jmp .limit_cpu_win_scan
.limit_cpu_win_apply:
    call GetCurrentProcess
    mov rcx, rax
    mov rdx, [new_affinity_mask]
    call SetProcessAffinityMask
    test eax, eax
    setne al
    movzx eax, al
    jmp .return
%else
    xor edi, edi
    mov esi, 128
    lea rdx, [rel affinity_current]
    call sched_getaffinity
    test eax, eax
    js .resource_false
    lea rdi, [rel affinity_target]
    xor eax, eax
    mov ecx, 16
    cld
    rep stosq
    xor r8d, r8d
    xor r9d, r9d
.limit_cpu_linux_scan:
    cmp r8d, 1024
    jae .resource_false
    mov eax, r8d
    mov edx, eax
    and edx, 63
    shr eax, 6
    lea rsi, [rel affinity_current]
    bt qword [rsi+rax*8], rdx
    jnc .limit_cpu_linux_next
    cmp r9, [resource_count]
    jae .limit_cpu_linux_next
    lea rdi, [rel affinity_target]
    bts qword [rdi+rax*8], rdx
    inc r9
    cmp r9, [resource_count]
    jae .limit_cpu_linux_apply
.limit_cpu_linux_next:
    inc r8d
    jmp .limit_cpu_linux_scan
.limit_cpu_linux_apply:
    xor edi, edi
    mov esi, 128
    lea rdx, [rel affinity_target]
    call sched_setaffinity
    test eax, eax
    sete al
    movzx eax, al
    jmp .return
%endif
.do_limit_memory_mb:
    REQUIRE_ARITY 1
    mov rax, [rbp-72]
    cmp rax, 32
    jl error_range
    cmp rax, 1048576
    ja error_range
    shl rax, 20
%ifdef WIN_BUILD
    lea rdi, [rel resource_limit_buffer]
    xor eax, eax
    mov ecx, 18
    cld
    rep stosq
    mov dword [resource_limit_buffer+16], 0x100
    mov rax, [rbp-72]
    shl rax, 20
    mov [resource_limit_buffer+112], rax
    cmp qword [memory_job_handle], 0
    jne .memory_job_ready
    xor ecx, ecx
    xor edx, edx
    call CreateJobObjectW
    test rax, rax
    jz .resource_false
    mov [memory_job_handle], rax
.memory_job_ready:
    mov rcx, [memory_job_handle]
    mov edx, 9
    lea r8, [rel resource_limit_buffer]
    mov r9d, 144
    call SetInformationJobObject
    test eax, eax
    jz .resource_false
    cmp qword [memory_job_assigned], 0
    jne .memory_limit_success
    call GetCurrentProcess
    mov rdx, rax
    mov rcx, [memory_job_handle]
    call AssignProcessToJobObject
    test eax, eax
    jz .resource_false
    mov qword [memory_job_assigned], 1
.memory_limit_success:
    mov eax, 1
    jmp .return
%else
    mov [rlimit_buffer], rax
    mov [rlimit_buffer+8], rax
    mov edi, 9
    lea rsi, [rel rlimit_buffer]
    call setrlimit
    test eax, eax
    sete al
    movzx eax, al
    jmp .return
%endif
.resource_false:
    xor eax, eax
    jmp .return
.hardware_zero:
    xor eax, eax
    jmp .return
.false_result:
    xor eax, eax
    jmp .return
.return:
    EPILOGUE

; Parse one quoted string or whitespace-delimited token into spawn_arg_dest.
; Returns its byte length in EAX and advances cursor. No escape processing.
parse_spawn_arg:
    push rsi
    push rdi
    call skip_spaces
    mov rsi, [cursor]
    mov rdi, [spawn_arg_dest]
    xor ecx, ecx
    xor r10d, r10d
    mov al, [rsi]
    cmp al, '"'
    je .quoted
    cmp al, 39
    je .quoted
.unquoted_loop:
    mov al, [rsi]
    test al, al
    jz .done
    cmp al, 10
    je .done
    cmp al, 13
    je .done
    cmp al, ' '
    je .done
    cmp al, 9
    je .done
    jmp .copy_byte
.quoted:
    mov r10b, al
    inc rsi
.quoted_loop:
    mov al, [rsi]
    test al, al
    jz error_syntax
    cmp al, 10
    je error_syntax
    cmp al, r10b
    je .quote_end
    cmp qword [spawn_parse_escapes], 0
    je .copy_byte
    cmp al, 0x5c
    jne .copy_byte
    inc rsi
    mov al, [rsi]
    cmp al, 'n'
    je .escape_newline
    cmp al, 'r'
    je .escape_return
    cmp al, 't'
    je .escape_tab
    cmp al, 0x5c
    je .escape_literal
    cmp al, '"'
    je .escape_literal
    cmp al, 39
    je .escape_literal
    jmp error_syntax
.escape_newline:
    mov al, 10
    jmp .escape_store
.escape_return:
    mov al, 13
    jmp .escape_store
.escape_tab:
    mov al, 9
    jmp .escape_store
.escape_literal:
.escape_store:
    mov r11, [spawn_arg_capacity]
    dec r11
    cmp rcx, r11
    jae error_syntax
    mov [rdi+rcx], al
    inc rcx
    inc rsi
    jmp .quoted_loop
.copy_byte:
    mov r11, [spawn_arg_capacity]
    dec r11
    cmp rcx, r11
    jae error_syntax
    mov [rdi+rcx], al
    inc rcx
    inc rsi
    cmp r10b, 0
    jne .quoted_loop
    jmp .unquoted_loop
.quote_end:
    inc rsi
.done:
    mov byte [rdi+rcx], 0
    mov [spawn_arg_length], rcx
    mov [cursor], rsi
    mov eax, ecx
    pop rdi
    pop rsi
    ret

; Expand {cell_name} placeholders in the most recently parsed file argument.
; The source and destination are separate buffers, so overlap is impossible.
expand_template_arg:
    PROLOGUE
    mov rax, [spawn_arg_dest]
    mov [template_input_ptr], rax
    mov rax, [spawn_arg_length]
    mov [template_input_length], rax
    mov qword [template_input_index], 0
    mov qword [template_output_length], 0
.scan:
    mov rax, [template_input_index]
    cmp rax, [template_input_length]
    jae .finish
    mov rdx, [template_input_ptr]
    mov al, [rdx+rax]
    cmp al, '{'
    je .open_brace
    cmp al, '}'
    je .close_brace
.copy_character:
    mov rdx, [template_output_length]
    cmp rdx, 4095
    jae error_syntax
    lea rdi, [rel template_output_buffer]
    mov [rdi+rdx], al
    inc qword [template_output_length]
    inc qword [template_input_index]
    jmp .scan
.open_brace:
    mov rax, [template_input_index]
    inc rax
    cmp rax, [template_input_length]
    jae .placeholder
    mov rdx, [template_input_ptr]
    cmp byte [rdx+rax], '{'
    jne .placeholder
    mov al, '{'
    jmp .copy_two_character_escape
.close_brace:
    mov rax, [template_input_index]
    inc rax
    cmp rax, [template_input_length]
    jae .copy_character
    mov rdx, [template_input_ptr]
    cmp byte [rdx+rax], '}'
    jne .copy_character
    mov al, '}'
.copy_two_character_escape:
    mov rdx, [template_output_length]
    cmp rdx, 4095
    jae error_syntax
    lea rdi, [rel template_output_buffer]
    mov [rdi+rdx], al
    inc qword [template_output_length]
    add qword [template_input_index], 2
    jmp .scan
.placeholder:
    inc qword [template_input_index]
    mov qword [template_variable_length], 0
    lea rdi, [rel id_buffer]
    xor eax, eax
    mov ecx, 32
    cld
    rep stosb
.read_variable:
    mov rax, [template_input_index]
    cmp rax, [template_input_length]
    jae error_syntax
    mov rdx, [template_input_ptr]
    mov al, [rdx+rax]
    cmp al, '}'
    je .variable_end
    mov rcx, [template_variable_length]
    test rcx, rcx
    jnz .later_character
    cmp al, '_'
    je .valid_character
    cmp al, 'A'
    jb error_syntax
    cmp al, 'Z'
    jbe .valid_character
    cmp al, 'a'
    jb error_syntax
    cmp al, 'z'
    ja error_syntax
    jmp .valid_character
.later_character:
    cmp al, '_'
    je .valid_character
    cmp al, 'A'
    jb .maybe_digit
    cmp al, 'Z'
    jbe .valid_character
    cmp al, 'a'
    jb .maybe_digit
    cmp al, 'z'
    jbe .valid_character
.maybe_digit:
    cmp al, '0'
    jb error_syntax
    cmp al, '9'
    ja error_syntax
.valid_character:
    cmp rcx, 31
    jae error_syntax
    lea rdi, [rel id_buffer]
    mov [rdi+rcx], al
    inc qword [template_variable_length]
    inc qword [template_input_index]
    jmp .read_variable
.variable_end:
    cmp qword [template_variable_length], 0
    je error_syntax
    lea rdi, [rel id_buffer]
    mov rcx, [template_variable_length]
    mov byte [rdi+rcx], 0
    inc qword [template_input_index]
    call lookup_variable
    cmp rax, -1
    je error_unknown
    lea rdx, [rel var_values]
    mov rax, [rdx+rax*8]
    mov [template_number_value], rax
%ifdef WIN_BUILD
    lea rcx, [rel template_number_buffer]
    lea rdx, [rel fmt_template_integer]
    mov r8, [template_number_value]
%else
    lea rdi, [rel template_number_buffer]
    lea rsi, [rel fmt_template_integer]
    mov rdx, [template_number_value]
%endif
    xor eax, eax
    mov [template_saved_rsp], rsp
    and rsp, -16
%ifdef WIN_BUILD
    sub rsp, 32
%endif
    call sprintf
    mov rsp, [template_saved_rsp]
    test eax, eax
    jle error_syntax
    mov [template_number_length], rax
    mov rdx, [template_output_length]
    add rdx, rax
    cmp rdx, 4095
    ja error_syntax
    lea rsi, [rel template_number_buffer]
    lea rdi, [rel template_output_buffer]
    add rdi, [template_output_length]
    mov rcx, [template_number_length]
    rep movsb
    mov rax, [template_number_length]
    add [template_output_length], rax
    jmp .scan
.finish:
    mov rax, [template_output_length]
    lea rdi, [rel template_output_buffer]
    mov byte [rdi+rax], 0
    mov rdi, [spawn_arg_dest]
    lea rsi, [rel template_output_buffer]
    lea rcx, [rax+1]
    rep movsb
    mov rax, [template_output_length]
    mov [spawn_arg_length], rax
    EPILOGUE

convert_spawn_path:
%ifdef WIN_BUILD
    PROLOGUE
    sub rsp, 16
    mov ecx, 65001
    xor edx, edx
    lea r8, [rel spawn_parent_buffer]
    mov r9d, -1
    lea rax, [rel spawn_wide_buffer]
    mov [rsp+32], rax
    mov dword [rsp+40], 4096
    call MultiByteToWideChar
    add rsp, 16
    test eax, eax
    setne al
    movzx eax, al
    EPILOGUE
%else
    mov eax, 1
    ret
%endif

eval_file_exists:
    PROLOGUE
    mov rsi, [cursor]
    cmp byte [rsi], '('
    jne error_arity
    inc qword [cursor]
    lea rax, [rel spawn_parent_buffer]
    mov [spawn_arg_dest], rax
    mov qword [spawn_arg_capacity], 4096
    call parse_spawn_arg
    test eax, eax
    jz error_syntax
    call expand_template_arg
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], ')'
    jne error_arity
    inc qword [cursor]
%ifdef WIN_BUILD
    call convert_spawn_path
    test eax, eax
    jz .missing
    lea rcx, [rel spawn_wide_buffer]
    call GetFileAttributesW
    cmp eax, -1
    sete al
    movzx eax, al
    xor eax, 1
%else
    lea rdi, [rel spawn_parent_buffer]
    xor esi, esi
    call access
    test eax, eax
    sete al
    movzx eax, al
%endif
    jmp .return
.missing:
    xor eax, eax
.return:
    EPILOGUE

; eval_term -> parse_atom ((* or /) parse_atom)*
eval_term:
    call parse_atom
    sub rsp, 16
.loop:
    mov [rsp], rax
    call skip_spaces
    mov rdx, [cursor]
    mov r10b, [rdx]
    cmp r10b, '*'
    je .multiply
    cmp r10b, '/'
    je .divide
    cmp r10b, '%'
    je .modulo
    jmp .done
.multiply:
    mov byte [operator], '*'
    inc rdx
    mov [cursor], rdx
    call parse_atom
    mov r11, rax
    mov rax, [rsp]
    imul rax, r11
    jmp .loop
.divide:
    mov byte [operator], '/'
    inc rdx
    mov [cursor], rdx
    call parse_atom
    test rax, rax
    jz error_divzero
    mov r11, rax
    mov rax, [rsp]
    mov r10, 0x8000000000000000
    cmp rax, r10
    jne .divide_safe
    cmp r11, -1
    je error_range
.divide_safe:
    cqo
    idiv r11
    jmp .loop
.modulo:
    inc rdx
    mov [cursor], rdx
    call parse_atom
    test rax, rax
    jz error_divzero
    mov r11, rax
    mov rax, [rsp]
    mov r10, 0x8000000000000000
    cmp rax, r10
    jne .modulo_safe
    cmp r11, -1
    je error_range
.modulo_safe:
    cqo
    idiv r11
    mov rax, rdx
    jmp .loop
.done:
    mov rax, [rsp]
    add rsp, 16
    ret

; eval_expr -> parse_term ((+ or -) parse_term)*
eval_expr:
    call eval_term
    sub rsp, 16
.loop:
    mov [rsp], rax
    call skip_spaces
    mov rdx, [cursor]
    mov r10b, [rdx]
    cmp r10b, '+'
    je .plus
    cmp r10b, '-'
    je .minus
    jmp .done
.plus:
    mov byte [operator], '+'
    inc rdx
    mov [cursor], rdx
    call eval_term
    mov r11, rax
    mov rax, [rsp]
    add rax, r11
    jmp .loop
.minus:
    mov byte [operator], '-'
    inc rdx
    mov [cursor], rdx
    call eval_term
    mov r11, rax
    mov rax, [rsp]
    sub rax, r11
    jmp .loop
.done:
    mov rax, [rsp]
    add rsp, 16
    ret

; process one line of source.
; Create the object described by spawn_kind, spawn_target_buffer and content buffer.
create_spawn_object:
    PROLOGUE
%ifdef WIN_BUILD
    call convert_spawn_path
    test eax, eax
    jz .failed
    cmp qword [spawn_kind], 1
    jne .create_file_win
    lea rcx, [rel spawn_wide_buffer]
    xor edx, edx
    call CreateDirectoryW
    test eax, eax
    setne al
    movzx eax, al
    jmp .return
.create_file_win:
    sub rsp, 32
    lea rcx, [rel spawn_wide_buffer]
    mov edx, 0x40000000
    xor r8d, r8d
    xor r9d, r9d
    mov qword [rsp+32], 1
    mov qword [rsp+40], 0x80
    mov qword [rsp+48], 0
    call CreateFileW
    add rsp, 32
    cmp rax, -1
    je .failed
    mov [file_io_handle], rax
    mov qword [file_io_count], 0
    mov qword [rsp+32], 0
    mov rcx, rax
    lea rdx, [rel spawn_content_buffer]
    mov r8d, [spawn_content_length]
    lea r9, [rel file_io_count]
    call WriteFile
    mov [file_io_success], rax
    mov rcx, [file_io_handle]
    call CloseHandle
    cmp qword [file_io_success], 0
    je .remove_partial_win
    mov rax, [file_io_count]
    cmp rax, [spawn_content_length]
    jne .remove_partial_win
    mov eax, 1
    jmp .return
.remove_partial_win:
    lea rcx, [rel spawn_wide_buffer]
    call DeleteFileW
    jmp .failed
.failed:
    xor eax, eax
%else
    cmp qword [spawn_kind], 1
    jne .create_file_linux
    lea rdi, [rel spawn_target_buffer]
    mov esi, 511
    call mkdir
    test eax, eax
    sete al
    movzx eax, al
    jmp .return
.create_file_linux:
    lea rdi, [rel spawn_target_buffer]
    mov esi, 193
    mov edx, 438
    call open
    cmp eax, -1
    je .failed
    mov [file_io_handle], rax
    mov qword [file_io_count], 0
.write_loop:
    mov rax, [file_io_count]
    cmp rax, [spawn_content_length]
    jae .write_done
    mov rdi, [file_io_handle]
    lea rsi, [rel spawn_content_buffer]
    add rsi, rax
    mov rdx, [spawn_content_length]
    sub rdx, rax
    call write
    test rax, rax
    jle .write_failed
    add [file_io_count], rax
    jmp .write_loop
.write_done:
    mov rdi, [file_io_handle]
    call close
    mov eax, 1
    jmp .return
.write_failed:
    mov rdi, [file_io_handle]
    call close
    lea rdi, [rel spawn_target_buffer]
    call unlink
    xor eax, eax
.failed:
    xor eax, eax
%endif
.return:
    EPILOGUE

execute_spawn:
    PROLOGUE
    add qword [cursor], 5
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], 'd'
    jne .try_file
    cmp byte [rsi+1], 'i'
    jne error_syntax
    cmp byte [rsi+2], 'r'
    jne error_syntax
    cmp byte [rsi+3], ' '
    je .spawn_dir
    cmp byte [rsi+3], 9
    jne error_syntax
.spawn_dir:
    mov qword [spawn_kind], 1
    add qword [cursor], 3
    jmp .read_name
.try_file:
    cmp byte [rsi], 'f'
    jne error_syntax
    cmp byte [rsi+1], 'i'
    jne error_syntax
    cmp byte [rsi+2], 'l'
    jne error_syntax
    cmp byte [rsi+3], 'e'
    jne error_syntax
    cmp byte [rsi+4], ' '
    je .spawn_file
    cmp byte [rsi+4], 9
    jne error_syntax
.spawn_file:
    mov qword [spawn_kind], 2
    add qword [cursor], 4
.read_name:
    lea rax, [rel spawn_name_buffer]
    mov [spawn_arg_dest], rax
    mov qword [spawn_arg_capacity], 512
    call parse_spawn_arg
    test eax, eax
    jz error_syntax
    call expand_template_arg
    ; A name is a single path component; reject traversal and separators.
    lea rsi, [rel spawn_name_buffer]
    cmp byte [rsi], '.'
    jne .validate_name
    cmp byte [rsi+1], 0
    je error_syntax
    cmp byte [rsi+1], '.'
    jne .validate_name
    cmp byte [rsi+2], 0
    je error_syntax
.validate_name:
    lea rsi, [rel spawn_name_buffer]
.name_loop:
    mov al, [rsi]
    test al, al
    jz .read_parent
    cmp al, '/'
    je error_syntax
    cmp al, 0x5c
    je error_syntax
    inc rsi
    jmp .name_loop
.read_parent:
    lea rax, [rel spawn_parent_buffer]
    mov [spawn_arg_dest], rax
    mov qword [spawn_arg_capacity], 4096
    call parse_spawn_arg
    test eax, eax
    jz error_syntax
    call expand_template_arg
    mov qword [spawn_content_length], 0
    cmp qword [spawn_kind], 1
    je .check_line_end
    lea rax, [rel spawn_content_buffer]
    mov [spawn_arg_dest], rax
    mov qword [spawn_arg_capacity], 4096
    mov qword [spawn_parse_escapes], 1
    call parse_spawn_arg
    mov qword [spawn_parse_escapes], 0
    call expand_template_arg
    mov [spawn_content_length], rax
.check_line_end:
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], 0
    je .build_target
    cmp byte [rsi], 10
    je .build_target
    cmp byte [rsi], 13
    jne error_syntax
.build_target:
    lea rsi, [rel spawn_parent_buffer]
    lea rdi, [rel spawn_target_buffer]
    xor ecx, ecx
.copy_parent:
    mov al, [rsi+rcx]
    test al, al
    jz .parent_copied
    mov [rdi+rcx], al
    inc rcx
    jmp .copy_parent
.parent_copied:
    test rcx, rcx
    jz error_syntax
    mov al, [rdi+rcx-1]
%ifdef WIN_BUILD
    cmp al, '/'
    je .separator_ready
    cmp al, 0x5c
    je .separator_ready
    mov byte [rdi+rcx], 0x5c
%else
    cmp al, '/'
    je .separator_ready
    mov byte [rdi+rcx], '/'
%endif
    inc rcx
.separator_ready:
    lea rsi, [rel spawn_name_buffer]
.copy_name:
    mov al, [rsi]
    test al, al
    jz .target_done
    cmp rcx, 4095
    jae error_syntax
    mov [rdi+rcx], al
    inc rsi
    inc rcx
    jmp .copy_name
.target_done:
    mov byte [rdi+rcx], 0
    ; convert_spawn_path consumes a NUL-terminated path from spawn_parent_buffer.
    lea rsi, [rel spawn_target_buffer]
    lea rdi, [rel spawn_parent_buffer]
    xor ecx, ecx
.copy_target_back:
    mov al, [rsi+rcx]
    mov [rdi+rcx], al
    inc rcx
    test al, al
    jnz .copy_target_back
    call create_spawn_object
    test eax, eax
    jz .spawn_failed
    lea rdi, [rel fmt_spawn_ok]
    lea rsi, [rel spawn_target_buffer]
%ifdef WIN_BUILD
    mov rcx, rdi
    mov rdx, rsi
%else
    mov rdi, rdi
%endif
    xor eax, eax
    call printf
    jmp .return
.spawn_failed:
    lea rdi, [rel fmt_spawn_fail]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
.return:
    EPILOGUE

execute_append:
    PROLOGUE
    mov rsi, [cursor]
    cmp byte [rsi], 'a'
    jne error_syntax
    cmp byte [rsi+1], 'p'
    jne error_syntax
    cmp byte [rsi+2], 'p'
    jne error_syntax
    cmp byte [rsi+3], 'e'
    jne error_syntax
    cmp byte [rsi+4], 'n'
    jne error_syntax
    cmp byte [rsi+5], 'd'
    jne error_syntax
    add qword [cursor], 6
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], 'f'
    jne error_syntax
    cmp byte [rsi+1], 'i'
    jne error_syntax
    cmp byte [rsi+2], 'l'
    jne error_syntax
    cmp byte [rsi+3], 'e'
    jne error_syntax
    cmp byte [rsi+4], ' '
    je .append_file
    cmp byte [rsi+4], 9
    jne error_syntax
.append_file:
    add qword [cursor], 4
    lea rax, [rel spawn_parent_buffer]
    mov [spawn_arg_dest], rax
    mov qword [spawn_arg_capacity], 4096
    call parse_spawn_arg
    test eax, eax
    jz error_syntax
    call expand_template_arg
    lea rax, [rel spawn_content_buffer]
    mov [spawn_arg_dest], rax
    mov qword [spawn_arg_capacity], 4096
    mov qword [spawn_parse_escapes], 1
    call parse_spawn_arg
    mov qword [spawn_parse_escapes], 0
    call expand_template_arg
    mov [spawn_content_length], rax
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], 0
    je .open_append
    cmp byte [rsi], 10
    je .open_append
    cmp byte [rsi], 13
    jne error_syntax
.open_append:
    call convert_spawn_path
    test eax, eax
    jz .append_failed
%ifdef WIN_BUILD
    lea rcx, [rel spawn_wide_buffer]
    lea rdx, [rel mode_ab_w]
    call _wfopen
%else
    lea rdi, [rel spawn_parent_buffer]
    lea rsi, [rel mode_ab]
    call fopen
%endif
    test rax, rax
    jz .append_failed
    mov [file_io_handle], rax
%ifdef WIN_BUILD
    lea rcx, [rel spawn_content_buffer]
    mov edx, 1
    mov r8d, [spawn_content_length]
    mov r9, [file_io_handle]
%else
    lea rdi, [rel spawn_content_buffer]
    mov esi, 1
    mov edx, [spawn_content_length]
    mov rcx, [file_io_handle]
%endif
    call fwrite
    mov [file_io_count], rax
    mov rdi, [file_io_handle]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    call fclose
    mov rax, [file_io_count]
    cmp rax, [spawn_content_length]
    jne .append_failed
    lea rdi, [rel fmt_file_io_ok]
    lea rsi, [rel spawn_parent_buffer]
%ifdef WIN_BUILD
    mov rcx, rdi
    mov rdx, rsi
%else
    mov rdi, rdi
%endif
    xor eax, eax
    call printf
    jmp .return
.append_failed:
    lea rdi, [rel fmt_file_io_fail]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
.return:
    EPILOGUE

execute_read_file:
    PROLOGUE
    mov rsi, [cursor]
    cmp byte [rsi], 'r'
    jne error_syntax
    cmp byte [rsi+1], 'e'
    jne error_syntax
    cmp byte [rsi+2], 'a'
    jne error_syntax
    cmp byte [rsi+3], 'd'
    jne error_syntax
    add qword [cursor], 4
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], 'f'
    jne error_syntax
    cmp byte [rsi+1], 'i'
    jne error_syntax
    cmp byte [rsi+2], 'l'
    jne error_syntax
    cmp byte [rsi+3], 'e'
    je .read_file_keyword
    jmp error_syntax
.read_file_keyword:
    cmp byte [rsi+4], ' '
    je .read_file_path
    cmp byte [rsi+4], 9
    jne error_syntax
.read_file_path:
    add qword [cursor], 4
    lea rax, [rel spawn_parent_buffer]
    mov [spawn_arg_dest], rax
    mov qword [spawn_arg_capacity], 4096
    call parse_spawn_arg
    test eax, eax
    jz error_syntax
    call expand_template_arg
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], 0
    je .open_read
    cmp byte [rsi], 10
    je .open_read
    cmp byte [rsi], 13
    jne error_syntax
.open_read:
    call convert_spawn_path
    test eax, eax
    jz .read_failed
%ifdef WIN_BUILD
    lea rcx, [rel spawn_wide_buffer]
    lea rdx, [rel mode_rb_w]
    call _wfopen
%else
    lea rdi, [rel spawn_parent_buffer]
    lea rsi, [rel mode_rb]
    call fopen
%endif
    test rax, rax
    jz .read_failed
    mov [file_io_handle], rax
.read_loop:
%ifdef WIN_BUILD
    lea rcx, [rel file_io_buffer]
    mov edx, 4096
    mov r8, [file_io_handle]
%else
    lea rdi, [rel file_io_buffer]
    mov esi, 4096
    mov rdx, [file_io_handle]
%endif
    call fgets
    test rax, rax
    jz .read_done
    lea rdi, [rel fmt_raw_string]
    lea rsi, [rel file_io_buffer]
%ifdef WIN_BUILD
    mov rcx, rdi
    mov rdx, rsi
%else
    mov rdi, rdi
%endif
    xor eax, eax
    call printf
    jmp .read_loop
.read_done:
    mov rdi, [file_io_handle]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    call fclose
%ifdef WIN_BUILD
    xor ecx, ecx
%else
    xor edi, edi
%endif
    call fflush
    jmp .return
.read_failed:
    lea rdi, [rel fmt_file_io_fail]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
.return:
    EPILOGUE

execute_remove_file:
    PROLOGUE
    mov rsi, [cursor]
    cmp byte [rsi], 'r'
    jne error_syntax
    cmp byte [rsi+1], 'e'
    jne error_syntax
    cmp byte [rsi+2], 'm'
    jne error_syntax
    cmp byte [rsi+3], 'o'
    jne error_syntax
    cmp byte [rsi+4], 'v'
    jne error_syntax
    cmp byte [rsi+5], 'e'
    jne error_syntax
    add qword [cursor], 6
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], 'f'
    jne error_syntax
    cmp byte [rsi+1], 'i'
    jne error_syntax
    cmp byte [rsi+2], 'l'
    jne error_syntax
    cmp byte [rsi+3], 'e'
    jne error_syntax
    cmp byte [rsi+4], ' '
    je .remove_path
    cmp byte [rsi+4], 9
    jne error_syntax
.remove_path:
    add qword [cursor], 4
    lea rax, [rel spawn_parent_buffer]
    mov [spawn_arg_dest], rax
    mov qword [spawn_arg_capacity], 4096
    mov qword [spawn_parse_escapes], 0
    call parse_spawn_arg
    test eax, eax
    jz error_syntax
    call expand_template_arg
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], 0
    je .remove_now
    cmp byte [rsi], 10
    je .remove_now
    cmp byte [rsi], 13
    jne error_syntax
.remove_now:
    call convert_spawn_path
    test eax, eax
    jz .remove_failed
%ifdef WIN_BUILD
    lea rcx, [rel spawn_wide_buffer]
    call DeleteFileW
%else
    lea rdi, [rel spawn_parent_buffer]
    call unlink
    test eax, eax
    jnz .remove_failed
%endif
%ifdef WIN_BUILD
    test eax, eax
    jz .remove_failed
%endif
    lea rdi, [rel fmt_file_remove_ok]
    lea rsi, [rel spawn_parent_buffer]
%ifdef WIN_BUILD
    mov rcx, rdi
    mov rdx, rsi
%else
    mov rdi, rdi
%endif
    xor eax, eax
    call printf
    jmp .return
.remove_failed:
    lea rdi, [rel fmt_file_io_fail]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
.return:
    EPILOGUE

; `dialog "title" "message"` opens an information dialog.
; `dialog result_cell "title" "message"` stores Yes=1 / No=0 in an existing cell.
execute_dialog:
    PROLOGUE
    mov qword [dialog_result_slot], -1
    mov qword [dialog_answer], 0
    add qword [cursor], 6
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], '"'
    je .read_title
    cmp byte [rsi], 39
    je .read_title
    call parse_identifier
    test eax, eax
    jz error_syntax
    call lookup_variable
    cmp rax, -1
    je error_unknown
    mov [dialog_result_slot], rax
.read_title:
    lea rax, [rel dialog_title_buffer]
    mov [spawn_arg_dest], rax
    mov qword [spawn_arg_capacity], 512
    mov qword [spawn_parse_escapes], 0
    call parse_spawn_arg
    call expand_template_arg
    lea rax, [rel dialog_message_buffer]
    mov [spawn_arg_dest], rax
    mov qword [spawn_arg_capacity], 4096
    mov qword [spawn_parse_escapes], 0
    call parse_spawn_arg
    call expand_template_arg
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], 0
    je .arguments_ready
    cmp byte [rsi], 10
    je .arguments_ready
    cmp byte [rsi], 13
    jne error_syntax
.arguments_ready:
%ifdef WIN_BUILD
    cmp qword [dialog_host_flag], 1
    jne .host_unavailable
    call dialog_windows_show
    jmp .response_ready
%else
    lea rdi, [rel dialog_host_env]
    call getenv
    test rax, rax
    jz .host_unavailable
    cmp byte [rax], '1'
    jne .host_unavailable
    ; Wire format: RS HELIX_DIALOG TAB (I|Q) TAB title_hex TAB message_hex LF.
    lea rdi, [rel dialog_packet_buffer]
    lea rsi, [rel dialog_protocol_prefix]
    mov ecx, 14
    cld
    rep movsb
    cmp qword [dialog_result_slot], -1
    je .info_packet
    lea rsi, [rel dialog_question_code]
    jmp .append_code
.info_packet:
    lea rsi, [rel dialog_info_code]
.append_code:
    mov ecx, 2
    rep movsb
    mov [dialog_packet_cursor], rdi
    lea rax, [rel dialog_title_buffer]
    mov [dialog_hex_source], rax
    call dialog_encode_hex
    mov rdi, [dialog_packet_cursor]
    mov byte [rdi], 9
    inc rdi
    mov [dialog_packet_cursor], rdi
    lea rax, [rel dialog_message_buffer]
    mov [dialog_hex_source], rax
    call dialog_encode_hex
    mov rdi, [dialog_packet_cursor]
    mov byte [rdi], 10
    inc rdi
    mov byte [rdi], 0
    lea rdi, [rel fmt_raw_string]
    lea rsi, [rel dialog_packet_buffer]
%ifdef WIN_BUILD
    mov rcx, rdi
    mov rdx, rsi
%endif
    xor eax, eax
    call printf
    xor edi, edi
%ifdef WIN_BUILD
    xor ecx, ecx
%endif
    call fflush
    mov qword [dialog_answer], 0
    mov qword [dialog_read_first], 1
.read_host_response:
    call getchar
    cmp eax, -1
    je .response_ready
    cmp eax, 10
    je .response_ready
    cmp qword [dialog_read_first], 1
    jne .read_host_response
    mov qword [dialog_read_first], 0
    cmp eax, '1'
    jne .read_host_response
    mov qword [dialog_answer], 1
    jmp .read_host_response
%endif
.host_unavailable:
    lea rdi, [rel msg_dialog_unavailable]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
.response_ready:
    cmp qword [dialog_result_slot], -1
    je .return
    mov rax, [dialog_result_slot]
    lea rdi, [rel var_values]
    mov rdx, [dialog_answer]
    mov [rdi+rax*8], rdx
.return:
    EPILOGUE

%ifdef WIN_BUILD
dialog_windows_show:
    PROLOGUE
    mov ecx, 65001
    xor edx, edx
    lea r8, [rel dialog_message_buffer]
    mov r9d, -1
    sub rsp, 48
    lea rax, [rel dialog_message_wide]
    mov [rsp+32], rax
    mov dword [rsp+40], 4096
    call MultiByteToWideChar
    add rsp, 48
    mov ecx, 65001
    xor edx, edx
    lea r8, [rel dialog_title_buffer]
    mov r9d, -1
    sub rsp, 48
    lea rax, [rel dialog_title_wide]
    mov [rsp+32], rax
    mov dword [rsp+40], 512
    call MultiByteToWideChar
    add rsp, 48
    xor ecx, ecx
    lea rdx, [rel dialog_message_wide]
    lea r8, [rel dialog_title_wide]
    cmp qword [dialog_result_slot], -1
    je .information
    mov r9d, 0x24
    call MessageBoxW
    cmp eax, 6
    sete al
    movzx eax, al
    mov [dialog_answer], rax
    jmp .done
.information:
    mov r9d, 0x40
    call MessageBoxW
.done:
    EPILOGUE
%endif

dialog_encode_hex:
    PROLOGUE
.loop:
    mov rax, [dialog_hex_source]
    movzx ecx, byte [rax]
    test ecx, ecx
    jz .done
    mov rdx, [dialog_packet_cursor]
    mov eax, ecx
    shr eax, 4
    lea r8, [rel dialog_hex_digits]
    mov al, [r8+rax]
    mov [rdx], al
    inc rdx
    mov eax, ecx
    and eax, 15
    mov al, [r8+rax]
    mov [rdx], al
    inc rdx
    mov [dialog_packet_cursor], rdx
    inc qword [dialog_hex_source]
    jmp .loop
.done:
    EPILOGUE

execute_bridge:
    PROLOGUE
    add qword [cursor], 6
    lea rax, [rel spawn_name_buffer]
    mov [spawn_arg_dest], rax
    mov qword [spawn_arg_capacity], 512
    call parse_spawn_arg
    cmp eax, 5
    je .maybe_helix
    cmp eax, 4
    je .maybe_html
    cmp eax, 3
    je .maybe_css_js_cpp
    cmp eax, 2
    je .maybe_js
    cmp eax, 1
    je .maybe_c
    jmp error_syntax
.maybe_helix:
    lea rsi, [rel spawn_name_buffer]
    lea rdi, [rel bridge_helix]
    mov ecx, 6
    cld
    repe cmpsb
    jne error_syntax
    mov qword [bridge_mode], 6
    jmp .read_path
.maybe_html:
    lea rsi, [rel spawn_name_buffer]
    lea rdi, [rel bridge_html]
    mov ecx, 5
    cld
    repe cmpsb
    je .is_html
    jmp error_syntax
.is_html:
    mov qword [bridge_mode], 1
    jmp .read_path
.maybe_css_js_cpp:
    lea rsi, [rel spawn_name_buffer]
    lea rdi, [rel bridge_css]
    mov ecx, 4
    cld
    repe cmpsb
    je .is_css
    lea rsi, [rel spawn_name_buffer]
    lea rdi, [rel bridge_js]
    mov ecx, 3
    cld
    repe cmpsb
    je .is_js
    lea rsi, [rel spawn_name_buffer]
    lea rdi, [rel bridge_cpp]
    mov ecx, 4
    cld
    repe cmpsb
    je .is_cpp
    jmp error_syntax
.is_css:
    mov qword [bridge_mode], 2
    jmp .read_path
.maybe_js:
    lea rsi, [rel spawn_name_buffer]
    lea rdi, [rel bridge_js]
    mov ecx, 3
    cld
    repe cmpsb
    jne error_syntax
    mov qword [bridge_mode], 3
    jmp .read_path
.is_js:
    mov qword [bridge_mode], 3
    jmp .read_path
.is_cpp:
    mov qword [bridge_mode], 5
    jmp .read_path
.maybe_c:
    lea rsi, [rel spawn_name_buffer]
    lea rdi, [rel bridge_c]
    mov ecx, 2
    cld
    repe cmpsb
    jne error_syntax
    mov qword [bridge_mode], 4
.read_path:
    lea rax, [rel spawn_parent_buffer]
    mov [spawn_arg_dest], rax
    mov qword [spawn_arg_capacity], 4096
    mov qword [spawn_parse_escapes], 0
    call parse_spawn_arg
    test eax, eax
    jz error_syntax
    call expand_template_arg
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], 0
    je .path_ready
    cmp byte [rsi], 10
    je .path_ready
    cmp byte [rsi], 13
    jne error_syntax
.path_ready:
%ifdef WIN_BUILD
    call convert_spawn_path
    test eax, eax
    jz .source_missing
    call execute_bridge_windows
    jmp .return
%else
    lea rdi, [rel spawn_parent_buffer]
    xor esi, esi
    call access
    test eax, eax
    jnz .source_missing
    cmp qword [bridge_mode], 1
    je .launch_open
    cmp qword [bridge_mode], 2
    je .launch_open
    cmp qword [bridge_mode], 3
    je .launch_node
    cmp qword [bridge_mode], 6
    je .launch_helix
    call prepare_bridge_temp
    test eax, eax
    jz .bridge_failed
    cmp qword [bridge_mode], 4
    je .launch_cc_compile
    jmp .launch_cxx_compile
.launch_open:
    lea rax, [rel bridge_tool_xdg]
    mov [bridge_argv], rax
    lea rax, [rel spawn_parent_buffer]
    mov [bridge_argv+8], rax
    mov qword [bridge_argv+16], 0
    call run_bridge_process
    jmp .check_bridge_status
.launch_node:
    lea rax, [rel bridge_tool_node]
    mov [bridge_argv], rax
    lea rax, [rel spawn_parent_buffer]
    mov [bridge_argv+8], rax
    mov qword [bridge_argv+16], 0
    call run_bridge_process
    jmp .check_bridge_status
.launch_helix:
    mov rax, [argv_value]
    mov rax, [rax]
    mov [bridge_argv], rax
    lea rax, [rel spawn_parent_buffer]
    mov [bridge_argv+8], rax
    mov qword [bridge_argv+16], 0
    call run_bridge_process
    jmp .check_bridge_status
.launch_cc_compile:
    lea rax, [rel bridge_tool_cc]
    jmp .compile
.launch_cxx_compile:
    lea rax, [rel bridge_tool_cxx]
.compile:
    mov [bridge_argv], rax
    lea rax, [rel spawn_parent_buffer]
    mov [bridge_argv+8], rax
    lea rax, [rel bridge_option_output]
    mov [bridge_argv+16], rax
    lea rax, [rel bridge_temp_path]
    mov [bridge_argv+24], rax
    mov qword [bridge_argv+32], 0
    call run_bridge_process
    test eax, eax
    jnz .compiler_failed
    lea rax, [rel bridge_temp_path]
    mov [bridge_argv], rax
    mov qword [bridge_argv+8], 0
    call run_bridge_process
    mov [bridge_status], eax
    lea rdi, [rel bridge_temp_path]
    call unlink
    mov eax, [bridge_status]
    jmp .check_bridge_status
.compiler_failed:
    mov [bridge_status], eax
    lea rdi, [rel bridge_temp_path]
    call unlink
    mov eax, [bridge_status]
.check_bridge_status:
    cmp eax, 0
    je .return
    cmp eax, 32512
    je .bridge_missing
    jmp .bridge_failed
%endif
.source_missing:
    lea rdi, [rel msg_bridge_source]
    jmp .print_error
.bridge_missing:
    lea rdi, [rel msg_bridge_missing]
    jmp .print_error
.bridge_failed:
    lea rdi, [rel msg_bridge_failed]
.print_error:
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
.return:
    EPILOGUE

%ifndef WIN_BUILD
prepare_bridge_temp:
    PROLOGUE
    lea rdi, [rel bridge_temp_path]
    lea rsi, [rel bridge_temp_template]
    call strcpy
    lea rdi, [rel bridge_temp_path]
    call mkstemp
    cmp eax, -1
    je .failed
    mov edi, eax
    call close
    mov eax, 1
    jmp .return
.failed:
    xor eax, eax
.return:
    EPILOGUE

run_bridge_process:
    PROLOGUE
    call fork
    test eax, eax
    jz .child
    cmp eax, -1
    je .failed
    mov [bridge_pid], rax
    mov rdi, rax
    lea rsi, [rel bridge_status]
    xor edx, edx
    call waitpid
    cmp eax, -1
    je .failed
    mov eax, [bridge_status]
    jmp .return
.child:
    lea rdi, [rel bridge_argv]
    mov rsi, rdi
    mov rdi, [rsi]
    call execvp
    mov edi, 127
    call _exit
.failed:
    mov eax, -1
.return:
    EPILOGUE
%endif

%ifdef WIN_BUILD
execute_bridge_windows:
    PROLOGUE
    lea rcx, [rel spawn_wide_buffer]
    call GetFileAttributesW
    cmp eax, -1
    je .source_missing
    cmp qword [bridge_mode], 1
    je .open_association
    cmp qword [bridge_mode], 2
    je .open_association
    cmp qword [bridge_mode], 3
    je .run_node
    cmp qword [bridge_mode], 6
    je .run_helix
    cmp qword [bridge_mode], 4
    je .compile_c
    lea rax, [rel bridge_tool_cxx_w]
    jmp .compile
.compile_c:
    lea rax, [rel bridge_tool_cc_w]
.compile:
    mov [bridge_tool_pointer], rax
    mov qword [bridge_command_kind], 2
    call prepare_bridge_temp_windows
    test eax, eax
    jz .bridge_failed
    call execute_bridge_windows_process
    test eax, eax
    jz .set_temp_program_mode
    mov [bridge_exit_code], eax
    lea rcx, [rel bridge_temp_path_w]
    call DeleteFileW
    mov eax, [bridge_exit_code]
    cmp eax, -1
    je .bridge_missing
    jmp .bridge_failed
.set_temp_program_mode:
    mov qword [bridge_command_kind], 3
.run_temp_program:
    call execute_bridge_windows_process
    mov [bridge_exit_code], eax
    lea rcx, [rel bridge_temp_path_w]
    call DeleteFileW
    mov eax, [bridge_exit_code]
    cmp eax, 0
    je .return
    cmp eax, -1
    je .bridge_missing
    jmp .bridge_failed
.run_node:
    lea rax, [rel bridge_tool_node_w]
    mov [bridge_tool_pointer], rax
    mov qword [bridge_command_kind], 1
    call execute_bridge_windows_process
    cmp eax, 0
    je .return
    cmp eax, -1
    je .bridge_missing
    jmp .bridge_failed
.run_helix:
    mov rax, [argv_value]
    mov rax, [rax]
    mov [bridge_tool_pointer], rax
    mov qword [bridge_command_kind], 4
    call execute_bridge_windows_process
    cmp eax, 0
    je .return
    cmp eax, -1
    je .bridge_missing
    jmp .bridge_failed
.open_association:
    xor ecx, ecx
    lea rdx, [rel bridge_shell_open_w]
    lea r8, [rel spawn_wide_buffer]
    xor r9d, r9d
    sub rsp, 16
    mov qword [rsp+32], 0
    mov qword [rsp+40], 1
    call ShellExecuteW
    add rsp, 16
    cmp rax, 32
    jbe .bridge_missing
    jmp .return
.source_missing:
    lea rdi, [rel msg_bridge_source]
    jmp .print_message
.bridge_missing:
    lea rdi, [rel msg_bridge_missing]
    jmp .print_message
.bridge_failed:
    lea rdi, [rel msg_bridge_failed]
.print_message:
    mov rcx, rdi
    xor eax, eax
    call printf
.return:
    EPILOGUE

prepare_bridge_temp_windows:
    PROLOGUE
    mov ecx, 1024
    lea rdx, [rel bridge_temp_directory_w]
    call GetTempPathW
    test eax, eax
    jz .failed
    cmp eax, 1024
    jae .failed
    lea rcx, [rel bridge_temp_directory_w]
    lea rdx, [rel bridge_temp_prefix_w]
    xor r8d, r8d
    lea r9, [rel bridge_temp_path_w]
    call GetTempFileNameW
    test eax, eax
    jz .failed
    lea rcx, [rel bridge_temp_path_w]
    call DeleteFileW
    lea rdx, [rel bridge_temp_path_w]
.find_extension:
    cmp word [rdx], 0
    je .extension_found
    add rdx, 2
    jmp .find_extension
.extension_found:
    sub rdx, 8
    mov word [rdx], '.'
    mov word [rdx+2], 'e'
    mov word [rdx+4], 'x'
    mov word [rdx+6], 'e'
    mov word [rdx+8], 0
    mov eax, 1
    jmp .return
.failed:
    xor eax, eax
.return:
    EPILOGUE

build_bridge_windows_command:
    PROLOGUE
    lea rdi, [rel bridge_command_line_w]
    cmp qword [bridge_command_kind], 3
    je .only_temp_path
    mov rsi, [bridge_tool_pointer]
    cmp qword [bridge_command_kind], 4
    jne .copy_tool
    mov word [rdi], 34
    add rdi, 2
.copy_tool:
    mov ax, [rsi]
    test ax, ax
    jz .tool_done
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    jmp .copy_tool
.tool_done:
    cmp qword [bridge_command_kind], 4
    jne .tool_space
    mov word [rdi], 34
    add rdi, 2
.tool_space:
    mov word [rdi], ' '
    add rdi, 2
    mov word [rdi], 34
    add rdi, 2
    lea rsi, [rel spawn_wide_buffer]
.copy_source:
    mov ax, [rsi]
    test ax, ax
    jz .source_done
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    jmp .copy_source
.source_done:
    mov word [rdi], 34
    add rdi, 2
    cmp qword [bridge_command_kind], 2
    jne .finish_command
    mov word [rdi], ' '
    add rdi, 2
    mov word [rdi], '-'
    add rdi, 2
    mov word [rdi], 'o'
    add rdi, 2
    mov word [rdi], ' '
    add rdi, 2
    mov word [rdi], 34
    add rdi, 2
    lea rsi, [rel bridge_temp_path_w]
.copy_output:
    mov ax, [rsi]
    test ax, ax
    jz .output_done
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    jmp .copy_output
.output_done:
    mov word [rdi], 34
    add rdi, 2
    jmp .finish_command
.only_temp_path:
    mov word [rdi], 34
    add rdi, 2
    lea rsi, [rel bridge_temp_path_w]
.copy_temp:
    mov ax, [rsi]
    test ax, ax
    jz .temp_done
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    jmp .copy_temp
.temp_done:
    mov word [rdi], 34
    add rdi, 2
.finish_command:
    mov word [rdi], 0
    EPILOGUE

execute_bridge_windows_process:
    PROLOGUE
    call build_bridge_windows_command
    lea rdi, [rel bridge_startup_info]
    xor eax, eax
    mov ecx, 13
    cld
    rep stosq
    lea rdi, [rel bridge_process_info]
    xor eax, eax
    mov ecx, 3
    cld
    rep stosq
    mov dword [bridge_startup_info], 104
    mov dword [bridge_startup_info+60], 0x100
    mov ecx, -10
    call GetStdHandle
    mov [bridge_startup_info+80], rax
    mov ecx, -11
    call GetStdHandle
    mov [bridge_startup_info+88], rax
    mov ecx, -12
    call GetStdHandle
    mov [bridge_startup_info+96], rax
    sub rsp, 48
    xor ecx, ecx
    lea rdx, [rel bridge_command_line_w]
    xor r8d, r8d
    xor r9d, r9d
    mov qword [rsp+32], 1
    mov qword [rsp+40], 0x08000000
    mov qword [rsp+48], 0
    mov qword [rsp+56], 0
    lea rax, [rel bridge_startup_info]
    mov [rsp+64], rax
    lea rax, [rel bridge_process_info]
    mov [rsp+72], rax
    call CreateProcessW
    add rsp, 48
    test eax, eax
    jz .launch_failed
    mov rcx, [bridge_process_info]
    mov edx, -1
    call WaitForSingleObject
    test eax, eax
    jnz .wait_failed
    mov rcx, [bridge_process_info]
    lea rdx, [rel bridge_exit_code]
    call GetExitCodeProcess
    test eax, eax
    jz .wait_failed
    mov eax, [bridge_exit_code]
    jmp .close_handles
.wait_failed:
    mov eax, -1
.close_handles:
    mov rbx, rax
    mov rcx, [bridge_process_info+8]
    test rcx, rcx
    jz .close_process
    call CloseHandle
.close_process:
    mov rcx, [bridge_process_info]
    test rcx, rcx
    jz .return_status
    call CloseHandle
.return_status:
    mov eax, ebx
    jmp .return
.launch_failed:
    mov eax, -1
.return:
    EPILOGUE
%endif

process_line:
    PROLOGUE
    lea rax, [line_buffer]
    mov [cursor], rax
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], 0
    je .return
    cmp byte [rsi], 10
    je .return
    cmp byte [rsi], '#'
    je .return
    ; Control blocks are handled even while a parent block is inactive.
    cmp byte [rsi], 'i'
    jne .check_while
    cmp byte [rsi+1], 'f'
    jne .check_while
    cmp byte [rsi+2], ' '
    je .handle_if
    cmp byte [rsi+2], 9
    je .handle_if
.check_while:
    cmp byte [rsi], 'w'
    jne .check_else
    cmp byte [rsi+1], 'h'
    jne .check_else
    cmp byte [rsi+2], 'i'
    jne .check_else
    cmp byte [rsi+3], 'l'
    jne .check_else
    cmp byte [rsi+4], 'e'
    jne .check_else
    cmp byte [rsi+5], ' '
    je .handle_while
    cmp byte [rsi+5], 9
    je .handle_while
.check_else:
    cmp byte [rsi], 'e'
    jne .ordinary
    cmp byte [rsi+1], 'l'
    je .check_else_word
    cmp byte [rsi+1], 'n'
    jne .ordinary
    cmp byte [rsi+2], 'd'
    jne .ordinary
    cmp byte [rsi+3], ' '
    je .handle_end
    cmp byte [rsi+3], 9
    je .handle_end
    cmp byte [rsi+3], 10
    je .handle_end
    cmp byte [rsi+3], 13
    je .handle_end
    cmp byte [rsi+3], 0
    je .handle_end
    jmp .ordinary
.check_else_word:
    cmp byte [rsi+2], 's'
    jne .ordinary
    cmp byte [rsi+3], 'e'
    jne .ordinary
    cmp byte [rsi+4], ' '
    je .handle_else
    cmp byte [rsi+4], 9
    je .handle_else
    cmp byte [rsi+4], 10
    je .handle_else
    cmp byte [rsi+4], 13
    je .handle_else
    cmp byte [rsi+4], 0
    je .handle_else
    jmp .ordinary
.ordinary:
    cmp byte [active_flag], 0
    je .return
    cmp byte [rsi], 'd'
    jne .check_bridge
    cmp byte [rsi+1], 'i'
    jne .check_bridge
    cmp byte [rsi+2], 'a'
    jne .check_bridge
    cmp byte [rsi+3], 'l'
    jne .check_bridge
    cmp byte [rsi+4], 'o'
    jne .check_bridge
    cmp byte [rsi+5], 'g'
    jne .check_bridge
    cmp byte [rsi+6], ' '
    je .run_dialog
    cmp byte [rsi+6], 9
    je .run_dialog
.check_bridge:
    cmp byte [rsi], 'b'
    jne .check_app_metadata
    cmp byte [rsi+1], 'r'
    jne .check_app_metadata
    cmp byte [rsi+2], 'i'
    jne .check_app_metadata
    cmp byte [rsi+3], 'd'
    jne .check_app_metadata
    cmp byte [rsi+4], 'g'
    jne .check_app_metadata
    cmp byte [rsi+5], 'e'
    jne .check_app_metadata
    cmp byte [rsi+6], ' '
    jne .check_app_metadata
    call execute_bridge
    jmp .return
.run_dialog:
    call execute_dialog
    jmp .return
.check_app_metadata:
    ; App UI declarations are consumed by the native GUI host; the standalone
    ; assembly runtime accepts them as non-executable metadata.
    cmp byte [rsi], 'a'
    jne .check_cell
    cmp byte [rsi+1], 'p'
    jne .check_cell
    cmp byte [rsi+2], 'p'
    jne .check_cell
    cmp byte [rsi+3], ' '
    je .return
.check_cell:
    ; cell NAME := expression
    cmp byte [rsi], 'c'
    jne .check_pulse
    cmp byte [rsi+1], 'e'
    jne .check_pulse
    cmp byte [rsi+2], 'l'
    jne .check_pulse
    cmp byte [rsi+3], 'l'
    jne .check_pulse
    cmp byte [rsi+4], ' '
    jne .check_pulse
    add qword [cursor], 4
    call skip_spaces
    call parse_identifier
    test eax, eax
    jz error_syntax
    call copy_target
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], ':'
    jne error_syntax
    inc qword [cursor]
    mov rsi, [cursor]
    cmp byte [rsi], '='
    jne error_syntax
    inc qword [cursor]
    call eval_expr
    mov [pending_value], rax
    call restore_target
    call set_variable
    jmp .return
.check_pulse:
    mov rsi, [cursor]
    cmp byte [rsi], 'a'
    jne .check_read_file
    cmp byte [rsi+1], 'p'
    jne .check_read_file
    cmp byte [rsi+2], 'p'
    jne .check_read_file
    cmp byte [rsi+3], 'e'
    jne .check_read_file
    cmp byte [rsi+4], 'n'
    jne .check_read_file
    cmp byte [rsi+5], 'd'
    jne .check_read_file
    cmp byte [rsi+6], ' '
    je .run_append
    cmp byte [rsi+6], 9
    je .run_append
.check_read_file:
    mov rsi, [cursor]
    cmp byte [rsi], 'r'
    jne .check_read_keyword
    cmp byte [rsi+1], 'e'
    jne .check_read_keyword
    cmp byte [rsi+2], 'm'
    jne .check_read_keyword
    cmp byte [rsi+3], 'o'
    jne .check_read_keyword
    cmp byte [rsi+4], 'v'
    jne .check_read_keyword
    cmp byte [rsi+5], 'e'
    jne .check_read_keyword
    cmp byte [rsi+6], ' '
    je .run_remove_file
    cmp byte [rsi+6], 9
    je .run_remove_file
.check_read_keyword:
    mov rsi, [cursor]
    cmp byte [rsi], 'r'
    jne .check_spawn
    cmp byte [rsi+1], 'e'
    jne .check_spawn
    cmp byte [rsi+2], 'a'
    jne .check_spawn
    cmp byte [rsi+3], 'd'
    jne .check_spawn
    cmp byte [rsi+4], ' '
    je .run_read_file
    cmp byte [rsi+4], 9
    je .run_read_file
.check_spawn:
    mov rsi, [cursor]
    cmp byte [rsi], 's'
    jne .check_pulse_keyword
    cmp byte [rsi+1], 'p'
    jne .check_pulse_keyword
    cmp byte [rsi+2], 'a'
    jne .check_pulse_keyword
    cmp byte [rsi+3], 'w'
    jne .check_pulse_keyword
    cmp byte [rsi+4], 'n'
    jne .check_pulse_keyword
    cmp byte [rsi+5], ' '
    je .run_spawn
    cmp byte [rsi+5], 9
    je .run_spawn
.check_pulse_keyword:
    mov rsi, [cursor]
    cmp byte [rsi], 'p'
    jne .check_sense
    cmp byte [rsi+1], 'u'
    jne .check_sense
    cmp byte [rsi+2], 'l'
    jne .check_sense
    cmp byte [rsi+3], 's'
    jne .check_sense
    cmp byte [rsi+4], 'e'
    jne .check_sense
.run_spawn:
    cmp byte [rsi], 's'
    je .dispatch_spawn
    add qword [cursor], 5
.pulse_command_body:
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], '"'
    je .pulse_string
    cmp byte [rsi], 39
    je .pulse_string
    call eval_expr
%ifdef WIN_BUILD
    lea rcx, [fmt_number]
    mov rdx, rax
%else
    lea rdi, [fmt_number]
    mov rsi, rax
%endif
    xor eax, eax
    call printf
    xor edi, edi
%ifdef WIN_BUILD
    xor ecx, ecx
%endif
    call fflush
    jmp .return
.dispatch_spawn:
    call execute_spawn
    jmp .return
.run_append:
    call execute_append
    jmp .return
.run_read_file:
    call execute_read_file
    jmp .return
.run_remove_file:
    call execute_remove_file
    jmp .return
.pulse_string:
    mov al, [rsi]
    mov [operator], al
    inc rsi
    mov [string_pointer], rsi
.find_quote:
    mov al, [rsi]
    test al, al
    jz error_syntax
    cmp al, 10
    je error_syntax
    cmp al, [operator]
    je .quote_found
    inc rsi
    jmp .find_quote
.quote_found:
    mov byte [rsi], 0
%ifdef WIN_BUILD
    lea rcx, [fmt_string]
    mov rdx, [string_pointer]
%else
    lea rdi, [fmt_string]
    mov rsi, [string_pointer]
%endif
    xor eax, eax
    call printf
    xor edi, edi
%ifdef WIN_BUILD
    xor ecx, ecx
%endif
    call fflush
    jmp .return
.check_sense:
    mov rsi, [cursor]
    cmp byte [rsi], 's'
    jne .assignment
    cmp byte [rsi+1], 'e'
    jne .assignment
    cmp byte [rsi+2], 'n'
    jne .assignment
    cmp byte [rsi+3], 's'
    jne .assignment
    cmp byte [rsi+4], 'e'
    jne .assignment
    cmp byte [rsi+5], ' '
    je .sense_keyword_ok
    cmp byte [rsi+5], 9
    jne error_syntax
.sense_keyword_ok:
    add qword [cursor], 5
    call skip_spaces
    call parse_identifier
    test eax, eax
    jz error_syntax
    call copy_target
    call read_integer
    mov [pending_value], rax
    call restore_target
    call set_variable
    jmp .return
.assignment:
    call parse_identifier
    test eax, eax
    jz error_syntax
    call copy_target
    call skip_spaces
    mov rsi, [cursor]
    cmp byte [rsi], ':'
    jne error_syntax
    inc qword [cursor]
    mov rsi, [cursor]
    cmp byte [rsi], '='
    jne error_syntax
    inc qword [cursor]
    call eval_expr
    mov [pending_value], rax
    call restore_target
    call set_variable
.return:
    EPILOGUE
.handle_if:
    add qword [cursor], 2
    call skip_spaces
    mov rax, [if_depth]
    cmp rax, 64
    jae error_syntax
    mov [if_frame_index], rax
    lea r11, [rel if_parent]
    mov dl, [active_flag]
    mov [r11+rax], dl
    lea r11, [rel if_type]
    mov byte [r11+rax], 0
    lea r11, [rel if_condition]
    mov byte [r11+rax], 0
    lea r11, [rel if_else_seen]
    mov byte [r11+rax], 0
    inc qword [if_depth]
    cmp byte [active_flag], 0
    je .inactive_if
    call eval_condition
    mov dl, al
    mov r11, [if_frame_index]
    lea r10, [rel if_condition]
    mov [r10+r11], dl
    mov [active_flag], dl
    jmp .return
.inactive_if:
    mov r11, [if_frame_index]
    lea r10, [rel if_condition]
    mov byte [r10+r11], 0
    jmp .return
.handle_while:
    add qword [cursor], 5
    call skip_spaces
    mov rax, [if_depth]
    test rax, rax
    jz .new_while
    dec rax
    lea r10, [rel if_type]
    cmp byte [r10+rax], 1
    jne .new_while
    lea r10, [rel while_line_offset]
    mov rdx, [line_start_offset]
    cmp [r10+rax*8], rdx
    jne .new_while
    mov [if_frame_index], rax
    call eval_condition
    mov dl, al
    mov r11, [if_frame_index]
    lea r10, [rel if_condition]
    mov [r10+r11], dl
    mov [active_flag], dl
    jmp .return
.new_while:
    mov rax, [if_depth]
    cmp rax, 64
    jae error_syntax
    mov [if_frame_index], rax
    lea r11, [rel if_parent]
    mov dl, [active_flag]
    mov [r11+rax], dl
    lea r11, [rel if_type]
    mov byte [r11+rax], 1
    lea r11, [rel if_condition]
    mov byte [r11+rax], 0
    lea r11, [rel if_else_seen]
    mov byte [r11+rax], 0
    lea r11, [rel while_line_offset]
    mov rdx, [line_start_offset]
    mov [r11+rax*8], rdx
    inc qword [if_depth]
    cmp byte [active_flag], 0
    je .inactive_while
    call eval_condition
    mov dl, al
    mov r11, [if_frame_index]
    lea r10, [rel if_condition]
    mov [r10+r11], dl
    mov [active_flag], dl
    jmp .return
.inactive_while:
    mov r11, [if_frame_index]
    lea r10, [rel if_condition]
    mov byte [r10+r11], 0
    jmp .return
.handle_else:
    mov rax, [if_depth]
    test rax, rax
    jz error_syntax
    dec rax
    mov [if_frame_index], rax
    lea r10, [rel if_type]
    cmp byte [r10+rax], 0
    jne error_syntax
    lea r10, [rel if_else_seen]
    cmp byte [r10+rax], 0
    jne error_syntax
    mov byte [r10+rax], 1
    lea r10, [rel if_parent]
    cmp byte [r10+rax], 0
    je .inactive_else
    lea r10, [rel if_condition]
    cmp byte [r10+rax], 0
    jne .inactive_else
    mov byte [active_flag], 1
    jmp .return
.inactive_else:
    mov byte [active_flag], 0
    jmp .return
.handle_end:
    mov rax, [if_depth]
    test rax, rax
    jz error_syntax
    dec rax
    mov [if_frame_index], rax
    lea r10, [rel if_type]
    cmp byte [r10+rax], 1
    jne .close_if
    lea r10, [rel if_condition]
    cmp byte [r10+rax], 0
    je .close_if
    lea r10, [rel while_line_offset]
    mov rsi, [r10+rax*8]
    mov rdi, [file_value]
%ifdef WIN_BUILD
    mov rcx, rdi
    mov rdx, rsi
    xor r8d, r8d
%else
    xor edx, edx
%endif
    call fseek
    jmp .return
.close_if:
    mov [if_depth], rax
    lea r10, [rel if_parent]
    mov dl, [r10+rax]
    mov [active_flag], dl
    jmp .return

eval_condition:
    call eval_expr
    mov [condition_left], rax
    call skip_spaces
    mov rsi, [cursor]
    mov al, [rsi]
    cmp al, 0
    je .truthy
    cmp al, 10
    je .truthy
    cmp al, 13
    je .truthy
    cmp al, '='
    je .equal
    cmp al, '!'
    je .not_equal
    cmp al, '<'
    je .less
    cmp al, '>'
    je .greater
    jmp error_syntax
.truthy:
    mov rax, [condition_left]
    test rax, rax
    setne al
    movzx eax, al
    ret
.equal:
    cmp byte [rsi+1], '='
    jne error_syntax
    mov byte [condition_operator], '='
    add qword [cursor], 2
    jmp .read_right
.not_equal:
    cmp byte [rsi+1], '='
    jne error_syntax
    mov byte [condition_operator], '!'
    add qword [cursor], 2
    jmp .read_right
.less:
    cmp byte [rsi+1], '='
    jne .less_only
    mov byte [condition_operator], 'l'
    add qword [cursor], 2
    jmp .read_right
.less_only:
    mov byte [condition_operator], '<'
    inc qword [cursor]
    jmp .read_right
.greater:
    cmp byte [rsi+1], '='
    jne .greater_only
    mov byte [condition_operator], 'g'
    add qword [cursor], 2
    jmp .read_right
.greater_only:
    mov byte [condition_operator], '>'
    inc qword [cursor]
.read_right:
    call eval_expr
    mov [condition_right], rax
    mov al, [condition_operator]
    cmp al, '='
    je .compare_equal
    cmp al, '!'
    je .compare_not_equal
    cmp al, '<'
    je .compare_less
    cmp al, 'l'
    je .compare_less_equal
    cmp al, '>'
    je .compare_greater
    cmp al, 'g'
    je .compare_greater_equal
    jmp error_syntax
.compare_equal:
    mov rax, [condition_left]
    cmp rax, [condition_right]
    sete al
    jmp .comparison_done
.compare_not_equal:
    mov rax, [condition_left]
    cmp rax, [condition_right]
    setne al
    jmp .comparison_done
.compare_less:
    mov rax, [condition_left]
    cmp rax, [condition_right]
    setl al
    jmp .comparison_done
.compare_less_equal:
    mov rax, [condition_left]
    cmp rax, [condition_right]
    setle al
    jmp .comparison_done
.compare_greater:
    mov rax, [condition_left]
    cmp rax, [condition_right]
    setg al
    jmp .comparison_done
.compare_greater_equal:
    mov rax, [condition_left]
    cmp rax, [condition_right]
    setge al
.comparison_done:
    movzx eax, al
    ret

copy_target:
    lea rsi, [id_buffer]
    lea rdi, [target_buffer]
    mov ecx, 32
    cld
    rep movsb
    ret
restore_target:
    lea rsi, [target_buffer]
    lea rdi, [id_buffer]
    mov ecx, 32
    cld
    rep movsb
    ret

; sense reads one signed decimal integer from stdin.
read_integer:
    PROLOGUE
    mov qword [input_value], 0
    mov qword [input_sign], 1
    mov qword [input_state], 0
.next_char:
    call getchar
    cmp eax, -1
    je .finish
    cmp eax, 10
    je .finish
    cmp eax, 13
    je .space
    cmp eax, ' '
    je .space
    cmp eax, 9
    je .space
    cmp eax, '+'
    je .plus_sign
    cmp eax, '-'
    je .minus_sign
    cmp eax, '0'
    jb error_input
    cmp eax, '9'
    ja error_input
    cmp qword [input_state], 3
    je error_input
    mov qword [input_state], 2
    sub eax, '0'
    movsxd rdx, eax
    mov rax, [input_value]
    imul rax, rax, 10
    add rax, rdx
    mov [input_value], rax
    jmp .next_char
.space:
    cmp qword [input_state], 2
    jne .next_char
    mov qword [input_state], 3
    jmp .next_char
.plus_sign:
    cmp qword [input_state], 0
    jne error_input
    mov qword [input_state], 1
    jmp .next_char
.minus_sign:
    cmp qword [input_state], 0
    jne error_input
    mov qword [input_sign], -1
    mov qword [input_state], 1
    jmp .next_char
.finish:
    cmp qword [input_state], 2
    jb error_input
    mov rax, [input_value]
    imul rax, [input_sign]
    EPILOGUE

error_syntax:
    FATAL_ALIGN
    lea rdi, [fmt_error]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
    lea rdi, [msg_syntax]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
    mov edi, 1
%ifdef WIN_BUILD
    mov ecx, 1
%endif
    call exit
    ud2
error_unknown:
    FATAL_ALIGN
    lea rdi, [fmt_error]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
    lea rdi, [msg_unknown]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
    mov edi, 1
%ifdef WIN_BUILD
    mov ecx, 1
%endif
    call exit
    ud2
error_toomany:
    FATAL_ALIGN
    lea rdi, [fmt_error]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
    lea rdi, [msg_toomany]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
    mov edi, 1
%ifdef WIN_BUILD
    mov ecx, 1
%endif
    call exit
    ud2
error_divzero:
    FATAL_ALIGN
    lea rdi, [fmt_error]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
    lea rdi, [msg_divzero]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
    mov edi, 1
%ifdef WIN_BUILD
    mov ecx, 1
%endif
    call exit
    ud2
error_input:
    FATAL_ALIGN
    lea rdi, [fmt_error]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
    lea rdi, [msg_input]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
    mov edi, 1
%ifdef WIN_BUILD
    mov ecx, 1
%endif
    call exit
    ud2

error_function:
    FATAL_ALIGN
    lea rdi, [fmt_error]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
    lea rdi, [msg_function]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
    mov edi, 1
%ifdef WIN_BUILD
    mov ecx, 1
%endif
    call exit
    ud2
error_arity:
    FATAL_ALIGN
    lea rdi, [fmt_error]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
    lea rdi, [msg_arity]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
    mov edi, 1
%ifdef WIN_BUILD
    mov ecx, 1
%endif
    call exit
    ud2
error_range:
    FATAL_ALIGN
    lea rdi, [fmt_error]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
    lea rdi, [msg_range]
%ifdef WIN_BUILD
    mov rcx, rdi
%endif
    xor eax, eax
    call printf
    mov edi, 1
%ifdef WIN_BUILD
    mov ecx, 1
%endif
    call exit
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
