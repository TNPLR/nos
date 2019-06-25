.code16
.section .text
# Init all the registers
xorw %ax, %ax
xorw %bx, %bx
xorw %cx, %cx
xorw %dx, %dx

movw $0x7c0, %ax
movw %ax, %es
movw %ax, %ds
movw %ax, %ss

# Reset Floppy (int 0x13, ah = 0x0, dl = 0x80 (first disk))
movb $0, %ah
movb $0x80, %dl
int $0x13

# Read Number 2 (CHS)
# (int 0x13, ah = 0x2, al = 1, ch = 0, cl = 2, dh = 0, dl = 0x80, ES:BX = 0x7E00)
movw $0x200, %bx
movb $0x2, %ah
movb $0x1, %al
movb $0x0, %ch
movb $0x2, %cl
movb $0x0, %dh
movb $0x80, %dl
int $0x13

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

ljmp $0x08, $(0x7c00+OS_PMODE)
.code32
OS_PMODE:
  movw $0x10, %ax
  movw %ax, %ss
  movw %ax, %ds
  movw %ax, %es
  movw %ax, %fs
  movw %ax, %gs
  movl $(0x7c00+PMODE_MESSAGE), %esi
  call print32

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
  .long GDT_NUL+0x7c00
.org 0x1FE, 0x62
.byte 0x55
.byte 0xAA

.org 0x400, 0x62
# SuperBlock
.long 184 # s_inode_count
.long 1440 # s_blocks_count
.long 72 # s_r_blocks_count
.long 1411 # s_free_blocks_count
.long 174 # s_free_inodes_count
.long 1 # s_first_data_block
.long 0 # s_log_block_size
.long 0 # s_log_frag_size
.long 8192 # s_blocks_per_group
.long 8192 # s_frags_per_group
.long 184 # s_inodes_per_group
.long 0 # s_mtime
.long 0x5D0F7311 # s_wtime
.word 0 # s_mnt_count
.word 0x1e # s_max_mnt_count
.word 0xEF53 # s_magic
.word 1 # s_state
.word 1 # s_errors
.word 0 # s_minor_rev_level
.long 0x5D0F7311 # s_lastcheck
.long 0xed4e00 # s_checkinterval
.long 0 # s_creator_os
.long 1 # s_rev_level
.word 0 # s_def_resuid
.word 0 # s_def_resgid
.long 11
.word 128
.word 0
.long 0
.long 0
.long 0
.quad 0x52145214
.quad 0x52145214
.quad 0
.quad 0
.quad 0
.quad 0
.quad 0
.quad 0
.long 0

.org 0x800, 0x0
# Block Group Descriptor Table
.long 3
.long 4
.long 5
.word 1411
.word 174
.word 1
.word 0
.long
.long
.long

.org 0xC00, 0x0
# BLOCK BITMAP
.long 0x0FFFFFFF

.org 0x1000, 0x0
# INODE BITMAP
.word 0b1111111111
.org 0x1480, 0x0
# INODE TABLE
# Root directory
.word 0x41ED #i_mode
.word 0
.long 1024
.long 0
.long 0x5D0F7311
.long 0
.long 0
.word 0
.word 2
.long 2
.long 0
.long 0
# 15 blocks
.long 28
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0
.long 0

.long 0
.long 0
.long 0
.long 0

.long 0
.long 0
.long 0
.org 0x7000, 0x0
.long 2
.word 12
.byte 1
.byte 2
.ascii "."

.long 2
.word 12
.byte 2
.byte 2
.ascii ".."
