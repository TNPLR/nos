#ifndef MEMORY_H_
#define MEMORY_H_
#include <type.h>
int init_mem(__u32 k_pages, void *boot_info);
extern void *(*page_alloc)(__u64 page_count);
extern void (*page_free)(void *pos, __u64 page_count);
#endif // MEMORY_H_
