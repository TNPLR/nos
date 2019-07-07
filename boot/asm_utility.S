.section .text
.code32
.global readATA
.global searchKernel
.global searchFile
.global readInodeBlock
.global print32
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
# Return Value: Total read block count


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

  .wait_ready:
    inb %dx, %al
    inb %dx, %al
    inb %dx, %al
    inb %dx, %al
    inb %dx, %al
    test $0x80, %al # BSY bit
    jnz .wait_ready
    test $0x1, %al # ERR bit
    jnz .wait_ready
    test $0x20, %al # DF bit
    jnz .wait_ready
    test $0x8, %al # DRQ bit
    jz .wait_ready

  # ecx * 512 / 2 = ecx * 256 = ecx << 8
  movl %ecx, %eax
  movl $256, %ecx
  movw $0x1F0, %dx
  rep insw

  movl %eax, %ecx
  movw $0x1F7, %dx
  loop .wait_ready
  popl %edx
  ret
