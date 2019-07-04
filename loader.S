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

  call searchKernel
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
  pushl %edx
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

  popl %edx
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

# Root directory Inode's block position
  movl $0x18A8, %esi
  movl $0x0, %edx

.searchKernel_Root_Block_Loop:
  movl $32, %ebx
  movl (%esi, %edx, 4), %eax
  shll %eax
  addl %eax, %ebx
  movl $2, %ecx
  movl $0x1C00, %edi
  call readATA
  call searchFile
  cmp $0, %eax
  jne .found_kernel_inode
  jmp . # TODO Loop next block


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

  movl $32, %eax
  pushl %eax

  movl $-1, %eax
  pushl %eax

  movl $0, %eax
  pushl %eax

  leal 0x2000(%edx), %esi
  pushl %esi

  movl $0x800000, %edi
  pushl %edi
  call readInodeBlock

  addl $20, %esp
  ret

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

KERN_FILENAME:
  .asciz "kernel.elf"

# readInodeBlock
# protect:
#  EBX EDI EBP
# STACK:
# +24 No. zero block LBA
# +20 read block count
# +16  block number (start from zero)
# +12  inode pos
# +8  address to put
# +4  return address
# +0  ebp
# Number Zero Block is at LBA 33


#
readInodeBlock:
  pushl %ebp
  movl %esp, %ebp

  pushl %edi
  pushl %ebx

  movl 12(%ebp), %ebx
  movl 16(%ebp), %edx
  movl 20(%ebp), %ecx
  movl 28(%ebx), %eax
  shr %eax

.riblock_loop:
  test %ecx, %ecx
  jz .riblock_ret_val
  cmp %eax, %edx
  jge .riblock_ret_val
  cmp $12, %edx
  jl .riblock_directBlocks
  cmp $268, %edx
  jl .riblock_indirect
  cmp $65804, %edx
  jl .riblock_db_indirect
  cmp $16843020, %edx
  jl .riblock_tp_indirect
  jge .riblock_ret_val

# Current Register Status
# EAX 512 bytes block count
# EBX INODE POS
# ECX Counter
# EDX CURRENT BLOCK NO.
.riblock_directBlocks:
  pushl %eax
  pushl %ebx
  pushl %ecx
  pushl %edx

  movl 40(%ebx, %edx, 4), %edx
  movl 24(%ebp), %ebx
  shll %edx
  addl %edx, %ebx
  movl $2, %ecx
  movl 8(%ebp), %edi

  call readATA

  movl %edi, 8(%ebp)

  jmp .riblock_loop_end

.riblock_indirect:
  pushl %eax
  pushl %ebx
  pushl %ecx
  pushl %edx

# ======================= STAGE I ==============================
  movl 88(%ebx), %edx
  movl 24(%ebp), %ebx
  shll %edx
  addl %edx, %ebx
  movl $2, %ecx
  movl 8(%ebp), %edi

  call readATA

  movl (%esp), %edx
  movl 4(%esp), %ecx
  movl 8(%esp), %ebx
  movl 12(%esp), %eax
# ======================= STAGE II ==============================
  movl 8(%ebp), %edi
  subl $12, %edx
  movl (%edi, %edx, 4), %edx
  movl 24(%ebp), %ebx
  shll %edx
  addl %edx, %ebx
  movl $2, %ecx

  call readATA

  movl %edi, 8(%ebp)

  jmp .riblock_loop_end

.riblock_db_indirect:
  pushl %eax
  pushl %ebx
  pushl %ecx
  pushl %edx

# ======================= STAGE I ==============================
  movl 92(%ebx), %edx
  movl 24(%ebp), %ebx
  shll %edx
  addl %edx, %ebx
  movl $2, %ecx
  movl 8(%ebp), %edi

  call readATA

  movl (%esp), %edx
  movl 4(%esp), %ecx
  movl 8(%esp), %ebx
  movl 12(%esp), %eax
# ======================= STAGE II ==============================
  movl 8(%ebp), %edi
  subl $268, %edx
  shrl $8, %edx

  movl (%edi, %edx, 4), %edx
  movl 24(%ebp), %ebx
  shll %edx
  addl %edx, %ebx
  movl $2, %ecx

  call readATA

  movl (%esp), %edx
  movl 4(%esp), %ecx
  movl 8(%esp), %ebx
  movl 12(%esp), %eax
# ======================= STAGE III ==============================
  movl 8(%ebp), %edi
  subl $268, %edx
  andl $256, %edx

  movl (%edi, %edx, 4), %edx
  movl 24(%ebp), %ebx
  shl %edx
  addl %edx, %ebx
  movl $2, %ecx

  call readATA

  movl %edi, 8(%ebp)

  jmp .riblock_loop_end

.riblock_tp_indirect:
  pushl %eax
  pushl %ebx
  pushl %ecx
  pushl %edx

# ======================= STAGE I ==============================
  movl 96(%ebx), %edx
  movl 24(%ebp), %ebx
  shll %edx
  addl %edx, %ebx
  movl $2, %ecx
  movl 8(%ebp), %edi

  call readATA

  movl (%esp), %edx
  movl 4(%esp), %ecx
  movl 8(%esp), %ebx
  movl 12(%esp), %eax
# ======================= STAGE II ==============================
  movl 8(%ebp), %edi
  subl $65804, %edx
  shrl $16, %edx

  movl (%edi, %edx, 4), %edx
  movl 24(%ebp), %ebx
  shll %edx
  addl %edx, %ebx
  movl $2, %ecx

  call readATA

  movl (%esp), %edx
  movl 4(%esp), %ecx
  movl 8(%esp), %ebx
  movl 12(%esp), %eax
# ======================= STAGE III ==============================
  movl 8(%ebp), %edi
  subl $65804, %edx
  shrl $8, %edx
  andl $256, %edx

  movl (%edi, %edx, 4), %edx
  movl 24(%ebp), %ebx
  shll %edx
  addl %edx, %ebx
  movl $2, %ecx

  call readATA

  movl (%esp), %edx
  movl 4(%esp), %ecx
  movl 8(%esp), %ebx
  movl 12(%esp), %eax
# ======================= STAGE IV ==============================
  movl 8(%ebp), %edi
  subl $65804, %edx
  andl $256, %edx

  movl (%edi, %edx, 4), %edx
  movl 24(%ebp), %ebx
  shl %edx
  addl %edx, %ebx
  movl $2, %ecx

  call readATA

  movl %edi, 8(%ebp)

  jmp .riblock_loop_end

.riblock_loop_end:

  popl %edx
  popl %ecx
  popl %ebx
  popl %eax

  decl %ecx
  incl %edx
  jmp .riblock_loop
.riblock_ret_val:
  movl 20(%ebp), %eax
  subl %ecx, %eax
.riblock_leave:
  popl %ebx
  popl %edi

  leave
  ret

# ESI = INODE POS; EDI = READ TO ADDR
readInodeFile:
  movl %esp, %ebp
  movl $0, %ecx
  .loop_read_inode_file:
    movl 40(%esi, %ecx, 4), %ebx
    test %ebx, %ebx
    jz .read_inode_file_end
    addl $16, %ebx
    shll %ebx
    pushl %ecx
    movl $2, %ecx
    call readATA
    popl %ecx
    incl %ecx
    cmp $12, %ecx
    jne .loop_read_inode_file

  movl 40(%esi, %ecx, 4), %ebx
  test %ebx, %ebx
  jz .read_inode_file_end
  addl $16, %ebx
  shll %ebx
  incl %ecx
  pushl %ecx
  movl $2, %ecx
  pushl %edi
  movl $0x2400, %edi
  call readATA
  popl %edi
  movl $0, %ecx
  pushl %esi
  movl $0x2400, %esi

  .loop_read_indirect_block1:
    movl (%esi, %ecx, 4), %ebx
    test %ebx, %ebx
    jz .read_inode_file_end
    addl $16, %ebx
    shll %ebx
    pushl %ecx
    movl $2, %ecx
    call readATA
    popl %ecx
    incl %ecx
    cmp $256, %ecx
    jne .loop_read_indirect_block1

  popl %esi
  popl %ecx

  movl 40(%esi, %ecx, 4), %ebx
  test %ebx, %ebx
  jz .read_inode_file_end
  addl $16, %ebx
  shll %ebx
  incl %ecx
  pushl %ecx
  movl $2, %ecx
  pushl %edi
  movl $0x2400, %edi
  call readATA
  popl %edi

  movl $0, %ecx
  pushl %esi
  movl $0x2400, %esi
  .loop_read_double_indirect_block1:
    movl (%esi, %ecx, 4), %ebx
    test %ebx, %ebx
    jz .read_inode_file_end
    addl $16, %ebx
    shll %ebx
    pushl %ecx
    movl $2, %ecx
    pushl %edi
    movl $0x2800, %edi
    call readATA
    popl %edi
    pushl %esi
    movl $0, %ecx
    movl $0x2800, %esi

    .loop_read_double_indirect_block2:
      movl (%esi, %ecx, 4), %ebx
      test %ebx, %ebx
      jz .read_inode_file_end
      addl $16, %ebx
      shll %ebx
      pushl %ecx
      movl $2, %ecx
      call readATA
      popl %ecx
      incl %ecx
      cmp $256, %ecx
      jne .loop_read_double_indirect_block2
    popl %esi
    popl %ecx
    incl %ecx
    cmp $256, %ecx
    jne .loop_read_double_indirect_block1

  popl %esi
  popl %ecx


  movl 40(%esi, %ecx, 4), %ebx
  test %ebx, %ebx
  jz .read_inode_file_end
  addl $16, %ebx
  shll %ebx
  incl %ecx
  pushl %ecx
  movl $2, %ecx
  pushl %edi
  movl $0x2400, %edi
  call readATA
  popl %edi

  movl $0, %ecx
  pushl %esi
  movl $0x2400, %esi
  .loop_read_triple_indirect_block1:
    movl (%esi, %ecx, 4), %ebx
    test %ebx, %ebx
    jz .read_inode_file_end
    addl $16, %ebx
    shll %ebx
    pushl %ecx
    movl $2, %ecx
    pushl %edi
    movl $0x2800, %edi
    call readATA
    popl %edi
    pushl %esi
    movl $0, %ecx
    movl $0x2800, %esi

    .loop_read_triple_indirect_block2:
      movl (%esi, %ecx, 4), %ebx
      test %ebx, %ebx
      jz .read_inode_file_end
      addl $16, %ebx
      shll %ebx
      pushl %ecx
      movl $2, %ecx
      pushl %edi
      movl $0x2800, %edi
      call readATA
      popl %edi
      pushl %esi
      movl $0, %ecx
      movl $0x2C00, %esi

      .loop_read_triple_indirect_block3:
        movl (%esi, %ecx, 4), %ebx
        test %ebx, %ebx
        jz .read_inode_file_end
        addl $16, %ebx
        shll %ebx
        pushl %ecx
        movl $2, %ecx
        call readATA
        popl %ecx
        incl %ecx
        cmp $256, %ecx
        jne .loop_read_triple_indirect_block3

      popl %esi
      popl %ecx
      incl %ecx
      cmp $256, %ecx
      jne .loop_read_double_indirect_block2
    popl %esi
    popl %ecx

    incl %ecx
    cmp $256, %ecx
    jne .loop_read_double_indirect_block1
  popl %esi
  popl %ecx
  .read_inode_file_end:
  movl %ebp, %esp
  ret
