#ifndef PIO_H_
#define PIO_H_
#include <type.h>
static inline void outb(__u8 val, __u16 port)
{
	asm inline (
		"outb %%al, %%dx"
		:: "a"(val), "d"(port));
}
static inline void outw(__u16 val, __u16 port)
{
	asm inline (
		"outw %%al, %%dx"
		:: "a"(val), "d"(port));
}
static inline __u8 inb(__u16 port)
{
	__u8 ret;
	asm inline (
		"inb %%dx, %%al"
		: "=a"(ret)
		: "d"(port));
	return ret;
}
static inline __u16 inw(__u16 port)
{
	__u16 ret;
	asm inline (
		"inw %%dx, %%ax"
		: "=a"(ret)
		: "d"(port));
	return ret;
}
#endif // PIO_H_
