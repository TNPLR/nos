.code16
.section .text
# Init all the registers
xorw %ax, %ax
xorw %bx, %bx
xorw %cx, %cx
xorw %dx, %dx

movw $0x7E0, %ax
movw %ax, %es
movw %ax, %ds
movw %ax, %ss

jc error

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

  movl $2, %ebx
  movl $1, %ecx
  movl $0x9000, %edi
  call readATA

jmp .
.code16
# ====================================================================
# Print Error Message
# ====================================================================
error:
  # Print Error
  movw $ERROR_MSG, %bp
  call print
  jmp .
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
  movw $0x400, %di
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
# =====================================================================
# print32 (32 bits print method)
# =====================================================================
# esi as Message position, zero-term string
print32:
  call getCursorPos
  movw %ax, %dx

  # Count String
  xorl %ecx, %ecx
  movl %esi, %edi
  cnt32:
  movb (%edi), %al
  cmpb $0, %al
  je cnt32_exit
  incl %edi
  incl %ecx
  jmp cnt32
  cnt32_exit:

  # Print
  movl $0xb8000, %edi
  andl $0xFFFF, %edx
  shll %edx
  addl %edx, %edi
  shrl %edx
  print32loop:
  movb (%esi), %al
  movb %al, (%edi)
  movb $0x07, 1(%edi)
  incl %esi
  addl $2, %edi
  loop print32loop

  # Move cursor to next line
  movw %dx, %bx
  addw $80, %bx
  call setCursorPos
  ret

# =====================================================================
# getCursorPos
# =====================================================================
getCursorPos:
  movb $0x0E, %al
  movw $0x3D4, %dx
  outb %al, %dx
  incw %dx
  inb %dx, %al
  shlw $8, %ax
  movb $0x0F, %al
  decw %dx
  outb %al, %dx
  incw %dx
  inb %dx, %al
  ret

# =====================================================================
# setCursorPos (bx = Position)
# =====================================================================
setCursorPos:
  movb $0x0F, %al
  movw $0x3D4, %dx
  outb %al, %dx
  movb %bl, %al
  incw %dx
  outb %al, %dx
  movb $0x0E, %al
  decw %dx
  outb %al, %dx
  movb %bh, %al
  incw %dx
  outb %al, %dx
  ret

# ===============================================================================
# readATA 
# ebx = LBA 28 bits
# ecx = sectors to read count
# edi = position to put
# ===============================================================================
readATA:
  movw $0x1F6, %dx
  movl %ebx, %eax
  shrl $24, %eax
  orb $0xE0, %al
  outb %al, %dx

  movw $0x1F2, %dx
  movb %cl, %al
  outb %al, %dx

  movw $0x1F3, %dx
  movl %ebx, %eax
  outb %al, %dx

  movw $0x1F4, %dx
  shrl $8, %eax
  outb %al, %dx

  movw $0x1F5, %dx
  shrl $8, %eax
  outb %al, %dx

  movw $0x1F7, %dx
  movb $0x20, %al
  outb %al, %dx

  nop
  nop
  nop
  nop
  .wait_ready:
    nop
    inb %dx, %al
    test $0x8, %al # DRQ bit
    jz .wait_ready

  # ecx * 512 / 2 = ecx * 256 = ecx << 8
  shll $8, %ecx
  movw $0x1F0, %dx
  rep insw

  ret

HELLO_MESSAGE:
.asciz "Hello world!"
PMODE_MESSAGE:
.asciz "We're in Protected Mode Now!!"
ERROR_MSG:
.asciz "READ FLOPPY ERROR"
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
.org 0x1FE, 0x62
.byte 0x55
.byte 0xAA

.org 0x400, 0x62
