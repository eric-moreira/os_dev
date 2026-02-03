[BITS 16]
[ORG 0x7c00]

start:

    xor ax,ax
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov sp, 0x7c00

test_disk_extension:
    mov [DriveId], dl
    mov ah,0x41
    mov bx,0x55aa
    int 0x13
    jc  NotSupport
    cmp bx, 0xaa55
    jne NotSupport

loadloader:
                                    ;ReadPacket Struct
                                    ;offset     field
                                    ;0          size
                                    ;2          number of sectors
                                    ;4          offset
                                    ;6          segment
                                    ;8          address lo
                                    ;12         address hi
    mov si, ReadPacket
    mov word[si],0x10
    mov word[si+2],5
    mov word[si+4],0x7e00
    mov word[si+6],0
    mov dword[si+8],1
    mov dword[si+0xc],0
    mov dl,[DriveId]
    mov ah,0x42
    int 0x13
    jc ReadError

    mov dl,[DriveId]
    jmp 0x7e00              ; address we load our loader from disk


ReadError:
NotSupport:
    mov ah,0x13
    mov al, 1
    mov bx,0xa
    xor dx,dx
    mov bp,Message
    mov cx,MessageLen
    int 0x10

end:
    hlt
    jmp end


Message: db "Error in Boot process"
MessageLen: equ $-Message
DriveId: db 0
ReadPacket: times 16 db 0

times (0x1be -($-$$)) db 0

    db 80h              ;boot indicator
    db 0,2,0            ;starting CHS
    db 0f0h             ;type
    db 0ffh,0ffh,0ffh   ;ending CHS
    dd 1                ;starting sector
    dd (20*16*63-1)     ;size 10MB

dw 0xAA55
