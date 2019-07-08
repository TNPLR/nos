#include <text.h>
#include <kstring.h>
#include <pio.h>

static unsigned short int getCursorPosition(void)
{
  unsigned short int ret;
  outb(0x0F, 0x3D4);
  ret = inb(0x3D5);
  outb(0x0E, 0x3D4);
  ret |= (unsigned short int)inb(0x3D5) << 8;
  return ret;
}

static void setCursorPosition(unsigned short int position)
{
  outb(0x0F, 0x3D4);
  outb(position & 0xFF, 0x3D5);
  outb(0x0E, 0x3D4);
  outb((position >> 8) & 0xFF, 0x3D5);
}
static unsigned short int *screen_start_addr = (unsigned short *)0xB8000;
static unsigned short int *buffer_start_addr = (unsigned short *)0x80000;
static unsigned short int buffer_cursor_position = 0;
void initText(void)
{
  memcpy(buffer_start_addr, screen_start_addr, 0xFA0);
  buffer_cursor_position = getCursorPosition();
}

void bufferScroll(void)
{
  memcpy(buffer_start_addr, buffer_start_addr + 0xA0, 0xF00);
  buffer_cursor_position = buffer_cursor_position - (buffer_cursor_position % 80);
}

void kfflush(void)
{
  memcpy(screen_start_addr, buffer_start_addr, 0xFA0);
  setCursorPosition(buffer_cursor_position);
}

#define COLOR 0x7
void bufferPutc(char ch)
{
  *(buffer_start_addr + buffer_cursor_position++) = (unsigned short)COLOR << 8 | ch;
}

static void newline(void)
{
  buffer_cursor_position += 80 - buffer_cursor_position % 80;
  if (buffer_cursor_position >= 0x7D0) {
    buffer_cursor_position -= 80;
    bufferScroll();
  }
}

void kputc(char ch)
{
  switch (ch) {
    case '\n':
    case '\r':
      newline();
      break;
    case '\b':
      --buffer_cursor_position;
      break;
    default:
      bufferPutc(ch);
      break;
  }
  kfflush();
}
