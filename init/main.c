#include <text.h>
#include <memory.h>

void kmain(unsigned int k_size, void *boot_info)
{
  // init our pages
  initRam();
  // Our stack is at 0x7000
  // init text system
  initText();

  // Print A Msg
  kputs("This is a 64 bits kernel");
  for (;;) ;
}
