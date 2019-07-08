#include <text.h>
void kmain(void)
{
  // Our stack is at 0x7000
  // init text system
  initText();

  // Print A Msg
  kputc('T');
  kputc('h');
  kputc('i');
  kputc('s');
  kputc(' ');
  kputc('i');
  kputc('s');
  kputc(' ');
  kputc('k');
  kputc('e');
  kputc('r');
  kputc('n');
  kputc('e');
  kputc('l');
  kputc('\n');
  for (;;) ;
}
