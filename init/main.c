#include <text.h>
void kmain(void)
{
  // Our stack is at 0x7000
  // init text system
  initText();

  // Print A Msg
  kputs("This is a 64 bits kernel");
  for (;;) ;
}
