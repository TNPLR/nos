OUTPUT_FORMAT(elf64-x86-64)
ENTRY(kmain)
SECTIONS {
  . = 0xFFFF800000200000;
  .text :
  {
    *(.text)
  }
  .data : {*(.data)}
  .bss : {*(.bss)}
  .rodata : {*(.rodata)}
}
