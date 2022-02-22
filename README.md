## SLIP implementation for toit

This package contains an implementation of SLIP for message encapsulation on a serial line. It works with toit's port library package

The protocol works with delimiting all messages with an escape sequence 0xC0

If a 0xC0 appears in data, it is replaced by 0xDB 0xDC. 0xDB in the stream in turn will be replaced by 0xDB 0xDD

The [esp serial flasher protocol](https://docs.espressif.com/projects/esptool/en/latest/esp32/advanced-topics/serial-protocol.html) uses this transport mechanism 