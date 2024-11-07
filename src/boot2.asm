;====================;
;Copyright (C) 2024  ;
;Tyler McGurrin      ;
;Under LGPL V2.1     ;
;====================;
[BITS 16]
%define ENDL 0x0D, 0x0A
%define LF 
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

	mov si, msg_timecheck
	call print
	call timecheck
	mov si, msg_done
	call print
	mov si, timedata
	call print
	jmp wait_reboot

	
timecheck:	; Function to check the current time according to the CMOS
push cs
push cs
pop ds
pop es

mov ah,03h ;No.3 sub in 10h interrupt,get cursor
int 10h;Return bh=page num,dh=line num,dl=column number
mov di,timestore
;save bh,dh,dl
mov [es:di],bx
mov [es:di+2],dx

refresh_datetime:
;restore page\line\col number (bh,dh,dl)
mov bx,[es:di]
mov dx,[es:di+2]

;reset to old page\line\column number
mov ah,02h ;set cursor
int 10h

;read year
mov al,9
mov ah,2
mov si, timedata
call read_cmos_bcd

;read month
mov al,8
mov ah,1
inc si
call read_cmos_bcd

;read date
mov al,7
mov ah,1
inc si
call read_cmos_bcd

;read hour
mov al,4
mov ah,1
inc si
call read_cmos_bcd

;read munite
mov al,2
mov ah,1
inc si
call read_cmos_bcd

;read second
mov al,0
mov ah,1
inc si
call read_cmos_bcd

mov dx,timedata ;string start addr
mov ah,9
int 21h

mov ah, 0

;dead loop is not a resolution,it cause cpu turn to 100%
;jmp refresh_datetime
mov ax,4c00h
int 21h

read_cmos_bcd:
;Args:
;al => start addr
;Return:
;Write converted string in ds:si
;si point to the end of string after called
push cx

out 70h,al
in al,71h ;read one byte
mov ah,al
;For convenience
;al store byte high 4 bit
;ah store byte low 4 bit
;Because,human read order
;High bit put low addr
;Example:string "12","1" must store in low addr in memory

mov cl,4
shr al,cl ;only retain high 4 bit
and ah,00001111b ;clear high 4 bit to 0

add ah,30h
add al,30h

mov [ds:si],ax
add si,2

pop cx
ret

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
msg_timecheck:	db 'Checking Current System Time...', 0
reboot_msg:     db ENDL, 'Press Any Key to Reboot...', ENDL, 0
loaderr_msg:    db 'Loading Failed!', ENDL, 0
loaderrfs_msg:  db 'ERROR: 1', ENDL, 'Failed to Initialize Filesystem', ENDL, 0
msg_done:       db 'Finished!', ENDL, 0
timedata		db "00-00-00 00:00:00$"
timestore		db 16
