;====================;
;Copyright (C) 2024  ;
;Tyler McGurrin		 ;
;Under LGPL V2.1	 ;
;====================;
[ORG 0x7C00]
[BITS 16]
%define ENDL 0x0D, 0x0A
; FAT12 Header
jmp short main
nop

bdb_oem:                    db 'MSWIN4.1'           ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880                 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                    ; 9 sectors/fat
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebr_drive_number:           db 0                    ; 0x00 floppy, 0x80 hdd, useless
                            db 0                    ; reserved
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; serial number, value doesn't matter
ebr_volume_label:           db 'TESTOS     '		; 11 bytes, padded with spaces
ebr_system_id:              db 'FAT12   '           ; 8 bytes, padded with spaces

; Code Starts Here

main:
	mov ax, 0 		;cannot set ES/DS directly
	mov ds, ax
	mov es, ax

	;stack setup
	mov ss, ax
	mov sp, 0x7C00

	push es
	push word .load
	retf	
	
.load:


    ; read something from floppy disk
    ; BIOS should set DL to drive number
    mov [ebr_drive_number], dl

    ; show loading message
    mov si, msg
    call print

    ; read drive parameters (sectors per track and head count),
    ; instead of relying on data on formatted disk
    push es
    mov ah, 08h
    int 13h
    jc loaderr
    pop es

    and cl, 0x3F                        ; remove top 2 bits
    xor ch, ch
    mov [bdb_sectors_per_track], cx     ; sector count

    inc dh
    mov [bdb_heads], dh                 ; head count

    ; compute LBA of root directory = reserved + fats * sectors_per_fat
    ; note: this section can be hardcoded
    mov ax, [bdb_sectors_per_fat]
    mov bl, [bdb_fat_count]
    xor bh, bh
    mul bx                              ; ax = (fats * sectors_per_fat)
    add ax, [bdb_reserved_sectors]      ; ax = LBA of root directory
    push ax

    ; compute size of root directory = (32 * number_of_entries) / bytes_per_sector
    mov ax, [bdb_dir_entries_count]
    shl ax, 5                           ; ax *= 32
    xor dx, dx                          ; dx = 0
    div word [bdb_bytes_per_sector]     ; number of sectors we need to read

    test dx, dx                         ; if dx != 0, add 1
    jz .root_dir
    inc ax                              ; division remainder != 0, add 1
                                        ; this means we have a sector only partially filled with entries

.root_dir:

    ; read root directory
    mov cl, al                          ; cl = number of sectors to read = size of root directory
    pop ax                              ; ax = LBA of root directory
    mov dl, [ebr_drive_number]          ; dl = drive number (we saved it previously)
    mov bx, buffer                      ; es:bx = buffer
    call disk_read

    ; search for kernel.bin
    xor bx, bx
    mov di, buffer
.search:
    mov si, mainfile
    mov cx, 11                          ; compare up to 11 characters
    push di
    repe cmpsb
    pop di
    je .found

    add di, 32
    inc bx
    cmp bx, [bdb_dir_entries_count]
    jl .search
    ; kernel not found
    jmp loaderr
.found:

    ; di should have the address to the entry
    mov ax, [di + 26]                   ; first logical cluster field (offset 26)
    mov [main_cluster], ax

    ; load FAT from disk into memory
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read

    ; read kernel and process FAT chain
    mov bx, LOAD_SEGMENT
    mov es, bx
    mov bx, LOAD_OFFSET

.load_loop:

    ; Read next cluster
    mov ax, [main_cluster]

    ; not nice :( hardcoded value
    add ax, 31                          ; first cluster = (kernel_cluster - 2) * secto>
                                        ; start sector = reserved + fats + root direct>
    mov cl, 1
    mov dl, [ebr_drive_number]
    call disk_read

    add bx, [bdb_bytes_per_sector]

    ; compute location of next cluster
    mov ax, [main_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx                              ; ax = index of entry in FAT, dx = cluster mod>

    mov si, buffer
    add si, ax
    mov ax, [ds:si]                     ; read entry from FAT table at index ax

    or dx, dx
    jz .even

.odd:
    shr ax, 4
    jmp .next_cluster_after

.even:
    and ax, 0x0FFF

.next_cluster_after:
    cmp ax, 0x0FF8                      ; end of chain
    jae .read_finish

    mov [main_cluster], ax
    jmp .load_loop

.read_finish:
    
    ; jump to our kernel
    mov dl, [ebr_drive_number]          ; boot device in dl

    mov ax, LOAD_SEGMENT         ; set segment registers
    mov ds, ax
    mov es, ax

    jmp LOAD_SEGMENT:LOAD_OFFSET

    jmp wait_reboot            ; should never happen

    cli                                 ; disable interrupts, this way CPU can't get out of "halt" state
    hlt


;loaderr1:
;	mov si, loaderr1_msg
;	call print
;	call loaderr
;loaderr2:
;	mov si, loaderr2_msg
;	call print
;	call loaderr
loaderr:
	mov si, loaderr_msg
	call print
	jmp wait_reboot

wait_reboot:
	;mov si, reboot_msg
	;call print
	mov ah, 0
	int 16h			; wait untill keypress
	jmp 0FFFFh:0 	; jump to begining of BIOS

.halt:
	cli
	hlt


print:
	lodsb
	or al, al 		; zero is end of string
	jz .done		; get out
	mov ah, 0x0E
	mov bh, 0
	int 0x10
	jmp print
.done:
	ret
	mov si, 0

; Disk Routines
lba_to_chs:

    push ax
    push dx

    xor dx, dx                          ; dx = 0
    div word [bdb_sectors_per_track]    ; ax = LBA / SectorsPerTrack
                                        ; dx = LBA % SectorsPerTrack

    inc dx                              ; dx = (LBA % SectorsPerTrack + 1) = sector
    mov cx, dx                          ; cx = sector

    xor dx, dx                          ; dx = 0
    div word [bdb_heads]                ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
                                        ; dx = (LBA / SectorsPerTrack) % Heads = head
    mov dh, dl                          ; dh = head
    mov ch, al                          ; ch = cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah                           ; put upper 2 bits of cylinder in CL

    pop ax
    mov dl, al                          ; restore DL
    pop ax
    ret


disk_read:

    push ax                             ; save registers we will modify
    push bx
    push cx
    push dx
    push di

    push cx                             ; temporarily save CL (number of sectors to read)
    call lba_to_chs                     ; compute CHS
    pop ax                              ; AL = number of sectors to read
    
    mov ah, 02h
    mov di, 3                           ; retry count

.retry:
    pusha                               ; save all registers, we don't know what bios modifies
    stc                                 ; set carry flag, some BIOS'es don't set it
    int 13h                             ; carry flag cleared = success
    jnc .done                           ; jump if carry not set

    ; read failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; all attempts are exhausted
    jmp loaderr


.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax                             ; restore registers modified
    ret
disk_reset:
	pusha
	mov ah, 0
    stc
    int 13h
    jc loaderr
    popa
    ret
; Messages
; | [Name] | [Type] | [Text/Data] |
reboot_msg:		db 'Press Any Key to Reboot...', ENDL, 0
loaderr_msg:	db 'Failed!', ENDL, 0
loaderr1_msg:	db 'ERR1', ENDL, 0
loaderr2_msg:	db 'ERR2', ENDL, 0
msg:			db 'Loading Main System...', 0
mainfile:		db 'BOOT    BIN'
main_cluster:	dw 0
LOAD_OFFSET		equ 0
LOAD_SEGMENT	equ 0x2000

; Setup for legacy BIOSes and filling the rest of the .bin file with zeros
	times 510-($-$$) db 0
    db 0x55
    db 0xAA

buffer:
