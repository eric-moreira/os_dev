[BITS 16]
[ORG 0x7e00]

start:
.clear_screen:
    mov ah, 0x00      ; função 00h = set video mode
    mov al, 0x03      ; modo 03h = texto 80x25, colorido
    int 0x10          ; BIOS video interrupt
 
    mov ah, 0x13
    mov al, 1
    mov bx,0xa
    xor dx,dx
    mov bp,Message
    mov cx,MessageLen
    int 0x10
end:
    hlt
    jmp end

Message: db "loader start"
MessageLen: equ $-Message

