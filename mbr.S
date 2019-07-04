.code16
.section .text
# Init all the registers
xorw %ax, %ax
xorw %bx, %bx
xorw %cx, %cx
xorw %dx, %dx

movw $0x7C0, %ax
movw %ax, %es
movw %ax, %ds
movw %ax, %ss

# Reset Disk (int 0x13, ah = 0x0, dl = 0x80 (first disk))
movb $0, %ah
movb $0x80, %dl
int $0x13

# Read Number 3 and 32 sectors (CHS)
# (int 0x13, ah = 0x2, al = 32, ch = 0, cl = 3, dh = 0, dl = 0x80, ES:BX = 0x7E00)
movw $0x200, %bx
movb $0x2, %ah
movb $32, %al
movb $0x0, %ch
movb $0x3, %cl
movb $0x0, %dh
movb $0x80, %dl
int $0x13

jc ERROR
ljmp $0x7e0, $0x0
ERROR:
jmp .
.org 0x1BE, 0x0
.byte 0x80
.byte 0x0
.byte 0x0
.byte 0x0
.byte 0x83
.byte 0
.byte 0
.byte 0
.long 16
.long 122864
.org 0x1FE, 0x0
.byte 0x55
.byte 0xAA
