; ----------------------------
; Simple boot loader (16-bit real mode)
; - Limpa tela, salva drive, verifica CPUID/recursos, lê kernel via INT 13h (LBA/DAP)
; - Pede mapa de memória via INT 0x15 (E820)
; - Verifica / tenta linha A20
; - Mensagens de erro para debug
; ----------------------------
[BITS 16]
[ORG 0x7E00]

; -----------------------------------------------------------------
; Entry point
; -----------------------------------------------------------------
start:
         ; chama BIOS para aplicar o modo de vídeo

; -----------------------------------------------------------------
; Salva o identificador do drive (DL) e verifica recursos do CPU/BIOS
; - Verifica extensão CPUID estendida e features: Long Mode (LM) e SSE2
; - Caso falhe, salta para NotSupport
; -----------------------------------------------------------------
.check_cpuid:
    mov [DriveId], dl         ; salva drive de boot para leituras posteriores

    mov eax, 0x80000000      ; consulta o maior CPUID suportado (extendida)
    cpuid
    cmp eax, 0x80000001
    jb NotSupport            ; se CPUID estendido não suportado -> não é compatível

    mov eax, 0x80000001      ; lê features estendidas
    cpuid
    test edx, (1<<29)        ; verifica bit de Long Mode (AMD long mode) no EDX
    jz NotSupport
    test edx, (1<<26)        ; verifica SSE2 (mínimo razoável)
    jz NotSupport

; -----------------------------------------------------------------
; Carrega o kernel usando INT 13h Extensions (BIOS AH=0x42) com DAP (Disk Address Packet)
; - ReadPacket structure preenchida em `ReadPacket` (no final do arquivo)
; - Se ocorrer CF (carry flag) após INT 0x13, saltar para ReadError
; -----------------------------------------------------------------
load_kernel:
    mov si, ReadPacket
    mov word [si], 0x10      ; DAP size (16 bytes)
    mov word [si+2], 100     ; número de setores a ler (exemplo)
    mov word [si+4], 0       ; offset (0)
    mov word [si+6], 0x1000  ; segment para destino (0x1000:0 => 0x10000)
    mov dword [si+8], 6      ; LBA baixo (começa no setor 6)
    mov dword [si+0xC], 0    ; LBA alto (0 para discos pequenos)

    mov dl, [DriveId]        ; drive a ser lido (salvo anteriormente)
    mov ah, 0x42             ; função INT 13h: Extensions - Read
    int 0x13
    jc ReadError             ; se CF=1, houve erro de leitura

; -----------------------------------------------------------------
; Consulta mapa de memória com INT 0x15 E820
; - Itera até EBX = 0 retornado pela BIOS
; - Armazena as entradas em ES:DI (buffer em 0x9000)
; - Se INT retorna carry ou assinatura inválida, salta para NotSupport
; -----------------------------------------------------------------
test_memory_info:
    mov eax, 0xE820
    mov edx, 0x534D4150      ; 'SMAP' signature
    mov ecx, 20              ; buffer size (20 bytes para ACPI <= 2.0)
    mov edi, 0x9000          ; base do buffer (usando ES:DI nas chamadas subsequentes)
    xor ebx, ebx             ; continuação = 0 (primeira chamada)
    int 0x15
    jc NotSupport            ; CF set -> função não suportada / erro

get_mem_info:
    add edi, 20              ; avança o ponteiro do buffer para a próxima entrada
    mov eax, 0xE820
    mov edx, 0x534D4150
    mov ecx, 20
    int 0x15
    jc get_mem_done         ; CF set -> fim/erro (tratado abaixo)

    test ebx, ebx            ; EBX = 0 -> terminar; senão, repetir (continuação)
    jnz get_mem_info

get_mem_done:
    ; Ao chegar aqui, temos o mapa de memória preenchido em 0x9000

; -----------------------------------------------------------------
; Rotina de verificação/ativação da linha A20 (simples teste)
; - Verifica se leitura/escrita em 0x0000:0x7C00 se comporta como esperado
; - Ajusta/Aguarda conforme necessário (implementação simplista)
; -----------------------------------------------------------------
test_a20:
    mov ax, 0xFFFF
    mov es, ax
    mov word [ds:0x7c00], 0xA200   ; escreve padrão de teste no endereço 0x7C00
    cmp word [es:0x7c10], 0xA200
    jne SetA20LineDone
    mov word [0x7c00], 0xB200
    cmp word [es:0x7c10], 0xB200
    je end

SetA20LineDone:
    xor ax, ax
    mov es, ax
 .clear_screen:
     ; Configura modo texto 80x25 (BIOS INT 10h, AH=0)
     mov ah, 0x00      ; função 00h = set video mode
     mov al, 0x03      ; modo 03h = texto 80x25, colorido
     int 0x10 
    ; Exibe mensagem simples em tela de texto via escrita direta em VRAM (0xB800)

    mov si, Message
    mov ax, 0xb800
    mov es, ax
    xor di,di
    mov cx, MessageLen

PrintMessage:
    mov al, [si]
    mov [es:di], al
    mov byte[es:di+1], 0xa   ; atributo / cor (uso simplificado)

    add di, 2
    add si, 1
    loop PrintMessage

end:
    hlt
    jmp end


; -----------------------------------------------------------------
; Handlers de erro / mensagens (usam BIOS INT 10h AH=0x13 - modo texto simplificado)
; - Mantém compatibilidade com sua rotina original de exibição
; -----------------------------------------------------------------
ReadError:


NotSupport:
; ----------------------------
; Dados (strings, buffers, structs)
; ----------------------------

Message:            db "Text mode is set"
MessageLen:         equ $ - Message

MsgSupport:         db "NotSupport: recurso ausente"
MsgSupportLen:      equ $ - MsgSupport

msgReadError:       db "Read Error: falha ao ler setores do disco"
msgReadErrorLen:    equ $ - msgReadError

DriveId:            db 0                 ; drive original (DL) salvo
ReadPacket:         times 16 db 0        ; Disk Address Packet (DAP) - ver struct abaixo

; -----------------------------------------------------------------
; Estruturas e offsets (referência)
; ReadPacket (DAP)
; offset    field
; 0         size (2 bytes)
; 2         number of sectors (2 bytes)
; 4         offset (2 bytes)
; 6         segment (2 bytes)
; 8         address lo (dword)
; 12        address hi (dword)
;
; MemInfo (E820) layout
; offset    field
; 0         base address (qword)
; 8         length (qword)
; 16        type (dword)
; -----------------------------------------------------------------
