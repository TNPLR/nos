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
  call setupBootInfo

  call searchKernel

  movl %eax, %edx

  movl $0x36d76289, %eax # multiboot 2 magic
  leal 0x3000, %ebx # boot information

  jmp *%edx

  hlt # Won't reach here
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
  pushw %es
  movw $0, %ax
  movw %ax, %es
  movl $0xe820, %eax
  xorl %ebx, %ebx
  movw $0x3018, %di
  movl $24, %ecx
  movl $0x534D4150, %edx
getRam_loop:
  int $0x15
  movl %eax, %edx

# Change type value 1 -> 1, else -> 0
  movl 16(%di), %eax
  cmp $1, %eax
  je .next_getRam
  movl $2, 16(%di)

  .next_getRam:
# Add the value of size
  movl %es:0x300C, %eax
  addl $24, %eax
  movl %eax, %es:0x300C
  movl $0xe820, %eax
  movl $24, %ecx
  addw $24, %di
  cmpl $0, %ebx
  jne getRam_loop

  movw %di, %ax
  movw $0x300C, %di
  subw $0x3018, %ax
  movw %ax, (%di)
  movw $0, 2(%di)
  popw %es
  ret

.code32
#=====================================================================
# setupBootInfo @ 0x3000
#=====================================================================
setupBootInfo:
  leal 0x3008, %ebx
  movl $6, (%ebx)

# Size of All was written in getRam function
  leal 4(%ebx), %ebx
  movl (%ebx), %eax
  movl $0, 0x3008(%eax)
  movl $0, 0x300C(%eax)
  addl $16, %eax
  movl %eax, 0x3000
  movl $0, 0x3004

  leal 4(%ebx), %ebx
  movl $20, (%ebx) # Size of one entry

  leal 4(%ebx), %ebx
  movl $0, (%ebx) # Version = 0

  ret

KERN_FILENAME:
  .asciz "kernel.elf"
searchFile:
  pushl %ebx
  pushl %ecx
  pushl %edx
  pushl %esi
  pushl %edi
  movl $0x1C00, %ebx
  movl $0x0, %edx
  .loop_search_file:
    movl (%ebx, %edx, 1), %eax
    cmp $0, %eax
    je .next_search_file
    movzbl 6(%ebx, %edx, 1), %eax
    cmp $10, %eax         # kernel.elf 10 bytes
    jne .next_search_file
    leal 8(%ebx, %edx, 1), %edi
    leal KERN_FILENAME+0x7E00, %esi
    movl $10, %ecx
    repe cmpsb
    cmp $0, %ecx
    jne .next_search_file
    movl (%ebx, %edx, 1), %eax
    jmp .search_file_exit
  .next_search_file:
    movzwl 4(%ebx, %edx, 1), %eax
    addl %eax, %edx
    cmp $0x400, %edx
    jl .loop_search_file

  .search_file_end:
  movl $0, %eax

  .search_file_exit:
  popl %edi
  popl %esi
  popl %edx
  popl %ecx
  popl %ebx
  ret

# =============================================================
# searchKernel : search kernel.elf
# =============================================================
searchKernel:
# Read superblock to 0x1000 and block descriptor table to 0x1400
  movl $34, %ebx
  movl $4, %ecx
  movl $0x1000, %edi
  call readATA

# Read INODE Table to find root directory
  movl 0x1408, %ebx
  addl $16, %ebx
  shll %ebx
  movl $2, %ecx
  movl $0x1800, %edi
  call readATA

# block number zero
  movl $0x0, %ecx
  jmp .read_next_root_block

.searchKernel_Root_Block_Loop:
  pushl %ecx
  call searchFile
  popl %ecx
  cmp $0, %eax
  jne .found_kernel_inode
.read_next_root_block:
  pushl %ecx
  movl $32, %eax
  pushl %eax

  movl $1, %eax
  pushl %eax

  pushl %ecx

  movl $0x1880, %eax # Root Inode Position
  pushl %eax

  movl $0x1c00, %eax
  pushl %eax

  call readInodeBlock

  addl $20, %esp
  popl %ecx
  incl %ecx
  test %eax, %eax
  jnz .searchKernel_Root_Block_Loop
.kernel_not_found:
  movl $(0x7E00+.kernel_not_found_msg), %esi
  call print32
  hlt

.kernel_not_found_msg:
  .asciz "Kernel not found"
.found_kernel_inode:
  decl %eax
  movl $0, %edx
  divl 0x1000 + 40
  shll $5, %eax
  movl 0x1408(%eax), %ebx
  addl $16, %ebx
  movl %edx, %eax
  xorl %edx, %edx
  movl $8, %ecx
  divl %ecx
  addl %eax, %ebx
  shll %ebx
  movl $2, %ecx
  movl $0x2000, %edi
  call readATA
  shll $7, %edx

  pushl %edx
  movl $32, %eax
  pushl %eax

  movl $1, %eax
  pushl %eax

  movl $0, %eax
  pushl %eax

  leal 0x2000(%edx), %eax
  pushl %eax

  movl $0x10000, %eax
  pushl %eax
  call readInodeBlock

  addl $20, %esp
  popl %edx

  movzwl 0x10038, %ecx
  movl 0x10020, %ebx          # Program header start position
  leal 0x10000(%ebx), %ebx
.load_elf_loop:
  pushl %ecx
  pushl %edx

  movl (%ebx), %eax
  cmp $1, %eax
  je .load_elf
  popl %edx
  jmp .add_elf_header
.load_elf:
  movl $32, %eax
  pushl %eax

  movl 0x20(%ebx), %eax
  test $0x3ff, %eax
  jz .load_less
  addl $0x400, %eax
  .load_less:
  shr $10, %eax
  pushl %eax

  movl 8(%ebx), %eax
  shr $10, %eax
  pushl %eax

  leal 0x2000(%edx), %eax
  pushl %eax

  movl 0x10(%ebx), %eax
  pushl %eax
  call readInodeBlock

  addl $20, %esp
  popl %edx
  movl 0x8(%ebx), %esi
  andl $1023, %esi
  
  test %esi, %esi
  
  jz .add_elf_header
  movl 0x8(%ebx), %esi
  movl 0x10(%ebx), %edi
  addl %edi, %esi
  movl 0x20(%ebx), %ecx
  rep movsb
  .add_elf_header:

  popl %ecx
  addl $0x38, %ebx
  loop .load_elf_loop

  movl 0x10018, %eax
  ret


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
  .word 23
  .long GDT_NUL+0x7E00
