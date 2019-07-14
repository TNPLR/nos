#include <type.h>
#include <text.h>
#include <memory.h>

static void error_halt(void)
{
	asm (
			"cli\n"
			"hlt"
	    );
}
void kmain(__u32 k_pages, void *boot_info)
{
	// Our stack is at 0x7000
	// init text system
	init_text();

	// init our pages
	if ((__u64)boot_info < 0x100000U) {
		boot_info += 0xFFFFFFFF80000000ULL;
		init_mem(k_pages, boot_info);
	} else {
		kputs("Boot Info Not at Address Below 1MiB");
		error_halt();
	}

	void *pg = page_alloc(200);
	kprintf("Allocate Page(s) at 0x%lx\n", (__u64)pg);

	page_free(pg, 200);
	
	// Print A Msg
	kputs("This is a 64 bits kernel");
	for (;;) ;
}
