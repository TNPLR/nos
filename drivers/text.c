#include <text.h>

#include <kstring.h>
#include <x86.h>

#include <type.h>
#include <stdarg.h>


static __u16 getCursorPosition(void)
{
	__u16 ret;
	outb(0x0F, 0x3D4);
	ret = inb(0x3D5);
	outb(0x0E, 0x3D4);
	ret |= (__u16)inb(0x3D5) << 8;
	return ret;
}

static void setCursorPosition(__u16 position)
{
	outb(0x0F, 0x3D4);
	outb(position & 0xFF, 0x3D5);
	outb(0x0E, 0x3D4);
	outb((position >> 8) & 0xFF, 0x3D5);
}

static __u16 *screen_start_addr = (__u16 *)0xB8000;
static __u16 *buffer_start_addr = (__u16 *)0xB9000;
static __u16 buffer_cursor_position = 0;

void initText(void)
{
	memcpy(buffer_start_addr, screen_start_addr, 0xFA0);
	buffer_cursor_position = getCursorPosition();
}

void bufferScroll(void)
{
	memcpy(buffer_start_addr, buffer_start_addr + 80, 0xE60);
	buffer_cursor_position = buffer_cursor_position - (buffer_cursor_position % 80);
	memset(buffer_start_addr + 0x730, 0, 0x140); 
}

void kfflush(void)
{
	memcpy(screen_start_addr, buffer_start_addr, 0xFA0);
	setCursorPosition(buffer_cursor_position);
}

static void newline(void)
{
	buffer_cursor_position += 80 - buffer_cursor_position % 80;
	if (buffer_cursor_position >= 0x780) {
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
	case '\t':
		buffer_cursor_position = (buffer_cursor_position & (~7)) + 8;
		break;
	default:
		*(buffer_start_addr + buffer_cursor_position++) = (__u16)COLOR << 8 | ch;
		break;
	}

	if (buffer_cursor_position >= 1920) {
		newline();
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

static void kprintu(__u64 num)
{
	static char buf[20];
	int i;
	for (i = 19; num > 0; --i) {
		buf[i] = (num % 10) + '0';
		num /= 10;
	}
	while (i <= 19) {
		bufferPutc(buf[i++]);
	}
}

static void kprintx(__u64 num)
{
	static char buf[16];
	int i;
	for (i = 15; num > 0; --i) {
		buf[i] = (num & 0xF);
		num >>= 4;
	}
	while (i <= 15) {
		bufferPutc(buf[i] > 9 ? (buf[i]-10 + 'A') : (buf[i] + '0'));
		++i;
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
				kprintu(va_arg(args, __u32));
				break;
			case 'x':
				kprintx(va_arg(args, __u32));
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
	kfflush();
	va_end(args);
}
