.section .multiboot_header

header_start:
.long 0xE85250D6
.long 0                   # i386
.long header_end - header_start
.long 0x100000000 - (0xE85250d6 + 0 + (header_end - header_start))

.word 0
.word 0
.long 8
header_end:
