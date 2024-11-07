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


	jmp .done

.done:
	mov si, msg
	call print
	hlt

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
reboot_msg:             db 'Press Any Key to Reboot...', ENDL, 0
loaderr_msg:    		db 'Loading Failed!', ENDL, 0
msg:                    db 'Done!', ENDL, 0
main_cluster:   		dw 0
