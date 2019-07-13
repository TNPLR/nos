#include <type.h>
#include <text.h>
#include <memory.h>

void kmain(__u32 k_size, void *boot_info)
{
	// Our stack is at 0x7000
	// init text system
	init_text();

	// init our pages
	init_mem(k_size, boot_info);
	
	// Print A Msg
	kputs("This is a 64 bits kernel");
	for (;;) ;
}
