STRUC sigact
    .handler resq 1
    .flag    resq 1
    .restorer resq 1
    .mask resq 16
ENDSTRUC

STRUC sigval
    .int resd 1
    .ptr resd 1
ENDSTRUC

STRUC sigthd
    .function resd 1
    .attribute resd 1
ENDSTRUC

STRUC sigun
    .pad resd 11
    .tid resd 1
    .thread resb sigthd_size
ENDSTRUC

STRUC sigev
    .value resb sigval_size
    .signo resd 1
    .notify resd 1
    .union  resb sigun_size
ENDSTRUC

STRUC timespec
    .sec resq 1
    .nsec resq 1
ENDSTRUC

STRUC itimerspec
    .value resb  timespec_size
    .interval resb timespec_size
ENDSTRUC

STRUC linux_dirent64
	.d_ino resq 1
	.d_off resq 1
	.d_reclen resw 1
	.d_type resb 1
	.d_name resb 1
ENDSTRUC

section .data
dirpath db "/proc/", 0
rFile	db "/status", 0
msgKill db "Killed: ", 0
msgFound db "Found: ", 0
msgLF db 0ah, 0

section .bss
buf resb 131072
nread resq 1
bpos resq 1
d resq 1
namep resb 256
dPath resb 256
buf2 resb 60000
pid resb 8
timeid resq 1
ts resq itimerspec_size
act resb sigact_size
ev resb sigev_size

section .text
global _start
_start:

main:
        push rbp
        mov rbp, rsp

        mov qword [act + sigact.handler], killproc
        mov qword [act + sigact.flag], 4000000h     ; SA_RESTORER
        mov qword [act + sigact.restorer], restore
        mov r10, 8                  ; size_t
        xor rdx, rdx                ; struct sigaction *
        mov rsi, act              	; const struct sigaction *
        mov rdi, 10                 ; int = SIGUSR1
        mov rax, 0Dh                ; sys_rt_sigaction
        syscall
        cmp rax, -1
        jz .exit

        mov dword [ev + sigev.notify], 0    ; sigevent.sigev_notify
        mov dword [ev + sigev.signo], 10    ; sigevent.sigev_signo = SIGUSR1
        mov rax, ev               ; sigevent
        mov rdx, timeid           ; timer_t * created_timer_id
        mov rsi, rax                ; struct sigevent *timer_event_spec
        xor rdi, rdi                ; clockid_t which_clock
        mov rax, 0DEh               ; sys_timer_create
        syscall
        test rax, rax
        jnz .exit

        mov qword [ts + itimerspec.value + timespec.sec], 10     ; itimerspec.it_value.tv_sec
        mov qword [ts + itimerspec.value + timespec.nsec], 0    ; itimerspec.it_value.tv_nsec
        mov qword [ts + itimerspec.interval + timespec.sec], 10  ; itimerspec.it_interval.tv_sec
        mov qword [ts + itimerspec.interval + timespec.nsec], 0 ; itimerspec.it_interval.tv_nsec
        xor     r10, r10                ; struct __kernel_itimerspec *old_setting
        mov     rdx, ts               	; const struct __kernel_itimerspec *new_setting
        xor     rsi, rsi                ; int flags
        mov     rdi, [timeid]           ; timer_t timer_id
        mov     rax, 0DFh               ; sys_timer_settime
        syscall
        test    rax, rax
        jnz     .exit
    .looproc:;
        mov     rax, 22h                ; sys_pause
        syscall
        jmp     .looproc

.exit:
        mov rax, 0x3c
        syscall
        ret

restore:
        mov     rax, 15                 ; sys_rt_sigreturn
        syscall
        ret

test:
	push rbp
	mov rbp, rsp
	mov rdi, msgKill
	call print
	leave
	ret

killproc:
	push rbp
	mov rbp, rsp
	push rdi
	push rsi
	push rbx
	mov rdi, 0
	mov [bpos], rdi
	mov rdi, dirpath
	mov rsi, 0x100000 ; O_RONLY | O_DIRECTORY
	mov rax, 0x2
	syscall
	cmp rax, -1
	je .exit
	mov rdi, rax
	mov rsi, buf
	mov rdx, 0x20000
	mov rax, 0xd9
	syscall
	mov [nread], rax
	xor rax, rax
.l1:
	mov rax, buf
	add rax, [bpos]
	mov rcx, [bpos]
	add cx, [rax + linux_dirent64.d_reclen]
	mov [bpos], rcx
	add rax, 0x13
	;======================================
	mov rdi, rax
	call getpname
	call isnum
	cmp rax, 0
	je .con
	call strcat

	mov rdi, dPath
	mov rsi, 0
	mov rdx, 0
	mov rax, 2
	syscall

	mov rdi, rax
	mov rax, 0
	mov rsi, buf2
	mov rdx, 60000
	syscall

	mov rdi, buf2
	call findProc
	cmp rax, 0
	je .con
	mov rdi, buf2
	call findPid

	mov rdi, pid
	call atoi
	mov rdi, rax
	mov rax, 0xc8
	mov rsi, 9
	syscall
	cmp rax, 0
	jne .con
	mov rdi, msgFound
	call print
	mov rdi, pid
	call print
	mov rdi, msgLF
	call print
	mov rdi, msgKill
	call print
	mov rdi, pid
	call print
	mov rdi, msgLF
	call print
	mov rdi, msgLF
	call print
	;======================================
.con:
	mov rax, [bpos]
	mov rcx, [nread]
	cmp rax, rcx
	jl .l1
.exit:
	pop rbx
	pop rsi
	pop rdi
	leave
	ret

write:
        mov rax, 1
        syscall
        ret

slen:
        push rbp
        mov rbp, rsp
        push rdi
        push rsi
        push rbx
        xor rax, rax
        xor rdx, rdx
.slenL:
        mov dl, byte [rdi + rax]
        cmp dl, 0
        jz .slenE
        inc rax
        jmp .slenL
.slenE:
        pop rbx
        pop rsi
        pop rdi
        leave
        ret

getpname:
	push rbp
	mov rbp, rsp
	push rdi
	push rsi
	push rbx

	xor rax, rax
	xor rdx, rdx
.l1:
	mov dl, byte [rdi + rax]
	cmp dl, 0
	jz .l2
	mov [namep + rax], dl
	inc rax
	jmp .l1
.l2:
	mov dl, 0
	mov [namep + rax], dl
	pop rbx
	pop rsi
	pop rdi
	leave
	ret

isnum:
	push rbp
	mov rbp, rsp
	push rdi
	push rsi
	push rbx
	call slen
	mov rcx, rax
	xor rdx, rdx
	xor rax, rax
.l1:
	mov dl, byte [rdi + rax]
	cmp dl, 0x30
	jge .check9
	jmp .no
.check9:
	cmp dl, 0x57
	jle .okay
.no:
	jmp .exit
.okay:
	inc rax
	dec rcx
	jnz .l1
.exit:
	pop rbx
	pop rsi
	pop rdi
	leave
	ret

print:
        push rbp
        mov rbp, rsp
        push rdi
        push rsi
        push rbx
        call slen
        mov rdx, rax
        mov rsi, rdi
        mov rdi, 0
        call write
        pop rbx
        pop rsi
        pop rdi
        leave
        ret


strcat:
	push rbp
	mov rbp, rsp
	push rdi
	push rsi
	push rbx

	mov rdi, dirpath
	call slen
	mov rcx, rax
	mov rdi, namep
	call slen
	mov rbx, rax
	mov rdi, rFile
	call slen
	mov r10, rax
	xor rax, rax
	xor rdx, rdx
.l1:
	mov dl, byte [dirpath + rax]
	mov [dPath + rax], dl
	inc rax
	dec rcx
	jnz .l1
	mov rcx, rbx
	xor r8, r8
.l2:
	mov dl, byte [namep + r8]
	mov [dPath + rax], dl
	inc rax
	inc r8
	dec rcx
	jnz .l2
	xor r8, r8
	mov rcx, r10
.l3:
	mov dl, byte [rFile + r8]
	mov [dPath + rax], dl
	inc rax
	inc r8
	dec rcx
	jnz .l3

	pop rbx
	pop rsi
	pop rdi
	leave
	ret

findProc:
	push rbp
	mov rbp, rsp
	push rdi
	push rdi
	push rbx

	mov dx, word [buf2 + 6]
	cmp dx, "nc"
	je .yes
	jmp .no
.yes:
	mov rax, 1
	jmp .exit
.no:
	mov rax, 0
.exit:
	pop rbx
	pop rsi
	pop rdi
	leave
	ret

findPid:
	push rbp
	mov rbp, rsp
	push rdi
	push rdi
	push rbx
	xor rax, rax
.l1:
	mov dl, byte [buf2 + rax]
	cmp dl, "P"
	je .getPid
	inc rax
	jmp .l1
.getPid:
	add rax, 5
	xor rcx, rcx
.l2:
	mov dl, [buf2 + rax]
	cmp dl, 0xa
	je .exit
	mov [pid + rcx], dl
	inc rcx
	inc rax
	jmp .l2
.exit:
	mov dl, 0
	mov [pid + rcx], dl
	pop rbx
	pop rsi
	pop rdi
	leave
	ret

atoi:
        push rbp
        mov rbp, rsp
        sub rsp, 20h
        push rdi
        push rsi
        push rbx
        mov [rbp - 8], rdi
        xor rax, rax
        xor rcx, rcx
        xor rdi, rdi
        mov rbx, 10
        mov rsi, [rbp - 8]
.atoiL1:
        xor rdx, rdx
        mov cl, [rsi]
        cmp cl, 20h
        je .atoiE
        cmp cl, 0ah
        je .atoiE
	cmp cl, 0
	je .atoiE
        sub cl, 30h
        add rax, rcx
        mul rbx
        inc rsi
        inc rdi
        jmp .atoiL1
.atoiE:
        mov rcx, rdi
        div rbx
        pop rbx
        pop rsi
        pop rdi
        leave
        ret
