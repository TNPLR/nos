#include <text.h>

#include <kstring.h>
#include <pio.h>

#include <stdarg.h>


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

static void newline(void)
{
  buffer_cursor_position += 80 - buffer_cursor_position % 80;
  if (buffer_cursor_position >= 0x7D0) {
    buffer_cursor_position -= 80;
    bufferScroll();
  }
}


#define COLOR 0x7
void bufferPutc(char ch)
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
      *(buffer_start_addr + buffer_cursor_position++) = (unsigned short)COLOR << 8 | ch;
      break;
  }
}

void kputc(char ch)
{
  bufferPutc(ch);
  kfflush();
}

static inline void kputs_nnl(const char *s)
{
  while (*s) {
    bufferPutc(*s++);
  }
}

void kputs(const char *s)
{
  kputs_nnl(s);
  newline();
  kfflush();
}

static void kprintu(unsigned long long int num)
{
  static char buf[20];
  int i;
  for (i = 19; num > 0; --i) {
    buf[i] = (num % 10) + '0';
    num /= 10;
  }
  while (i <= 9) {
    bufferPutc(buf[i++]);
  }
}

static void kprintx(unsigned long long int num)
{
  static char buf[16];
  int i;
  for (i = 15; num > 0; --i) {
    buf[i] = (num & 0xF);
    num >>= 4;
  }
  while (i <= 9) {
    buf[i] = buf[i] > 9 ? buf[i] + 'A' : buf[i] + '0';
    bufferPutc(buf[i++]);
  }
}

void kprintf(const char *format, ...)
{
  va_list args;
  va_start(args, format);
  while (*format) {
    if (*format == '%') {
      switch (*++format) {
        case '%':
          bufferPutc('%');
          break;
        case 'u':
          kprintu(va_arg(args, unsigned));
          break;
        case 'x':
          kprintx(va_arg(args, unsigned));
          break;
        case 's':
          kputs_nnl(va_arg(args, const char *));
          break;
        case '\0':
          return;
        default: // unknown option
          bufferPutc(*format);
          break;
      }
    } else {
      bufferPutc(*format);
    }
    ++format;
  }
}
