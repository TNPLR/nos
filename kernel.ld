OUTPUT_FORMAT(elf64-x86-64)
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
