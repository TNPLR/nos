#include <bitmap.h>
#include <kstring.h>

void initBitmap(void *pos, unsigned long long int size)
{
  memset(pos, 0, size);
}

static inline void setBit(void *pos, unsigned long long int num)
{
  *((unsigned char *)pos + (num >> 3)) |= 1 << (num & 0x7);
}
static inline void clearBit(void *pos, unsigned long long int num)
{
  *((unsigned char *)pos + (num >> 3)) &= ~(1 << (num & 0x7));
}
void setBitmap(void *pos, unsigned long long int num, unsigned long long int count)
{
  for (int i = 0; i < count; ++i) {
    setBit(pos, num);
    ++num;
  }
}

void cleanBitmap(void *pos, unsigned long long int num, unsigned long long int count)
{
  for (int i = 0; i < count; ++i) {
    clearBit(pos, num);
    ++num;
  }
}
