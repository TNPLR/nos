.code16
.include "asm_utility.h"
.section .text
# Init all the registers
xorw %ax, %ax
xorw %bx, %bx
xorw %cx, %cx
xorw %dx, %dx

movw $0x7E0, %ax
movw %ax, %es
movw %ax, %ds

movw $0, %ax
movw %ax, %ss

movw $0x7c00, %sp

# Print
movw $HELLO_MESSAGE, %bp
call print
call getRam

# Clear Interrupt Flag
cli

# A20
inb $0x92, %al
orb $2, %al
outb %al, $0x92

# LGDT
lgdt GDTR

# Enter Protected Mode
movl %cr0, %eax
orl $1, %eax
movl %eax, %cr0

ljmp $0x08, $(0x7E00+OS_PMODE)
.code32
OS_PMODE:
  movw $0x10, %ax
  movw %ax, %ss
  movw %ax, %ds
  movw %ax, %es
  movw %ax, %fs
  movw %ax, %gs

  movl $0x7c00, %eax
  movl %eax, %esp
  movl $(0x7E00+PMODE_MESSAGE), %esi
  call print32

  call searchKernel

  movl %eax, %edx
  jmp *%edx

  hlt
.code16
# ====================================================================
# print function
# ====================================================================
# es:bp as Message position, zero-term string
print:
  # Get cursor position (Return dh = row, dl = column ...)
  movb $0x03, %ah
  movb $0, %bh
  int $0x10

  # Count String
  xorw %cx, %cx
  movw %bp, %si
  cnt:
  movb (%si), %ah
  cmpb $0, %ah
  je cnt_exit
  incw %si
  incw %cx
  jmp cnt
  cnt_exit:

  # Print
  # (ah = 0x13, al = 0x0, bh = 0, bl = 7, cx = strlen, dh:dl=row:column, es:bp=7c0:Message)
  movw $0x1300, %ax
  movw $0x7, %bx
  int $0x10

  # Move cursor to next line
  incb %dh
  xorb %dl, %dl
  movb $0, %bh
  movb $0x02, %ah
  int $0x10
  ret
#=====================================================================

#=====================================================================
# int 0xE820
# (eax = 0xe820) (ebx = 0) (es:di = smap) (ecx = buffer size = 0x200) (edx = smap)
#=====================================================================
getRam:
  movl $0xe820, %eax
  xorl %ebx, %ebx
  movw $0x3E00, %di
  movl $32, %ecx
  movl $0x534D4150, %edx
getRam_loop:
  int $0x15
  movl %eax, %edx
  movl $0xe820, %eax
  movl $32, %ecx
  addw $32, %di
  cmpl $0, %ebx
  jne getRam_loop
  ret
.code32
HELLO_MESSAGE:
.asciz "Hello world!"
PMODE_MESSAGE:
.asciz "We're in Protected Mode Now!!"
GDT_NUL:
  .long 0
  .long 0
GDT_CODE32:
  .long 0x0000FFFF
  .long 0x00CF9A00
GDT_DATA32:
  .long 0x0000FFFF
  .long 0x00CF9200
GDTR:
  .word 24
  .long GDT_NUL+0x7E00
