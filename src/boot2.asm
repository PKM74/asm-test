;====================;
;Copyright (C) 2024  ;
;Tyler McGurrin      ;
;Under LGPL V2.1     ;
;====================;
[BITS 16]
%define ENDL 0x0D, 0x0A

main:
	cli
	;setup stack
	mov ax, ds
	mov ss, ax
	mov sp, 0
	mov bp, sp
	sti
	xor dh,dh
	push dx

	mov si, msg_done
	call print
	jmp load
	
print:
        lodsb
        or al, al               ; zero is end of string
        jz .done                ; get out
        mov ah, 0x0E
        mov bh, 0
        int 0x10
        jmp print
.done:
        ret

load:
	mov si, msg_loading
	call print
	mov si, msg_fsload
	call print
	jmp loaderrfs



loaderrfs:
	mov si, loaderrfs_msg
	call print
	jmp wait_reboot
loaderr:
    mov si, loaderr_msg
    call print
    jmp wait_reboot    
wait_reboot:
        mov si, reboot_msg
        call print
        mov ah, 0
        int 16h                 ; wait untill keypress
        jmp 0FFFFh:0    ; jump to begining of BIOS

; Messages
; | [Name] | [Type] | [Text/Data] |
msg_loading:	db 'Loading Second Phase...', ENDL, 0
msg_fsload:		db 'Setting Up Filesystem...', ENDL, 0
reboot_msg:     db ENDL, 'Press Any Key to Reboot...', ENDL, 0
loaderr_msg:    db 'Loading Failed!', ENDL, 0
loaderrfs_msg:  db 'ERROR: 1', ENDL, 'Failed to Initialize Filesystem', ENDL, 0
msg_done:       db '		Done!', ENDL, 0
