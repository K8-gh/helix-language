; Helix 0.9.1 — integrated Win32 runner front-end, written in NASM.
; The language engine ships as an internal sibling helper executable.

default rel

global wWinMain
global HelixWndProc
extern RegisterClassW
extern CreateWindowExW
extern ShowWindow
extern UpdateWindow
extern GetMessageW
extern TranslateMessage
extern DispatchMessageW
extern DefWindowProcW
extern DestroyWindow
extern LoadCursorW
extern SendMessageW
extern GetWindowTextW
extern SetWindowTextW
extern SetFocus
extern PostQuitMessage
extern SetTimer
extern GetOpenFileNameW
extern GetModuleFileNameW
extern CreatePipe
extern SetHandleInformation
extern CreateProcessW
extern CloseHandle
extern PeekNamedPipe
extern ReadFile
extern WriteFile
extern WaitForSingleObject
extern TerminateProcess
extern MultiByteToWideChar
extern WideCharToMultiByte
extern CreateSolidBrush
extern CreateFontW
extern SetTextColor
extern SetBkColor
extern SetWindowLongPtrW
extern MoveWindow
extern CallWindowProcW
extern CreateFileW
extern ReadFile

%define WM_CREATE 1
%define WM_DESTROY 2
%define WM_KEYDOWN 0x0100
%define WM_CHAR 0x0102
%define WM_CLOSE 16
%define WM_COMMAND 273
%define WM_TIMER 275
%define WM_SIZE 5
%define WM_SETFONT 48
%define WM_CTLCOLOREDIT 0x0133
%define WM_CTLCOLORBTN 0x0135
%define WM_CTLCOLORSTATIC 0x0138
%define SW_SHOW 5
%define SW_HIDE 0
%define WS_OVERLAPPEDWINDOW 0x00CF0000
%define WS_VISIBLE 0x10000000
%define WS_CHILD 0x40000000
%define WS_BORDER 0x00800000
%define WS_VSCROLL 0x00200000
%define ES_MULTILINE 0x0004
%define ES_AUTOVSCROLL 0x0040
%define ES_READONLY 0x0800
%define ES_AUTOHSCROLL 0x0080
%define STARTF_USESTDHANDLES 0x00000100
%define CREATE_NO_WINDOW 0x08000000
%define CREATE_NEW_CONSOLE 0x00000010
%define HANDLE_FLAG_INHERIT 1
%define GWLP_WNDPROC -4
%define VK_RETURN 13
%define OFN_FILEMUSTEXIST 0x00001000
%define OFN_PATHMUSTEXIST 0x00000800
%define OFN_EXPLORER 0x00080000
%define EM_SETSEL 0x00B1
%define EM_REPLACESEL 0x00C2
%define ID_BROWSE 101
%define ID_RUN 102
%define ID_PATH 103
%define ID_OUTPUT 104
%define ID_INPUT 105
%define ID_SEND 106
%define ID_INPUT_LABEL 107
%define ID_STOP 108
%define ID_CLEAR 109
%define ID_APP_BUTTON_BASE 200
%define MAX_APP_BUTTONS 6

%macro WPROLOGUE 0
    push rbp
    mov rbp, rsp
    push rbx
    push rsi
    push rdi
    sub rsp, 40
%endmacro
%macro WEPILOGUE 0
    add rsp, 40
    pop rdi
    pop rsi
    pop rbx
    mov rsp, rbp
    pop rbp
    ret
%endmacro

; CONTROL style, className, caption, x, y, w, h, id
%macro CONTROL 8
    sub rsp, 96
    xor ecx, ecx
    lea rdx, [rel %2]
    lea r8, [rel %3]
    mov r9d, %1
    mov dword [rsp+32], %4
    mov dword [rsp+40], %5
    mov dword [rsp+48], %6
    mov dword [rsp+56], %7
    mov rax, [window_current]
    mov [rsp+64], rax
    mov qword [rsp+72], %8
    mov rax, [instance_value]
    mov [rsp+80], rax
    mov qword [rsp+88], 0
    call CreateWindowExW
    add rsp, 96
%endmacro

section .rdata
class_name:     dw 'H','e','l','i','x','0','9','1',0
window_title:   dw 'H','e','l','i','x',' ','0','.','9','.','1',' ','-',' ','T','e','r','m','i','n','a','l',0
class_edit:     dw 'E','D','I','T',0
class_button:   dw 'B','U','T','T','O','N',0
class_static:   dw 'S','T','A','T','I','C',0
font_name:      dw 'C','o','n','s','o','l','a','s',0
text_path:      dw 0x0424,0x0430,0x0439,0x043B,0x0020,0x0048,0x0065,0x006C,0x0069,0x0078,0x0020,0x0028,0x002E,0x0068,0x006C,0x0078,0x0029,0x003A,0
text_browse:    dw 0x041E,0x0431,0x0437,0x043E,0x0440,0x002E,0x002E,0x002E,0
text_run:       dw 0x0417,0x0430,0x043F,0x0443,0x0441,0x043A,0
text_stop:      dw 0x0421,0x0442,0x043E,0x043F,0
text_clear:     dw 0x041E,0x0447,0x0438,0x0441,0x0442,0x0438,0x0442,0x044C,0
text_send:      dw 0x041E,0x0442,0x043F,0x0440,0x0430,0x0432,0x0438,0x0442,0x044C,0
text_input_label: dw 0x0412,0x0432,0x043E,0x0434,0x0020,0x0028,0x0045,0x006E,0x0074,0x0065,0x0072,0x0029,0x003A,0
text_app_input_label: dw 0x0412,0x0432,0x043E,0x0434,0x0020,0x043F,0x0440,0x0438,0x043B,0x043E,0x0436,0x0435,0x043D,0x0438,0x044F,0x0020,0x0028,0x0045,0x006E,0x0074,0x0065,0x0072,0x0029,0x003A,0
text_app_title: dw 'H','e','l','i','x',' ','A','p','p',0
text_empty:     dw 0
text_welcome:   dw 0x0422,0x0435,0x0440,0x043C,0x0438,0x043D,0x0430,0x043B,0x0020,0x0048,0x0065,0x006C,0x0069,0x0078,0x0020,0x0030,0x002E,0x0039,0x002E,0x0031,13,10,0x0412,0x044B,0x0431,0x0435,0x0440,0x0438,0x0442,0x0435,0x0020,0x0444,0x0430,0x0439,0x043B,0x0020,0x002E,0x0068,0x006C,0x0078,0x0020,0x0438,0x0020,0x043D,0x0430,0x0436,0x043C,0x0438,0x0442,0x0435,0x0020,0x00AB,0x0417,0x0430,0x043F,0x0443,0x0441,0x043A,0x00BB,0x002E,13,10,0
text_no_file:   dw 0x0421,0x043D,0x0430,0x0447,0x0430,0x043B,0x0430,0x0020,0x0432,0x044B,0x0431,0x0435,0x0440,0x0438,0x0442,0x0435,0x0020,0x0444,0x0430,0x0439,0x043B,0x0020,0x002E,0x0068,0x006C,0x0078,0x002E,13,10,0
text_busy:      dw 0x041F,0x0440,0x043E,0x0433,0x0440,0x0430,0x043C,0x043C,0x0430,0x0020,0x0048,0x0065,0x006C,0x0069,0x0078,0x0020,0x0443,0x0436,0x0435,0x0020,0x0437,0x0430,0x043F,0x0443,0x0449,0x0435,0x043D,0x0430,0x002E,13,10,0
text_start_error: dw 0x0414,0x0432,0x0438,0x0436,0x043E,0x043A,0x0020,0x0048,0x0065,0x006C,0x0069,0x0078,0x0020,0x043D,0x0435,0x0020,0x043D,0x0430,0x0439,0x0434,0x0435,0x043D,0x0020,0x0440,0x044F,0x0434,0x043E,0x043C,0x0020,0x0441,0x0020,0x043F,0x0440,0x0438,0x043B,0x043E,0x0436,0x0435,0x043D,0x0438,0x0435,0x043C,0x002E,13,10,0
text_send_error: dw 0x0421,0x0435,0x0439,0x0447,0x0430,0x0441,0x0020,0x043F,0x0440,0x043E,0x0433,0x0440,0x0430,0x043C,0x043C,0x0430,0x0020,0x043D,0x0435,0x0020,0x043E,0x0436,0x0438,0x0434,0x0430,0x0435,0x0442,0x0020,0x0432,0x0432,0x043E,0x0434,0x0430,0x002E,13,10,0
text_finished:  dw 13,10,0x005B,0x043F,0x0440,0x043E,0x0433,0x0440,0x0430,0x043C,0x043C,0x0430,0x0020,0x0437,0x0430,0x0432,0x0435,0x0440,0x0448,0x0435,0x043D,0x0430,0x005D,13,10,0
text_stop_requested: dw 13,10,0x005B,0x043E,0x0441,0x0442,0x0430,0x043D,0x043E,0x0432,0x043A,0x0430,0x0020,0x0437,0x0430,0x043F,0x0440,0x043E,0x0448,0x0435,0x043D,0x0430,0x005D,13,10,0
text_prefix:    dw '> ',0
text_crlf:      dw 13,10,0
text_native_started: dw 0x0417,0x0430,0x043F,0x0443,0x0449,0x0435,0x043D,0x0430,0x0020,0x0441,0x0438,0x0441,0x0442,0x0435,0x043C,0x043D,0x0430,0x044F,0x0020,0x043A,0x043E,0x043D,0x0441,0x043E,0x043B,0x044C,0x0020,0x0057,0x0069,0x006E,0x0064,0x006F,0x0077,0x0073,0x002E,13,10,0
text_output_truncated: dw 91,72,101,108,105,120,58,32,111,117,116,112,117,116,32,108,105,110,101,32,101,120,99,101,101,100,101,100,32,54,53,53,51,54,32,98,121,116,101,115,59,32,101,97,114,108,105,101,114,32,102,114,97,103,109,101,110,116,32,116,114,117,110,99,97,116,101,100,93,13,10,0
header_windows: db 'helix console windows',0
header_app:     db 'helix app',0
app_title_prefix: db 'app title ',0
app_size_prefix: db 'app size ',0
app_button_prefix: db 'app button ',0
app_input_prefix: db 'app input',0
runtime_leaf:   dw 'h','e','l','i','x','-','c','o','r','e','.','e','x','e',0
default_ext:    dw 'h','l','x',0
filter_source:  dw 'H','e','l','i','x',' ','s','o','u','r','c','e',' ','(','*','.','h','l','x',')',0,'*','.','h','l','x',0,'A','l','l',' ','f','i','l','e','s',0,'*','.','*',0,0

section .data
window_class:
    dd 3
    dd 0                    ; padding to 8-byte pointer alignment
    dq HelixWndProc
    dd 0,0
    dq 0                    ; hInstance
    dq 0                    ; hIcon
    dq 0                    ; hCursor
    dq 4                    ; BLACK_BRUSH; replaced at startup with the terminal brush
    dq 0                    ; menu
    dq class_name

section .bss
instance_value: resq 1
background_brush: resq 1
terminal_font:  resq 1
window_current: resq 1
main_window:    resq 1
path_hwnd:      resq 1
path_label_hwnd:resq 1
output_hwnd:    resq 1
input_hwnd:     resq 1
input_label_hwnd:resq 1
run_hwnd:       resq 1
stop_hwnd:      resq 1
clear_hwnd:     resq 1
send_hwnd:      resq 1
input_old_proc: resq 1
mode_file_handle: resq 1
detected_console_mode: resd 1
detected_app_mode: resd 1
mode_bytes_read: resd 1
input_msg_hwnd: resq 1
input_msg_id:   resd 1
input_msg_wparam: resq 1
input_msg_lparam: resq 1
browse_hwnd:    resq 1
startup_cmd:    resq 1
message_buffer: resb 48
message_id:     resd 1
wparam_value:   resq 1
lparam_value:   resq 1
wnd_proc_result:resq 1
module_path:    resw 1024
runtime_path:   resw 1024
selected_file:  resw 1024
command_line:   resw 2200
startup_file:   resw 1024
file_dialog:    resb 160
security_attrs: resb 24
startup_info:   resb 104
process_info:   resb 24
pipe_out_read:  resq 1
pipe_out_write: resq 1
pipe_in_read:   resq 1
pipe_in_write:  resq 1
process_handle: resq 1
thread_handle:  resq 1
child_done:     resd 1
bytes_available:resd 1
bytes_read:     resd 1
bytes_written:  resd 1
read_buffer:    resb 4096
header_buffer:  resb 128
wide_buffer:    resw 65537
pending_utf8:   resb 65536
pending_length: resq 1
convert_length: resq 1
user_wide:      resw 1024
user_utf8:      resb 4096
echo_wide:      resw 1100
append_pointer: resq 1
char_count:     resq 1
copy_pointer:   resq 1
msg:            resb 48
app_button_count: resd 1
app_has_input:  resd 1
app_event_ids:  resd MAX_APP_BUTTONS
app_button_hwnds: resq MAX_APP_BUTTONS
app_source_size: resd 1
app_parse_ptr:  resq 1
app_line_ptr:   resq 1
app_text_ptr:   resq 1
app_temp_id:    resd 1
app_event_digits: resb 16
app_event_buffer: resb 16
app_event_len:  resd 1
app_source_buffer: resb 65536
app_text_buffer: resb 512
app_wide_buffer: resw 256
app_title_buffer: resw 256
app_event_temp: resd 1
app_size_width: resd 1
app_size_height: resd 1

section .text

wWinMain:
    WPROLOGUE
    mov [instance_value], rcx
    mov [startup_cmd], r8
    mov [window_class+24], rcx
    mov ecx, 0x000C0C0C
    call CreateSolidBrush
    mov [background_brush], rax
    mov [window_class+48], rax
    mov ecx, -18
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    sub rsp, 112
    mov dword [rsp+32], 400      ; FW_NORMAL
    mov dword [rsp+40], 0        ; italic
    mov dword [rsp+48], 0        ; underline
    mov dword [rsp+56], 0        ; strikeout
    mov dword [rsp+64], 1        ; DEFAULT_CHARSET
    mov dword [rsp+72], 0        ; OUT_DEFAULT_PRECIS
    mov dword [rsp+80], 0        ; CLIP_DEFAULT_PRECIS
    mov dword [rsp+88], 5        ; CLEARTYPE_QUALITY
    mov dword [rsp+96], 0x31     ; FIXED_PITCH | FF_MODERN
    lea rax, [rel font_name]
    mov [rsp+104], rax
    call CreateFontW
    add rsp, 112
    mov [terminal_font], rax
    xor ecx, ecx
    mov edx, 32512
    call LoadCursorW
    mov [window_class+40], rax
    lea rcx, [rel window_class]
    call RegisterClassW

    sub rsp, 96
    xor ecx, ecx
    lea rdx, [rel class_name]
    lea r8, [rel window_title]
    mov r9d, WS_OVERLAPPEDWINDOW | WS_VISIBLE
    mov dword [rsp+32], 0x80000000
    mov dword [rsp+40], 0x80000000
    mov dword [rsp+48], 1200
    mov dword [rsp+56], 740
    mov qword [rsp+64], 0
    mov qword [rsp+72], 0
    mov rax, [instance_value]
    mov [rsp+80], rax
    mov qword [rsp+88], 0
    call CreateWindowExW
    add rsp, 96
    mov [main_window], rax
    test rax, rax
    jz .quit
    mov rcx, rax
    mov edx, SW_SHOW
    call ShowWindow
    mov rcx, [main_window]
    call UpdateWindow
.loop:
    lea rcx, [rel message_buffer]
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    call GetMessageW
    test eax, eax
    jle .quit
    lea rcx, [rel message_buffer]
    call TranslateMessage
    lea rcx, [rel message_buffer]
    call DispatchMessageW
    jmp .loop
.quit:
    xor eax, eax
    WEPILOGUE

HelixWndProc:
    WPROLOGUE
    mov [window_current], rcx
    mov [message_id], edx
    mov [wparam_value], r8
    mov [lparam_value], r9
    cmp edx, WM_CREATE
    je .create
    cmp edx, WM_COMMAND
    je .command
    cmp edx, WM_TIMER
    je .timer
    cmp edx, WM_SIZE
    je .size
    cmp edx, WM_CTLCOLOREDIT
    je .paint_terminal
    cmp edx, WM_CTLCOLORSTATIC
    je .paint_terminal
    cmp edx, WM_CTLCOLORBTN
    je .paint_terminal
    cmp edx, WM_CLOSE
    je .close
    cmp edx, WM_DESTROY
    je .destroy
.default:
    mov rcx, [window_current]
    mov edx, [message_id]
    mov r8, [wparam_value]
    mov r9, [lparam_value]
    call DefWindowProcW
    WEPILOGUE
.paint_terminal:
    mov rcx, [wparam_value]
    mov edx, 0x00D8D8D8
    call SetTextColor
    mov rcx, [wparam_value]
    mov edx, 0x000C0C0C
    call SetBkColor
    mov rax, [background_brush]
    WEPILOGUE
.create:
    mov rax, [window_current]
    mov [main_window], rax
    mov rax, [instance_value]
    ; path label
    CONTROL (WS_CHILD | WS_VISIBLE), class_static, text_path, 15, 15, 155, 28, 0
    mov [path_label_hwnd], rax
    mov rcx, rax
    call set_terminal_font
    ; path field
    CONTROL (WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOHSCROLL), class_edit, text_empty, 180, 12, 570, 32, ID_PATH
    mov [path_hwnd], rax
    mov rcx, rax
    call set_terminal_font
    ; browse button
    CONTROL (WS_CHILD | WS_VISIBLE), class_button, text_browse, 760, 12, 90, 32, ID_BROWSE
    mov rcx, rax
    call set_terminal_font
    mov [browse_hwnd], rax
    ; run button
    CONTROL (WS_CHILD | WS_VISIBLE), class_button, text_run, 860, 12, 90, 32, ID_RUN
    mov rcx, rax
    call set_terminal_font
    mov [run_hwnd], rax
    CONTROL (WS_CHILD | WS_VISIBLE), class_button, text_stop, 960, 12, 90, 32, ID_STOP
    mov [stop_hwnd], rax
    mov rcx, rax
    call set_terminal_font
    CONTROL (WS_CHILD | WS_VISIBLE), class_button, text_clear, 1060, 12, 100, 32, ID_CLEAR
    mov [clear_hwnd], rax
    mov rcx, rax
    call set_terminal_font
    ; output pane
    CONTROL (WS_CHILD | WS_VISIBLE | WS_BORDER | WS_VSCROLL | ES_MULTILINE | ES_AUTOVSCROLL | ES_READONLY), class_edit, text_empty, 15, 55, 1150, 570, ID_OUTPUT
    mov [output_hwnd], rax
    mov rcx, rax
    call set_terminal_font
    ; input label and input field
    CONTROL (WS_CHILD | WS_VISIBLE), class_static, text_input_label, 15, 645, 130, 32, ID_INPUT_LABEL
    mov [input_label_hwnd], rax
    mov rcx, rax
    call set_terminal_font
    ; input field
    CONTROL (WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOHSCROLL), class_edit, text_empty, 150, 645, 860, 32, ID_INPUT
    mov [input_hwnd], rax
    mov rcx, rax
    call set_terminal_font
    mov rcx, [input_hwnd]
    mov edx, GWLP_WNDPROC
    lea r8, [rel InputWndProc]
    call SetWindowLongPtrW
    mov [input_old_proc], rax
    ; send button
    CONTROL (WS_CHILD | WS_VISIBLE), class_button, text_send, 1020, 645, 140, 32, ID_SEND
    mov rcx, rax
    call set_terminal_font
    mov [send_hwnd], rax
    mov rcx, [window_current]
    mov edx, 1
    mov r8d, 50
    xor r9d, r9d
    call SetTimer
    lea rcx, [rel text_welcome]
    call append_text
    call load_startup_file
    test eax, eax
    jz .create_done
    mov rcx, [path_hwnd]
    lea rdx, [rel startup_file]
    call SetWindowTextW
    call start_program
.create_done:
    xor eax, eax
    WEPILOGUE
.command:
    mov rax, [wparam_value]
    and eax, 0xffff
    cmp eax, ID_BROWSE
    je .browse
    cmp eax, ID_RUN
    je .run
    cmp eax, ID_SEND
    je .send
    cmp eax, ID_STOP
    je .stop
    cmp eax, ID_CLEAR
    je .clear
    cmp eax, ID_APP_BUTTON_BASE
    jb .unknown_command
    cmp eax, ID_APP_BUTTON_BASE+MAX_APP_BUTTONS
    jae .unknown_command
    sub eax, ID_APP_BUTTON_BASE
    cmp eax, [app_button_count]
    jae .unknown_command
    lea rdx, [rel app_event_ids]
    mov ecx, [rdx+rax*4]
    call send_app_event
    xor eax, eax
    WEPILOGUE
.unknown_command:
    xor eax, eax
    WEPILOGUE
.browse:
    call browse_program
    xor eax, eax
    WEPILOGUE
.run:
    call start_program
    xor eax, eax
    WEPILOGUE
.send:
    call send_input
    xor eax, eax
    WEPILOGUE
.stop:
    call stop_program
    xor eax, eax
    WEPILOGUE
.clear:
    mov rcx, [output_hwnd]
    lea rdx, [rel text_empty]
    call SetWindowTextW
    xor eax, eax
    WEPILOGUE
.timer:
    call poll_program
    xor eax, eax
    WEPILOGUE
.size:
    call resize_controls
    xor eax, eax
    WEPILOGUE
.close:
    mov rcx, [window_current]
    call DestroyWindow
    xor eax, eax
    WEPILOGUE
.destroy:
    cmp qword [process_handle], 0
    je .post_quit
    mov rcx, [process_handle]
    xor edx, edx
    call TerminateProcess
    call close_process_handles
.post_quit:
    xor ecx, ecx
    call PostQuitMessage
    xor eax, eax
    WEPILOGUE

resize_controls:
    WPROLOGUE
    mov ebx, [lparam_value]
    and ebx, 0xffff
    mov esi, [lparam_value]
    shr esi, 16
    cmp ebx, 700
    jb .done
    cmp esi, 420
    jb .done
    cmp qword [output_hwnd], 0
    je .done
    ; Output pane grows with the client area.
    mov rcx, [output_hwnd]
    mov edx, 15
    mov r8d, 55
    mov r9d, ebx
    sub r9d, 30
    mov edi, esi
    sub edi, 125
    mov dword [rsp+32], edi
    call MoveWindow
    ; File path width; fixed-width action buttons hug the right edge.
    mov rcx, [path_hwnd]
    mov edx, 180
    mov r8d, 12
    mov r9d, ebx
    sub r9d, 614
    mov dword [rsp+32], 32
    call MoveWindow
    mov rcx, [browse_hwnd]
    mov edx, ebx
    sub edx, 424
    mov r8d, 12
    mov r9d, 90
    mov dword [rsp+32], 32
    call MoveWindow
    mov rcx, [run_hwnd]
    mov edx, ebx
    sub edx, 324
    mov r8d, 12
    mov r9d, 90
    mov dword [rsp+32], 32
    call MoveWindow
    mov rcx, [stop_hwnd]
    mov edx, ebx
    sub edx, 224
    mov r8d, 12
    mov r9d, 90
    mov dword [rsp+32], 32
    call MoveWindow
    mov rcx, [clear_hwnd]
    mov edx, ebx
    sub edx, 124
    mov r8d, 12
    mov r9d, 100
    mov dword [rsp+32], 32
    call MoveWindow
    ; Input row stays anchored at the bottom.
    mov edi, esi
    sub edi, 55
    mov rcx, [input_label_hwnd]
    mov edx, 15
    mov r8d, edi
    mov r9d, 130
    mov dword [rsp+32], 32
    call MoveWindow
    mov rcx, [input_hwnd]
    mov edx, 150
    mov r8d, edi
    mov r9d, ebx
    sub r9d, 324
    mov dword [rsp+32], 32
    call MoveWindow
    mov rcx, [send_hwnd]
    mov edx, ebx
    sub edx, 164
    mov r8d, edi
    mov r9d, 140
    mov dword [rsp+32], 32
    call MoveWindow
.done:
    WEPILOGUE

InputWndProc:
    WPROLOGUE
    mov [input_msg_hwnd], rcx
    mov [input_msg_id], edx
    mov [input_msg_wparam], r8
    mov [input_msg_lparam], r9
    cmp edx, WM_KEYDOWN
    jne .check_char
    cmp r8d, VK_RETURN
    jne .forward
    call send_input
    xor eax, eax
    WEPILOGUE
.check_char:
    cmp edx, WM_CHAR
    jne .forward
    cmp r8d, VK_RETURN
    jne .forward
    xor eax, eax
    WEPILOGUE
.forward:
    mov rcx, [input_old_proc]
    mov rdx, [input_msg_hwnd]
    mov r8d, [input_msg_id]
    mov r9, [input_msg_wparam]
    mov rax, [input_msg_lparam]
    mov [rsp+32], rax
    call CallWindowProcW
    WEPILOGUE

set_terminal_font:
    WPROLOGUE
    mov edx, WM_SETFONT
    mov r8, [terminal_font]
    mov r9d, 1
    call SendMessageW
    WEPILOGUE

append_text:
    WPROLOGUE
    mov [append_pointer], rcx
    mov rcx, [output_hwnd]
    mov edx, EM_SETSEL
    mov r8, -1
    mov r9, -1
    call SendMessageW
    mov rcx, [output_hwnd]
    mov edx, EM_REPLACESEL
    mov r8d, 1
    mov r9, [append_pointer]
    call SendMessageW
    WEPILOGUE

load_startup_file:
    WPROLOGUE
    mov rsi, [startup_cmd]
    test rsi, rsi
    jz .none
    cmp word [rsi], 0
    je .none
    cmp word [rsi], '"'
    jne .copy
    add rsi, 2
.copy:
    lea rdi, [rel startup_file]
.next:
    mov ax, [rsi]
    test ax, ax
    jz .finish
    cmp ax, '"'
    je .finish
    cmp ax, 13
    je .finish
    cmp ax, 10
    je .finish
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    jmp .next
.finish:
    mov word [rdi], 0
    cmp word [startup_file], 0
    je .none
    mov eax, 1
    WEPILOGUE
.none:
    xor eax, eax
    WEPILOGUE

browse_program:
    WPROLOGUE
    lea rdi, [rel file_dialog]
    xor eax, eax
    mov ecx, 20
    rep stosq
    mov dword [file_dialog], 152
    mov rax, [main_window]
    mov [file_dialog+8], rax
    lea rax, [rel filter_source]
    mov [file_dialog+24], rax
    mov dword [file_dialog+44], 1
    lea rax, [rel selected_file]
    mov [file_dialog+48], rax
    mov dword [file_dialog+56], 1024
    lea rax, [rel default_ext]
    mov [file_dialog+104], rax
    mov dword [file_dialog+96], OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_EXPLORER
    lea rcx, [rel file_dialog]
    call GetOpenFileNameW
    test eax, eax
    jz .done
    mov rcx, [path_hwnd]
    lea rdx, [rel selected_file]
    call SetWindowTextW
.done:
    WEPILOGUE

start_program:
    WPROLOGUE
    cmp qword [process_handle], 0
    je .prepare
    lea rcx, [rel text_busy]
    call append_text
    jmp .done
.prepare:
    mov qword [pending_length], 0
    mov rcx, [path_hwnd]
    lea rdx, [rel selected_file]
    mov r8d, 1024
    call GetWindowTextW
    cmp word [selected_file], 0
    jne .locate_runtime
    lea rcx, [rel text_no_file]
    call append_text
    jmp .done
.locate_runtime:
    xor ecx, ecx
    lea rdx, [rel module_path]
    mov r8d, 1024
    call GetModuleFileNameW
    lea rsi, [rel module_path]
    lea rdi, [rel runtime_path]
    mov qword [copy_pointer], 0
.copy_module_path:
    mov ax, [rsi]
    test ax, ax
    jz .leaf
    mov [rdi], ax
    cmp ax, '\'
    je .save_tail
    cmp ax, '/'
    jne .next_path_char
.save_tail:
    lea rax, [rdi+2]
    mov [copy_pointer], rax
.next_path_char:
    add rsi, 2
    add rdi, 2
    jmp .copy_module_path
.leaf:
    mov rdi, [copy_pointer]
    test rdi, rdi
    jnz .copy_runtime_name
    lea rdi, [rel runtime_path]
.copy_runtime_name:
    lea rsi, [rel runtime_leaf]
.copy_runtime_loop:
    mov ax, [rsi]
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    test ax, ax
    jnz .copy_runtime_loop
    ; Build: "<runtime>" "<source file>"
    lea rdi, [rel command_line]
    mov word [rdi], '"'
    add rdi, 2
    lea rsi, [rel runtime_path]
.copy_runtime_arg:
    mov ax, [rsi]
    test ax, ax
    jz .runtime_arg_done
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    jmp .copy_runtime_arg
.runtime_arg_done:
    mov word [rdi], '"'
    mov word [rdi+2], ' '
    mov word [rdi+4], '"'
    add rdi, 6
    lea rsi, [rel selected_file]
.copy_source_arg:
    mov ax, [rsi]
    test ax, ax
    jz .source_arg_done
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    jmp .copy_source_arg
.source_arg_done:
    mov word [rdi], '"'
    mov word [rdi+2], 0
    call detect_windows_console
    cmp eax, 1
    je .start_native_console
    call detect_helix_app
    ; Configure inheritable pipes.
    mov dword [security_attrs], 24
    mov qword [security_attrs+8], 0
    mov dword [security_attrs+16], 1
    lea rcx, [rel pipe_out_read]
    lea rdx, [rel pipe_out_write]
    lea r8, [rel security_attrs]
    xor r9d, r9d
    call CreatePipe
    test eax, eax
    jz .start_failed
    lea rcx, [rel pipe_in_read]
    lea rdx, [rel pipe_in_write]
    lea r8, [rel security_attrs]
    xor r9d, r9d
    call CreatePipe
    test eax, eax
    jz .start_failed
    mov rcx, [pipe_out_read]
    mov edx, HANDLE_FLAG_INHERIT
    xor r8d, r8d
    call SetHandleInformation
    mov rcx, [pipe_in_write]
    mov edx, HANDLE_FLAG_INHERIT
    xor r8d, r8d
    call SetHandleInformation
    lea rdi, [rel startup_info]
    xor eax, eax
    mov ecx, 13
    rep stosq
    mov dword [startup_info], 104
    mov dword [startup_info+60], STARTF_USESTDHANDLES
    mov rax, [pipe_in_read]
    mov [startup_info+80], rax
    mov rax, [pipe_out_write]
    mov [startup_info+88], rax
    mov [startup_info+96], rax
    lea rdi, [rel process_info]
    xor eax, eax
    mov ecx, 3
    rep stosq
    sub rsp, 80
    lea rcx, [rel runtime_path]
    lea rdx, [rel command_line]
    xor r8d, r8d
    xor r9d, r9d
    mov qword [rsp+32], 1
    mov qword [rsp+40], CREATE_NO_WINDOW
    mov qword [rsp+48], 0
    mov qword [rsp+56], 0
    lea rax, [rel startup_info]
    mov [rsp+64], rax
    lea rax, [rel process_info]
    mov [rsp+72], rax
    call CreateProcessW
    add rsp, 80
    test eax, eax
    jz .start_failed
    mov rax, [process_info]
    mov [process_handle], rax
    mov rax, [process_info+8]
    mov [thread_handle], rax
    mov rcx, [pipe_out_write]
    call CloseHandle
    mov rcx, [pipe_in_read]
    call CloseHandle
    mov qword [pipe_out_write], 0
    mov qword [pipe_in_read], 0
    mov dword [child_done], 0
    cmp dword [detected_app_mode], 1
    jne .standard_terminal_mode
    call enter_app_mode
.standard_terminal_mode:
    mov rcx, [input_hwnd]
    call SetFocus
    lea rcx, [rel text_crlf]
    call append_text
    jmp .done
.start_failed:
    lea rcx, [rel text_start_error]
    call append_text
    call close_process_handles
.done:
    WEPILOGUE
.start_native_console:
    ; For `helix console windows`, start the engine in a real OS console.
    lea rdi, [rel startup_info]
    xor eax, eax
    mov ecx, 13
    rep stosq
    mov dword [startup_info], 104
    lea rdi, [rel process_info]
    xor eax, eax
    mov ecx, 3
    rep stosq
    sub rsp, 80
    lea rcx, [rel runtime_path]
    lea rdx, [rel command_line]
    xor r8d, r8d
    xor r9d, r9d
    mov qword [rsp+32], 0
    mov qword [rsp+40], CREATE_NEW_CONSOLE
    mov qword [rsp+48], 0
    mov qword [rsp+56], 0
    lea rax, [rel startup_info]
    mov [rsp+64], rax
    lea rax, [rel process_info]
    mov [rsp+72], rax
    call CreateProcessW
    add rsp, 80
    test eax, eax
    jz .native_start_failed
    mov rcx, [process_info+8]
    call CloseHandle
    mov rcx, [process_info]
    call CloseHandle
    lea rcx, [rel text_native_started]
    call append_text
    WEPILOGUE
.native_start_failed:
    lea rcx, [rel text_start_error]
    call append_text
    WEPILOGUE

detect_windows_console:
    WPROLOGUE
    mov dword [detected_console_mode], 0
    sub rsp, 64
    lea rcx, [rel selected_file]
    mov edx, 0x80000000
    mov r8d, 3
    xor r9d, r9d
    mov qword [rsp+32], 3
    mov qword [rsp+40], 0x80
    mov qword [rsp+48], 0
    call CreateFileW
    add rsp, 64
    cmp rax, -1
    je .detect_done
    mov [mode_file_handle], rax
    mov dword [mode_bytes_read], 0
    sub rsp, 48
    mov rcx, [mode_file_handle]
    lea rdx, [rel header_buffer]
    mov r8d, 64
    lea r9, [rel mode_bytes_read]
    mov qword [rsp+32], 0
    call ReadFile
    add rsp, 48
    mov [input_msg_wparam], rax
    mov rcx, [mode_file_handle]
    call CloseHandle
    cmp qword [input_msg_wparam], 0
    je .detect_done
    cmp dword [mode_bytes_read], 21
    jb .detect_done
    lea rsi, [rel header_buffer]
    lea rdi, [rel header_windows]
    mov ecx, 21
    cld
    repe cmpsb
    jne .detect_done
    mov al, [header_buffer+21]
    cmp al, 10
    je .detected_windows
    cmp al, 13
    je .detected_windows
    test al, al
    jne .detect_done
.detected_windows:
    mov dword [detected_console_mode], 1
.detect_done:
    mov eax, [detected_console_mode]
    WEPILOGUE

detect_helix_app:
    WPROLOGUE
    mov dword [detected_app_mode], 0
    sub rsp, 64
    lea rcx, [rel selected_file]
    mov edx, 0x80000000
    mov r8d, 3
    xor r9d, r9d
    mov qword [rsp+32], 3
    mov qword [rsp+40], 0x80
    mov qword [rsp+48], 0
    call CreateFileW
    add rsp, 64
    cmp rax, -1
    je .detect_done
    mov [mode_file_handle], rax
    mov dword [mode_bytes_read], 0
    sub rsp, 48
    mov rcx, [mode_file_handle]
    lea rdx, [rel header_buffer]
    mov r8d, 32
    lea r9, [rel mode_bytes_read]
    mov qword [rsp+32], 0
    call ReadFile
    add rsp, 48
    mov [input_msg_wparam], rax
    mov rcx, [mode_file_handle]
    call CloseHandle
    cmp qword [input_msg_wparam], 0
    je .detect_done
    cmp dword [mode_bytes_read], 9
    jb .detect_done
    lea rsi, [rel header_buffer]
    lea rdi, [rel header_app]
    mov ecx, 9
    cld
    repe cmpsb
    jne .detect_done
    mov al, [header_buffer+9]
    cmp al, 10
    je .detected_app
    cmp al, 13
    je .detected_app
    test al, al
    jne .detect_done
.detected_app:
    mov dword [detected_app_mode], 1
.detect_done:
    mov eax, [detected_app_mode]
    WEPILOGUE

load_app_ui:
    WPROLOGUE
    mov dword [app_button_count], 0
    mov dword [app_has_input], 0
    sub rsp, 64
    lea rcx, [rel selected_file]
    mov edx, 0x80000000
    mov r8d, 3
    xor r9d, r9d
    mov qword [rsp+32], 3
    mov qword [rsp+40], 0x80
    mov qword [rsp+48], 0
    call CreateFileW
    add rsp, 64
    cmp rax, -1
    je .done
    mov [mode_file_handle], rax
    mov dword [app_source_size], 0
    sub rsp, 48
    mov rcx, [mode_file_handle]
    lea rdx, [rel app_source_buffer]
    mov r8d, 65535
    lea r9, [rel app_source_size]
    mov qword [rsp+32], 0
    call ReadFile
    add rsp, 48
    mov [input_msg_wparam], rax
    mov rcx, [mode_file_handle]
    call CloseHandle
    cmp qword [input_msg_wparam], 0
    je .done
    mov eax, [app_source_size]
    lea rdi, [rel app_source_buffer]
    mov byte [rdi+rax], 0
    mov rsi, rdi
.skip_header:
    mov al, [rsi]
    test al, al
    jz .done
    inc rsi
    cmp al, 10
    jne .skip_header
    mov [app_parse_ptr], rsi
.line_loop:
    mov rsi, [app_parse_ptr]
    mov [app_line_ptr], rsi
.skip_indent:
    mov al, [rsi]
    cmp al, ' '
    je .indent_next
    cmp al, 9
    jne .check_line_end
.indent_next:
    inc rsi
    jmp .skip_indent
.check_line_end:
    test al, al
    jz .done
    mov [app_line_ptr], rsi
    lea rdi, [rel app_title_prefix]
    mov ecx, 10
    cld
    repe cmpsb
    je .parse_title
    mov rsi, [app_line_ptr]
    lea rdi, [rel app_size_prefix]
    mov ecx, 9
    cld
    repe cmpsb
    je .parse_size
    mov rsi, [app_line_ptr]
    lea rdi, [rel app_button_prefix]
    mov ecx, 11
    cld
    repe cmpsb
    je .parse_button
    mov rsi, [app_line_ptr]
    lea rdi, [rel app_input_prefix]
    mov ecx, 9
    cld
    repe cmpsb
    jne .next_line
    mov al, [rsi]
    cmp al, 0
    je .mark_input
    cmp al, 10
    je .mark_input
    cmp al, 13
    je .mark_input
    cmp al, ' '
    jne .next_line
.mark_input:
    mov dword [app_has_input], 1
    jmp .next_line
.parse_title:
    cmp byte [rsi], '"'
    jne .next_line
    inc rsi
    lea rdi, [rel app_text_buffer]
    mov ecx, 510
.title_copy:
    mov al, [rsi]
    test al, al
    jz .next_line
    cmp al, 10
    je .next_line
    cmp al, 13
    je .next_line
    cmp al, '"'
    je .title_done
    mov [rdi], al
    inc rdi
    inc rsi
    loop .title_copy
    jmp .next_line
.title_done:
    mov byte [rdi], 0
    mov ecx, 65001
    xor edx, edx
    lea r8, [rel app_text_buffer]
    mov r9d, -1
    sub rsp, 48
    lea rax, [rel app_title_buffer]
    mov [rsp+32], rax
    mov qword [rsp+40], 256
    call MultiByteToWideChar
    add rsp, 48
    test eax, eax
    jz .next_line
    mov rcx, [main_window]
    lea rdx, [rel app_title_buffer]
    call SetWindowTextW
    jmp .next_line
.parse_size:
    xor ebx, ebx
    xor edi, edi
.width_digits:
    movzx eax, byte [rsi]
    cmp eax, '0'
    jb .width_done
    cmp eax, '9'
    ja .width_done
    imul ebx, ebx, 10
    sub eax, '0'
    add ebx, eax
    inc rsi
    inc edi
    cmp ebx, 1600
    ja .next_line
    jmp .width_digits
.width_done:
    test edi, edi
    jz .next_line
    cmp ebx, 480
    jb .next_line
.size_space:
    mov al, [rsi]
    cmp al, ' '
    je .size_space_next
    cmp al, 9
    jne .height_start
.size_space_next:
    inc rsi
    jmp .size_space
.height_start:
    xor r10d, r10d
    xor edi, edi
.height_digits:
    movzx eax, byte [rsi]
    cmp eax, '0'
    jb .height_done
    cmp eax, '9'
    ja .height_done
    imul r10d, r10d, 10
    sub eax, '0'
    add r10d, eax
    inc rsi
    inc edi
    cmp r10d, 1200
    ja .next_line
    jmp .height_digits
.height_done:
    test edi, edi
    jz .next_line
    cmp r10d, 320
    jb .next_line
.size_trailing:
    mov al, [rsi]
    cmp al, ' '
    je .size_trailing_next
    cmp al, 9
    je .size_trailing_next
    cmp al, 13
    je .apply_size
    cmp al, 10
    je .apply_size
    test al, al
    jne .next_line
.apply_size:
    mov [app_size_width], ebx
    mov [app_size_height], r10d
    mov rcx, [main_window]
    mov edx, 100
    mov r8d, 100
    mov r9d, ebx
    sub rsp, 48
    mov dword [rsp+32], r10d
    mov dword [rsp+40], 1
    call MoveWindow
    add rsp, 48
    jmp .next_line
.size_trailing_next:
    inc rsi
    jmp .size_trailing
.parse_button:
    xor ebx, ebx
    xor edi, edi
.button_id_digits:
    movzx eax, byte [rsi]
    cmp eax, '0'
    jb .button_id_done
    cmp eax, '9'
    ja .button_id_done
    imul ebx, ebx, 10
    sub eax, '0'
    add ebx, eax
    inc rsi
    inc edi
    cmp ebx, 9999
    ja .next_line
    jmp .button_id_digits
.button_id_done:
    test edi, edi
    jz .next_line
    test ebx, ebx
    jz .next_line
.button_skip_spaces:
    mov al, [rsi]
    cmp al, ' '
    je .button_space_next
    cmp al, 9
    jne .button_quote
.button_space_next:
    inc rsi
    jmp .button_skip_spaces
.button_quote:
    cmp byte [rsi], '"'
    jne .next_line
    inc rsi
    lea rdi, [rel app_text_buffer]
    xor ecx, ecx
.button_copy:
    mov al, [rsi]
    test al, al
    jz .next_line
    cmp al, 10
    je .next_line
    cmp al, 13
    je .next_line
    cmp al, '"'
    je .button_label_done
    cmp ecx, 510
    jae .next_line
    mov [rdi], al
    inc rdi
    inc rsi
    inc ecx
    jmp .button_copy
.button_label_done:
    test ecx, ecx
    jz .next_line
    mov byte [rdi], 0
    mov ecx, ebx
    lea rdx, [rel app_text_buffer]
    call create_app_button
    jmp .next_line
.next_line:
    mov rsi, [app_line_ptr]
.scan_eol:
    mov al, [rsi]
    test al, al
    jz .done
    inc rsi
    cmp al, 10
    jne .scan_eol
    mov [app_parse_ptr], rsi
    jmp .line_loop
.done:
    WEPILOGUE

create_app_button:
    WPROLOGUE
    mov [app_temp_id], ecx
    mov [app_text_ptr], rdx
    mov ebx, [app_button_count]
    cmp ebx, MAX_APP_BUTTONS
    jae .done
    xor esi, esi
.duplicate_check:
    cmp esi, ebx
    jae .convert_caption
    lea rdi, [rel app_event_ids]
    mov eax, [rdi+rsi*4]
    cmp eax, [app_temp_id]
    je .done
    inc esi
    jmp .duplicate_check
.convert_caption:
    mov ecx, 65001
    xor edx, edx
    mov r8, [app_text_ptr]
    mov r9d, -1
    sub rsp, 48
    lea rax, [rel app_wide_buffer]
    mov [rsp+32], rax
    mov qword [rsp+40], 256
    call MultiByteToWideChar
    add rsp, 48
    test eax, eax
    jz .done
    xor ecx, ecx
    lea rdx, [rel class_button]
    lea r8, [rel app_wide_buffer]
    mov r9d, WS_CHILD | WS_VISIBLE
    imul eax, ebx, 140
    add eax, 15
    sub rsp, 96
    mov dword [rsp+32], eax
    mov dword [rsp+40], 12
    mov dword [rsp+48], 130
    mov dword [rsp+56], 34
    mov rax, [main_window]
    mov [rsp+64], rax
    mov eax, ebx
    add eax, ID_APP_BUTTON_BASE
    mov [rsp+72], rax
    mov rax, [instance_value]
    mov [rsp+80], rax
    mov qword [rsp+88], 0
    call CreateWindowExW
    add rsp, 96
    test rax, rax
    jz .done
    lea rdi, [rel app_button_hwnds]
    mov [rdi+rbx*8], rax
    mov eax, [app_temp_id]
    lea rdi, [rel app_event_ids]
    mov [rdi+rbx*4], eax
    inc dword [app_button_count]
    lea rdi, [rel app_button_hwnds]
    mov rcx, [rdi+rbx*8]
    call set_terminal_font
.done:
    WEPILOGUE

send_app_event:
    WPROLOGUE
    cmp qword [process_handle], 0
    je .done
    cmp dword [child_done], 0
    jne .done
    mov [app_event_temp], ecx
    mov eax, ecx
    lea rdi, [rel app_event_digits]
    xor r9d, r9d
    mov ebx, 10
.digits:
    xor edx, edx
    div ebx
    add dl, '0'
    mov [rdi+r9], dl
    inc r9d
    test eax, eax
    jne .digits
    lea rsi, [rel app_event_digits]
    add rsi, r9
    dec rsi
    lea rdi, [rel app_event_buffer]
    mov ecx, r9d
.reverse_digits:
    mov al, [rsi]
    mov [rdi], al
    dec rsi
    inc rdi
    loop .reverse_digits
    mov byte [rdi], 10
    inc r9d
    mov [app_event_len], r9d
    mov dword [bytes_written], 0
    mov rcx, [pipe_in_write]
    lea rdx, [rel app_event_buffer]
    mov r8d, [app_event_len]
    lea r9, [rel bytes_written]
    sub rsp, 48
    mov qword [rsp+32], 0
    call WriteFile
    add rsp, 48
.done:
    WEPILOGUE

enter_app_mode:
    WPROLOGUE
    mov rcx, [main_window]
    lea rdx, [rel text_app_title]
    call SetWindowTextW
    call load_app_ui
    mov rcx, [output_hwnd]
    mov edx, SW_HIDE
    call ShowWindow
    mov rcx, [path_label_hwnd]
    mov edx, SW_HIDE
    call ShowWindow
    mov rcx, [path_hwnd]
    mov edx, SW_HIDE
    call ShowWindow
    mov rcx, [browse_hwnd]
    mov edx, SW_HIDE
    call ShowWindow
    mov rcx, [run_hwnd]
    mov edx, SW_HIDE
    call ShowWindow
    mov rcx, [stop_hwnd]
    mov edx, SW_HIDE
    call ShowWindow
    mov rcx, [clear_hwnd]
    mov edx, SW_HIDE
    call ShowWindow
    mov rcx, [input_label_hwnd]
    lea rdx, [rel text_app_input_label]
    call SetWindowTextW
    cmp dword [app_button_count], 0
    je .keep_input
    cmp dword [app_has_input], 0
    jne .keep_input
    mov rcx, [input_label_hwnd]
    mov edx, SW_HIDE
    call ShowWindow
    mov rcx, [input_hwnd]
    mov edx, SW_HIDE
    call ShowWindow
    mov rcx, [send_hwnd]
    mov edx, SW_HIDE
    call ShowWindow
.keep_input:
    WEPILOGUE

send_input:
    WPROLOGUE
    cmp qword [process_handle], 0
    je .not_running
    cmp dword [child_done], 0
    jne .not_running
    mov rcx, [input_hwnd]
    lea rdx, [rel user_wide]
    mov r8d, 1024
    call GetWindowTextW
    test eax, eax
    jz .done
    mov [char_count], rax
    ; echo typed input into the output pane
    lea rdi, [rel echo_wide]
    lea rsi, [rel text_prefix]
.copy_prefix:
    mov ax, [rsi]
    test ax, ax
    jz .copy_user
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    jmp .copy_prefix
.copy_user:
    lea rsi, [rel user_wide]
.copy_user_loop:
    mov ax, [rsi]
    test ax, ax
    jz .echo_end
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    jmp .copy_user_loop
.echo_end:
    mov word [rdi], 13
    mov word [rdi+2], 10
    mov word [rdi+4], 0
    lea rcx, [rel echo_wide]
    call append_text
    ; Convert UTF-16 edit text to UTF-8 bytes for Helix stdin.
    mov ecx, 65001
    xor edx, edx
    lea r8, [rel user_wide]
    mov r9d, -1
    sub rsp, 64
    lea rax, [rel user_utf8]
    mov [rsp+32], rax
    mov qword [rsp+40], 4096
    mov qword [rsp+48], 0
    mov qword [rsp+56], 0
    call WideCharToMultiByte
    add rsp, 64
    test eax, eax
    jz .clear_input
    dec eax
    lea rdx, [rel user_utf8]
    mov byte [rdx+rax], 10
    inc eax
    mov [bytes_written], eax
    mov rcx, [pipe_in_write]
    lea rdx, [rel user_utf8]
    mov r8d, [bytes_written]
    lea r9, [rel bytes_written]
    sub rsp, 48
    mov qword [rsp+32], 0
    call WriteFile
    add rsp, 48
.clear_input:
    mov rcx, [input_hwnd]
    lea rdx, [rel text_empty]
    call SetWindowTextW
    mov rcx, [input_hwnd]
    call SetFocus
    jmp .done
.not_running:
    lea rcx, [rel text_send_error]
    call append_text
.done:
    WEPILOGUE

stop_program:
    WPROLOGUE
    mov rcx, [process_handle]
    test rcx, rcx
    jz .done
    mov edx, 1
    call TerminateProcess
    test eax, eax
    jz .done
    lea rcx, [rel text_stop_requested]
    call append_text
.done:
    WEPILOGUE

poll_program:
    WPROLOGUE
    cmp qword [process_handle], 0
    je .done
    mov dword [bytes_available], 0
    sub rsp, 48
    mov rcx, [pipe_out_read]
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    lea rax, [rel bytes_available]
    mov [rsp+32], rax
    mov qword [rsp+40], 0
    call PeekNamedPipe
    add rsp, 48
    test eax, eax
    jz .check_done
    mov eax, [bytes_available]
    test eax, eax
    jz .check_done
    cmp eax, 4095
    jbe .read_size_ready
    mov eax, 4095
.read_size_ready:
    mov [bytes_available], eax
    mov dword [bytes_read], 0
    mov rcx, [pipe_out_read]
    lea rdx, [rel read_buffer]
    mov r8d, [bytes_available]
    lea r9, [rel bytes_read]
    sub rsp, 48
    mov qword [rsp+32], 0
    call ReadFile
    add rsp, 48
    test eax, eax
    jz .check_done
    mov eax, [bytes_read]
    test eax, eax
    jz .check_done
    mov rax, [pending_length]
    mov ecx, [bytes_read]
    add rax, rcx
    cmp rax, 65536
    jbe .pending_capacity_ok
    mov qword [pending_length], 0
    lea rcx, [rel text_output_truncated]
    call append_text
.pending_capacity_ok:
    mov rax, [pending_length]
    lea rdi, [rel pending_utf8]
    add rdi, rax
    lea rsi, [rel read_buffer]
    mov ecx, [bytes_read]
    rep movsb
    mov rax, [pending_length]
    mov ecx, [bytes_read]
    add rax, rcx
    mov [pending_length], rax
.convert_pending:
    mov rcx, [pending_length]
    test rcx, rcx
    jz .check_done
    lea rsi, [rel pending_utf8]
.find_complete_line:
    cmp byte [rsi], 10
    je .complete_line
    inc rsi
    loop .find_complete_line
    jmp .check_done
.complete_line:
    lea rax, [rel pending_utf8]
    sub rsi, rax
    inc rsi
    mov [convert_length], rsi
    mov ecx, 65001
    xor edx, edx
    lea r8, [rel pending_utf8]
    mov r9d, esi
    sub rsp, 48
    lea rax, [rel wide_buffer]
    mov [rsp+32], rax
    mov qword [rsp+40], 65536
    call MultiByteToWideChar
    add rsp, 48
    test eax, eax
    jz .check_done
    mov rdx, rax
    lea rdi, [rel wide_buffer]
    mov word [rdi+rdx*2], 0
    lea rcx, [rel wide_buffer]
    call append_text
    ; Keep any bytes after this newline and decode them on the next pass.
    mov rax, [pending_length]
    sub rax, [convert_length]
    mov [pending_length], rax
    lea rsi, [rel pending_utf8]
    add rsi, [convert_length]
    lea rdi, [rel pending_utf8]
    mov rcx, [pending_length]
    rep movsb
    jmp .convert_pending
.check_done:
    mov rcx, [process_handle]
    xor edx, edx
    call WaitForSingleObject
    test eax, eax
    jnz .done
    mov dword [child_done], 1
    ; Drain final output before closing the pipes.
    mov dword [bytes_available], 0
    sub rsp, 48
    mov rcx, [pipe_out_read]
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    lea rax, [rel bytes_available]
    mov [rsp+32], rax
    mov qword [rsp+40], 0
    call PeekNamedPipe
    add rsp, 48
    cmp dword [bytes_available], 0
    jne .done
    ; Preserve a final output fragment that did not end with LF.
    mov eax, [pending_length]
    test eax, eax
    jz .finished_message
    mov ecx, 65001
    xor edx, edx
    lea r8, [rel pending_utf8]
    mov r9d, eax
    sub rsp, 48
    lea rax, [rel wide_buffer]
    mov [rsp+32], rax
    mov qword [rsp+40], 65536
    call MultiByteToWideChar
    add rsp, 48
    test eax, eax
    jz .clear_pending
    mov rdx, rax
    lea rdi, [rel wide_buffer]
    mov word [rdi+rdx*2], 0
    lea rcx, [rel wide_buffer]
    call append_text
.clear_pending:
    mov qword [pending_length], 0
.finished_message:
    lea rcx, [rel text_finished]
    call append_text
    call close_process_handles
.done:
    WEPILOGUE

close_process_handles:
    WPROLOGUE
    mov rbx, [pipe_out_read]
    test rbx, rbx
    jz .in_write
    mov rcx, rbx
    call CloseHandle
.in_write:
    mov rbx, [pipe_in_write]
    test rbx, rbx
    jz .out_write
    mov rcx, rbx
    call CloseHandle
.out_write:
    mov rbx, [pipe_out_write]
    test rbx, rbx
    jz .in_read
    mov rcx, rbx
    call CloseHandle
.in_read:
    mov rbx, [pipe_in_read]
    test rbx, rbx
    jz .thread
    mov rcx, rbx
    call CloseHandle
.thread:
    mov rbx, [thread_handle]
    test rbx, rbx
    jz .process
    mov rcx, rbx
    call CloseHandle
.process:
    mov rbx, [process_handle]
    test rbx, rbx
    jz .clear
    mov rcx, rbx
    call CloseHandle
.clear:
    mov qword [pipe_out_read], 0
    mov qword [pipe_out_write], 0
    mov qword [pipe_in_read], 0
    mov qword [pipe_in_write], 0
    mov qword [thread_handle], 0
    mov qword [process_handle], 0
    mov qword [pending_length], 0
    mov dword [child_done], 0
    WEPILOGUE
