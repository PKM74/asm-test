;====================;
;Copyright (C) 2024  ;
;Tyler McGurrin		 ;
;Under LGPL V2.1	 ;
;====================;
[ORG 0x7C00]
[BITS 32]
main:
	xor ax, ax 		; zero out AX
	mov ds, ax

	mov si, msg
	call prin
	cld
print:
	lodsb
	or al, al 		; zero is end of string
	jz hang		 	; get out
	mov ah, 0x0E
	mov bh, 0
	int 0x10
	jmp print


;test_func:
;	mov si, test_msg
;	call print
;	cld
hang:
	jmp hang
	
; Messages
; [Name]  [Type] | [Text]   |
test_msg	db 'TESTING...', 13, 10, 0
msg			db 'Loading Main Functions...', 13, 10, 0
; Setup for legacy BIOSes and filling the rest of the .bin file with zeros
done:
	ret

	times 510-($-$$) db 0
    db 0x55
    db 0xAA
