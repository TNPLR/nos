#include <type.h>
#include <bitmap.h>
#include <kstring.h>

int init_bitmap(void *pos, __u64 size)
{
	memset(pos, 0, size);
	return 0;
}

static inline void setBit(void *pos, __u64 num)
{
	*((__u8 *)pos + (num >> 3)) |= 1 << (num & 0x7);
}

static inline void clearBit(void *pos, __u64 num)
{
	*((__u8 *)pos + (num >> 3)) &= ~(1 << (num & 0x7));
}

int set_bitmap(void *pos, __u64 num, __u64 count)
{
	for (int i = 0; i < count; ++i) {
		setBit(pos, num);
		++num;
	}
	return 0;
}

int clear_bitmap(void *pos, __u64 num, __u64 count)
{
	for (int i = 0; i < count; ++i) {
		clearBit(pos, num);
		++num;
	}
	return 0;
}
