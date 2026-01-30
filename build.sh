nasm -f bin -o boot.bin boot.asm
nasm -f bin -o loader.bin loader.asm
dd if=boot.bin of=boot.img bs=512 count=1 conv=notrunc seek=$[20*16*63]

dd if=loader.bin of=boot.img bs=512 count=5 seek=1 conv=notrunc
