#ifndef BITMAP_H_
#define BITMAP_H_
int init_bitmap(void *pos, __u64 size);
int set_bitmap(void *pos, __u64 num, __u64 count);
int clear_bitmap(void *pos, __u64 num, __u64 count);
#endif // BITMAP_H_
