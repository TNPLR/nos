OUTPUT_FORMAT(elf32-i386)
ENTRY(bootEntry)
SECTIONS {
  . = 0x100000;
  .text : 
  {
    KEEP(*(.multiboot_header))
    *(.text)
  }
  .data : {*(.data)}
  .bss : {*(.bss)}
  .rodata : {*(.rodata)}
}
