extrn LoadIconA			: proc
extrn LoadCursorA		: proc
extrn GetModuleHandleA	: proc
extrn GetCommandLineA	: proc
extrn ExitProcess		: proc
extrn RegisterClassExA	: proc
extrn CreateWindowExA	: proc
extrn ShowWindow		: proc
extrn UpdateWindow		: proc
extrn GetMessageA		: proc
extrn TranslateMessage	: proc
extrn DispatchMessageA	: proc
extrn DefWindowProcA	: proc
extrn SetTimer			: proc
extrn PostQuitMessage	: proc
extrn EnumWindows		: proc
extrn OpenProcess		: proc
extrn TerminateProcess	: proc
extrn CloseHandle		: proc
extrn GetWindowThreadProcessId : proc
extrn K32GetProcessImageFileNameA : proc

CS_HREDRAW				equ 2
CS_VREDRAW				equ 1
WS_EX_WINDOWEDGE		equ 100h
WS_EX_CLIENTEDGE		equ 200h
WS_EX_OVERLAPPEDWINDOW	equ WS_EX_WINDOWEDGE or WS_EX_CLIENTEDGE
WS_OVERLAPPED			equ 0
WS_CAPTION				equ 00C00000h
WS_SYSMENU				equ 00080000h
WS_VISIBLE				equ 10000000h
CW_USEDEFAULT			equ 80000000h   
NULL					equ 0
WM_QUIT					equ 12h
STANDARD_RIGHTS_REQUIED equ 0F0000h
SYNCHRONIZE				equ 100000h
PROCESS_ALL_ACCESS		equ STANDARD_RIGHTS_REQUIED or SYNCHRONIZE or 0FFFFh

POINT STRUCT
    x                   dd ?
    y                   dd ?
POINT ENDS

MSG STRUCT
    hwnd                dq ?
    message             dd ?
    wParam              dq ?
    lParam              dq ?
    time                dd ?
    pt                  POINT<>
MSG ENDS

WNDCLASSEX STRUCT
    cbSize              dd ?
    style               dd ?
    lpfnWndProc         dq ?
    cbClsExtra          dd ?
    cbWndExtra          dd ?
    hInstance           dq ?
    hIcon               dq ?
    hCursor             dq ?
    hbrBackground       dq ?
    lpszMenuName        dq ?
    lpszClassName       dq ?
    hIconSm             dq ?
WNDCLASSEX ENDS

.data
aClassName  db          "GUIASM",0
aAppName    db          "Anti browser",0
ProcKill	db			"notepad.exe", 0
AppChrome	db			"chrome.exe", 0
AppmsEdge	db			"msedge.exe", 0
AppEdge		db			"MicrosoftEdge.exe", 0
AppFireFox	db			"firefox.exe", 0
AppOpera	db			"opera.exe", 0
AppBrave	db			"brave.exe", 0
AppIE		db			"iexplore.exe", 0


.data?
;
nameProc	db 512 dup (?)
phIcon      dq ?
phCursor    dq ?
WndclsEx    WNDCLASSEX  <>
message     MSG         <>
hwnd        dq ?
dwProcessId	dd ?
hProcess	dq ?
fResult		db ?
.code
_start proc
	push rbp
	mov rbp, rsp
	sub rsp, 20h

	mov rdx, 32512
	xor rcx, rcx
	call LoadIconA
	mov phIcon, rax

	mov rdx, 32512
	xor rcx, rcx
	call LoadCursorA
	mov phCursor, rax

	xor rcx, rcx
	call GetModuleHandleA
	mov rcx, rax
	call GetCommandLineA
	mov r8, rax
	mov r9, 10
	xor rdx, rdx
	call wWinMain
	xor rcx, rcx
	call ExitProcess

	leave
	ret
_start endp

;start code
wWinMain proc
	push rbp
	mov rbp, rsp
	sub rsp, 60h
	mov [rbp + 10h], rcx	;hInstance
	mov [rbp + 18h], rdx	;hPrevInstance
	mov [rbp + 20h], r8		;lpCmdLine
	mov [rbp + 28h], r9		;nCmdShow
	; try to register class
	lea rdx, aClassName
	lea r12, WndProc
	mov r11, phIcon
	mov WndClsEx.cbSize, sizeof WNDCLASSEX
	mov WndClsEx.style, CS_HREDRAW or CS_VREDRAW
	mov WndClsEx.lpfnWndProc, r12
	mov WndClsEx.hInstance, rcx
	mov WndClsEx.hbrBackground, 6
	mov WndClsEx.lpszClassName, rdx
	mov WndClsEx.hIconsm, r11
	lea rcx, WndClsEx
	call RegisterClassExA
	cmp ax, 0
	je exit
	; if success try to create window
	mov rdx, [rbp + 10h]
	mov dword ptr [rsp + 20h], CW_USEDEFAULT
	mov dword ptr [rsp + 28h], CW_USEDEFAULT
	mov dword ptr [rsp + 30h], 300
	mov dword ptr [rsp + 38h], 100
	mov dword ptr [rsp + 40h], NULL
	mov dword ptr [rsp + 48h], NULL
	mov qword ptr [rsp + 50h], rdx
	mov dword ptr [rsp + 58h], NULL
	mov rcx, WS_EX_OVERLAPPEDWINDOW
	lea rdx, aClassName
	lea r8, aAppName
	mov r9, WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_VISIBLE
	call CreateWindowExA
	mov hwnd, rax
	mov rcx, hwnd
	mov rdx, [rbp + 28h]
	call ShowWindow
	mov rcx, hwnd
	call UpdateWindow
;loop 
messageLoop:
	lea rcx, message
	xor rdx, rdx
	xor r8, r8
	xor r9, r9
	call GetMessageA
	cmp rax, 0
	jz exit
	lea rcx, message
	call TranslateMessage
	lea rcx, message
	call DispatchMessageA
	jmp messageLoop
exit:
	xor rax, rax
	leave
	ret
wWinMain endp

WndProc proc
	push rbp
	mov rbp, rsp
	sub rsp, 20h
	mov [rbp + 10h], rcx	;hwnd
	mov [rbp + 18h], rdx	;msg
	mov [rbp + 20h], r8		;wparam
	mov [rbp + 28h], r9		;lparam
	cmp qword ptr [rbp + 18h], 1
	je WM_CREATE
	cmp qword ptr [rbp + 18h], 113h
	je WM_TIMER
	cmp qword ptr [rbp + 18h], 2
	je WM_DESTROY
	call DefWindowProcA
	jmp WndProcExit
	WM_CREATE:
		mov rcx, [rbp + 10h]
		mov rdx, 1
		mov r8, 5000 ;set time = 5s
		xor r9, r9
		call SetTimer
		jmp WndProcExit
	WM_TIMER:
		lea rcx, EnumWinProc 
		xor rdx, rdx
		call EnumWindows
		jmp WndProcExit
	WM_DESTROY:
		mov rcx, WM_QUIT
		call PostQuitMessage
		jmp WndProcExit
	WndProcExit:
	leave
	ret
WndProc endp

EnumWinProc proc
	push rbp
	mov rbp, rsp
	sub rsp, 20h
	mov [rbp + 10h], rcx	;hwnd
	mov [rbp + 18h], rdx	;lparam
	lea rdx, dwProcessId
	call GetWindowThreadProcessId
	mov rcx, PROCESS_ALL_ACCESS
	xor rdx, rdx
	mov r8d, dwProcessId
	call OpenProcess
	mov hProcess, rax
	cmp hProcess, 0
	je EnumWinProcExit
	mov rcx, hProcess
	lea rdx, nameProc
	mov r8, 512
	call K32GetProcessImageFileNameA
	;checkChrome
	lea rdx, AppChrome
	lea rcx, nameProc
	call strcmp
	cmp rax, 1
	jz KillProc
	;check edge
	lea rdx, AppEdge
	lea rcx, nameProc
	call strcmp
	cmp rax, 1
	jz KillProc
	lea rdx, AppmsEdge
	lea rcx, nameProc
	call strcmp
	cmp rax, 1
	jz KillProc
	;check firefox
	lea rdx, AppFireFox
	lea rcx, nameProc
	call strcmp
	cmp rax, 1
	jz KillProc
	;check opera
	lea rdx, AppFireFox
	lea rcx, nameProc
	call strcmp
	cmp rax, 1
	jz KillProc
	;check brave
	lea rdx, AppBrave
	lea rcx, nameProc
	call strcmp
	cmp rax, 1
	jz KillProc
	; check IE
	lea rdx, AppIE
	lea rcx, nameProc
	call strcmp
	cmp rax, 1
	jz KillProc
	jmp EnumWinProcExit
	KillProc:
	mov rcx, hProcess
	xor rdx, rdx
	call TerminateProcess
	mov rcx, hProcess
	call CloseHandle
	EnumWinProcExit:
	mov rax, 1
	leave
	ret
EnumWinProc endp

strcmp proc    ;strcmp(*str, *str)
	push rbp
	mov rbp, rsp
	sub rsp, 20h
	mov [rbp + 10h], rcx
	mov [rbp + 18h], rdx
	mov rcx, [rbp + 10h]
	call slen
	mov [rbp - 8h], rax
	mov rcx, [rbp + 18h]
	call slen
	mov [rbp - 10h], rax

	mov rsi, [rbp + 10h]
	mov rax, [rbp - 8h]
	add rsi, rax
	mov rdi, [rbp + 18h]
	mov rax, [rbp - 10h]
	add rdi, rax
	xor rdx, rdx
	xor rax, rax
	mov rcx, [rbp - 10h]
  
	cmploop:
	mov dl, [rdi]
	mov dh, [rsi]
	cmp dl, dh
	jnz strcmpExit
	dec rdi
	dec rsi
	dec rcx
	jnz cmploop
	mov rax, 1
	strcmpExit:
	leave
	ret
strcmp endp

slen proc
  push rbp
  mov rbp, rsp
  sub rsp, 20h
  push rdi
  push rsi
  mov [rbp -8], rcx
  mov rsi, [rbp - 8]
  xor rax, rax
  xor rcx, rcx
  L1:
  mov cl, byte ptr [rsi+rax]
  cmp cl, 0
  je sLE
  inc rax
  jmp L1
  sLE:
  leave
  ret
slen endp

end
