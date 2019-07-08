.section .multiboot_header
.code32
.include "asm_utility.h"
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
  .long 0
  .long 0x9200
GDT64_END:
GDT64_PTR:
  .word GDT64_END - GDT64 - 1
  .quad GDT64
bootEntry:
# Setup Page Table
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
  jmp .

