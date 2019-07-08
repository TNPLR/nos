#ifndef PIO_H_
#define PIO_H_
static inline void outb(unsigned char val, unsigned short int port)
{
  asm inline (
      "outb %%al, %%dx"
      :: "a"(val), "d"(port));
}
static inline void outw(unsigned short int val, unsigned short int port)
{
  asm inline (
      "outw %%al, %%dx"
      :: "a"(val), "d"(port));
}
static inline unsigned char inb(unsigned short int port)
{
  unsigned char ret;
  asm inline (
      "inb %%dx, %%al"
      : "=a"(ret)
      : "d"(port));
  return ret;
}
static inline unsigned short int inw(unsigned short int port)
{
  unsigned short int ret;
  asm inline (
      "inw %%dx, %%ax"
      : "=a"(ret)
      : "d"(port));
  return ret;
}
#endif // PIO_H_
