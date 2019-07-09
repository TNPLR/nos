.section .multiboot_header
.code32
.global bootEntry

header_start:
.long 0xE85250D6
.long 0                   # i386
.long header_end - header_start
.long 0x100000000 - (0xE85250d6 + 0 + (header_end - header_start))

.word 0
.word 0
.long 8
header_end:
GDT64:
  .quad 0
GDT64_CODE:
  .long 0x0000FFFF
  .long 0x00AF9A00
GDT64_DATA:
  .long 0x0000FFFF
  .long 0x00CF9200
GDT64_END:
GDT64_PTR:
  .word GDT64_END - GDT64 - 1
  .quad GDT64
bootEntry:
# Setup Page Table low 2mb
  leal 0x1C0000, %edi
  movl %edi, %cr3
  xorl %eax, %eax
  movl $0x10000, %ecx

  rep stosl

  movl $0x1C1003, 0x1C0000
  movl $0x1C2003, 0x1C1000
  movl $0x1C3003, 0x1C2000

  leal 0x1C3000, %edi
  movl $3, %eax
  movl $512, %ecx

  .loop_low2mb_pg:
    movl %eax, (%edi)
    addl $0x1000, %eax
    addl $8, %edi
    loop .loop_low2mb_pg

# Setup Page Table low 2mb at 0xffffffff80000000 (-2GB)
  movl $0x1C4003, 0x1C0ff8
  movl $0x1C2003, 0x1C4ff0

# Enable PAE
  movl %cr4, %eax
  orl $32, %eax
  movl %eax, %cr4

# EFER MSR
  movl $0xC0000080, %ecx
  rdmsr
  orl $256, %eax
  wrmsr

# Enable Paging
  movl %cr0, %eax
  orl $0x80000000, %eax
  movl %eax, %cr0

# Load new GDT
  lgdt GDT64_PTR

# jmp
  ljmp $0x8,$LMODE
.code64
LMODE:
  movw $0x10, %ax
  movw %ax, %ds
  movw %ax, %es
  movw %ax, %ss
  movw %ax, %fs
  movw %ax, %gs
  movq $0x7000, %rsp

  call searchKernel

  pushq %rax
  leaq 0x2000(%rax), %rax
  movl 28(%rax), %eax
  movq %rax, %rbx
  andq $255, %rbx
  shrq $8, %rax
  test %rbx, %rbx
  jz .pte
  incq %rax
  .pte:
  movq %rax, %rbx
  movq %rax, %rcx
  andq $511, %rbx
  shrq $9, %rcx
  test %rbx, %rbx
  jz .pde
  incq %rcx
  .pde:
  movq $0x200003, %rbx
  movq $0x1C2008, %rsi
  movq $0x1C5000, %rdi
  .pde_loop:
    movq %rdi, %rax
    addq $3, %rax
    movq %rax, (%rsi)
    addq $8, %rsi
    pushq %rcx
    movq $512, %rcx
    .pte_loop:
      movq %rbx, (%rdi)
      addq $0x1000, %rbx
      addq $8, %rdi
      loop .pte_loop
    popq %rcx
    loop .pde_loop

  popq %rax

  movq %rax, %rdx
  call readAllKernel

  jmp *%rax

# readInodeBlock64
# protect:
#  RBX RDI RBP
# STACK:
# +48 No. zero block LBA
# +40 read block count
# +32  block number (start from zero)
# +24  inode pos
# +16  address to put
# +8  return address
# +0  rbp
# Number Zero Block is at LBA 33
# Return Value: Total read block count

readInodeBlock64:
  pushq %rbp
  movq %rsp, %rbp

  pushq %rdi
  pushq %rbx

  movq 24(%rbp), %rbx
  movq 32(%rbp), %rdx
  movq 40(%rbp), %rcx
  movl 28(%rbx), %eax
  shr %rax

.riblock_loop:
  test %rcx, %rcx
  jz .riblock_ret_val
  cmp %rax, %rdx
  jge .riblock_ret_val
  cmp $12, %rdx
  jl .riblock_directBlocks
  cmp $268, %rdx
  jl .riblock_indirect
  cmp $65804, %rdx
  jl .riblock_db_indirect
  cmp $16843020, %rdx
  jl .riblock_tp_indirect
  jge .riblock_ret_val

# Current Register Status
# RAX 512 bytes block count
# RBX INODE POS
# RCX Counter
# RDX CURRENT BLOCK NO.
.riblock_directBlocks:
  pushq %rax
  pushq %rbx
  pushq %rcx
  pushq %rdx

  movl 40(%rbx, %rdx, 4), %edx
  movq 48(%rbp), %rbx
  shlq %rdx
  addq %rdx, %rbx
  movq $2, %rcx
  movq 16(%rbp), %rdi

  call readATA64

  movq %rdi, 16(%rbp)

  jmp .riblock_loop_end

.riblock_indirect:
  pushq %rax
  pushq %rbx
  pushq %rcx
  pushq %rdx

# ======================= STAGE I ==============================
  movl 88(%rbx), %edx
  movq 48(%rbp), %rbx
  shlq %rdx
  addq %rdx, %rbx
  movq $2, %rcx
  movq 16(%rbp), %rdi

  call readATA64

  movq (%rsp), %rdx
  movq 8(%rsp), %rcx
  movq 16(%rsp), %rbx
  movq 24(%rsp), %rax
# ======================= STAGE II ==============================
  movq 16(%rbp), %rdi
  subq $12, %rdx
  movl (%rdi, %rdx, 4), %edx
  movq 48(%rbp), %rbx
  shlq %rdx
  addq %rdx, %rbx
  movq $2, %rcx

  call readATA64

  movq %rdi, 16(%rbp)

  jmp .riblock_loop_end

.riblock_db_indirect:
  pushq %rax
  pushq %rbx
  pushq %rcx
  pushq %rdx

# ======================= STAGE I ==============================
  movl 92(%rbx), %edx
  movq 48(%rbp), %rbx
  shlq %rdx
  addq %rdx, %rbx
  movq $2, %rcx
  movq 16(%rbp), %rdi

  call readATA64

  movq (%rsp), %rdx
  movq 8(%rsp), %rcx
  movq 16(%rsp), %rbx
  movq 24(%rsp), %rax
# ======================= STAGE II ==============================
  movq 16(%rbp), %rdi
  subq $268, %rdx
  shrq $8, %rdx

  movl (%rdi, %rdx, 4), %edx
  movq 48(%rbp), %rbx
  shlq %rdx
  addq %rdx, %rbx
  movq $2, %rcx

  call readATA64

  movq (%rsp), %rdx
  movq 8(%rsp), %rcx
  movq 16(%rsp), %rbx
  movq 24(%rsp), %rax
# ======================= STAGE III ==============================
  movq 16(%rbp), %rdi
  subq $268, %rdx
  andq $256, %rdx

  movl (%rdi, %rdx, 4), %edx
  movq 48(%rbp), %rbx
  shlq %rdx
  addq %rdx, %rbx
  movq $2, %rcx

  call readATA64

  movq %rdi, 16(%rbp)

  jmp .riblock_loop_end

.riblock_tp_indirect:
  pushq %rax
  pushq %rbx
  pushq %rcx
  pushq %rdx

# ======================= STAGE I ==============================
  movl 96(%rbx), %edx
  movq 24(%rbp), %rbx
  shlq %rdx
  addq %rdx, %rbx
  movq $2, %rcx
  movq 16(%rbp), %rdi

  call readATA64

  movq (%rsp), %rdx
  movq 8(%rsp), %rcx
  movq 16(%rsp), %rbx
  movq 24(%rsp), %rax
# ======================= STAGE II ==============================
  movq 16(%rbp), %rdi
  subq $65804, %rdx
  shrq $16, %rdx

  movl (%rdi, %rdx, 4), %edx
  movq 48(%rbp), %rbx
  shlq %rdx
  addq %rdx, %rbx
  movq $2, %rcx

  call readATA64

  movq (%rsp), %rdx
  movq 8(%rsp), %rcx
  movq 16(%rsp), %rbx
  movq 24(%rsp), %rax
# ======================= STAGE III ==============================
  movq 16(%rbp), %rdi
  subq $65804, %rdx
  shrq $8, %rdx
  andq $256, %rdx

  movl (%rdi, %rdx, 4), %edx
  movq 48(%rbp), %rbx
  shlq %rdx
  addq %rdx, %rbx
  movq $2, %rcx

  call readATA64

  movq (%rsp), %rdx
  movq 8(%rsp), %rcx
  movq 16(%rsp), %rbx
  movq 24(%rsp), %rax
# ======================= STAGE IV ==============================
  movq 16(%rbp), %rdi
  subq $65804, %rdx
  andq $256, %rdx

  movl (%rdi, %rdx, 4), %edx
  movq 48(%rbp), %rbx
  shlq %rdx
  addq %rdx, %rbx
  movq $2, %rcx

  call readATA64

  movq %rdi, 16(%rbp)

  jmp .riblock_loop_end

.riblock_loop_end:

  popq %rdx
  popq %rcx
  popq %rbx
  popq %rax

  decq %rcx
  incq %rdx
  jmp .riblock_loop
.riblock_ret_val:
  movq 40(%rbp), %rax
  subq %rcx, %rax
.riblock_leave:
  popq %rbx
  popq %rdi

  leave
  ret
# ===============================================================================
# readATA64
# rbx = LBA 28 bits
# rcx = sectors to read count
# rdi = position to put
# ===============================================================================
readATA64:
  pushq %rdx
  movw $0x1F6, %dx
  movq %rbx, %rax
  shrq $24, %rax
  orb $0xE0, %al
  outb %al, %dx

  movw $0x1F2, %dx
  movb %cl, %al
  outb %al, %dx

  movw $0x1F3, %dx
  movq %rbx, %rax
  outb %al, %dx

  movw $0x1F4, %dx
  shrq $8, %rax
  outb %al, %dx

  movw $0x1F5, %dx
  shrq $8, %rax
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
  movq %rcx, %rax
  movq $256, %rcx
  movw $0x1F0, %dx
  rep insw

  movq %rax, %rcx
  movw $0x1F7, %dx
  loop .wait_ready
  popq %rdx
  ret

KERN_FILENAME:
  .asciz "kernel64.elf"
searchFile:
  pushq %rbx
  pushq %rcx
  pushq %rdx
  pushq %rsi
  pushq %rdi
  movq $0x1C00, %rbx
  movq $0x0, %rdx
  .loop_search_file:
    movl (%rbx, %rdx, 1), %eax
    cmp $0, %eax
    je .next_search_file
    movzbl 6(%rbx, %rdx, 1), %eax
    cmp $12, %eax         # kernel64.elf 12 bytes
    jne .next_search_file
    leaq 8(%rbx, %rdx, 1), %rdi
    leaq KERN_FILENAME, %rsi
    movq $10, %rcx
    repe cmpsb
    cmp $0, %rcx
    jne .next_search_file
    movl (%rbx, %rdx, 1), %eax
    jmp .search_file_exit
  .next_search_file:
    movzwq 4(%rbx, %rdx, 1), %rax
    addq %rax, %rdx
    cmp $0x400, %rdx
    jl .loop_search_file

  .search_file_end:
  movq $0, %rax

  .search_file_exit:
  popq %rdi
  popq %rsi
  popq %rdx
  popq %rcx
  popq %rbx
  ret

# =============================================================
# searchKernel : search kernel.elf
# =============================================================
searchKernel:
# Read superblock to 0x1000 and block descriptor table to 0x1400
  movq $34, %rbx
  movq $4, %rcx
  movq $0x1000, %rdi
  call readATA64

# Read INODE Table to find root directory
  movq 0x1408, %rbx
  addq $16, %rbx
  shlq %rbx
  movq $2, %rcx
  movq $0x1800, %rdi
  call readATA64

# block number zero
  movq $0x0, %rcx
  jmp .read_next_root_block

.searchKernel_Root_Block_Loop:
  pushq %rcx
  call searchFile
  popq %rcx
  cmp $0, %rax
  jne .found_kernel_inode
.read_next_root_block:
  pushq %rcx
  movq $32, %rax
  pushq %rax

  movq $1, %rax
  pushq %rax

  pushq %rcx

  movq $0x1880, %rax # Root Inode Position
  pushq %rax

  movq $0x1c00, %rax
  pushq %rax

  call readInodeBlock64

  addq $40, %rsp
  popq %rcx
  incq %rcx
  test %rax, %rax
  jnz .searchKernel_Root_Block_Loop
.kernel_not_found:
  hlt
.found_kernel_inode:
  decq %rax
  movq $0, %rdx
  divq 0x1000 + 40
  shlq $5, %rax
  movq 0x1408(%rax), %rbx
  addq $16, %rbx
  movq %rdx, %rax
  xorq %rdx, %rdx
  movq $8, %rcx
  divq %rcx
  addq %rax, %rbx
  shlq %rbx
  movq $2, %rcx
  movq $0x2000, %rdi
  call readATA64
  shlq $7, %rdx

  pushq %rdx
  movq $32, %rax
  pushq %rax

  movq $1, %rax
  pushq %rax

  movq $0, %rax
  pushq %rax

  leaq 0x2000(%rdx), %rax
  pushq %rax

  movq $0x10000, %rax
  pushq %rax
  call readInodeBlock64

  addq $40, %rsp
  popq %rdx

  movq %rdx, %rax
  ret

# RDX = INODE POS
readAllKernel:
  movzwq 0x10038, %rcx
  movq 0x10020, %rbx          # Program header start position
  leaq 0x10000(%rbx), %rbx
.load_elf_loop:
  pushq %rcx
  pushq %rdx

  movl (%rbx), %eax
  cmp $1, %rax
  je .load_elf
  popq %rdx
  jmp .add_elf_header
.load_elf:
  movq $32, %rax
  pushq %rax

  movq 0x20(%rbx), %rax
  test $0x3ff, %rax
  jz .load_less
  addq $0x400, %rax
  .load_less:
  shrq $10, %rax
  pushq %rax

  movq 8(%rbx), %rax
  shrq $10, %rax
  pushq %rax

  leaq 0x2000(%rdx), %rax
  pushq %rax

  movq 0x10(%rbx), %rax
  pushq %rax
  call readInodeBlock64

  addq $40, %rsp
  popq %rdx
  movq 0x8(%rbx), %rsi
  andq $1023, %rsi
  
  test %rsi, %rsi
  
  jz .add_elf_header
  movq 0x8(%rbx), %rsi
  movq 0x10(%rbx), %rdi
  addq %rdi, %rsi
  movq 0x20(%rbx), %rcx
  rep movsb
  .add_elf_header:

  popq %rcx
  addq $0x38, %rbx
  loop .load_elf_loop

  movq 0x10018, %rax
  ret
