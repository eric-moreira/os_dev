qemu-system-x86_64 -enable-kvm -cpu host -drive file=boot.img,format=raw,if=ide,index=0,media=disk -d cpu_reset,int
