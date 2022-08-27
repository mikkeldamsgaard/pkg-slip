import gpio show Pin
import uart 
import bytes show Buffer
import log show  default Logger
import encoding.hex
import writer show Writer
SLIP_DELIMETER_      ::= 0xC0
SLIP_ESCAPE_         ::= 0xDB
SLIP_C0_REPLACEMENT_ ::= #[SLIP_ESCAPE_, 0xDC]
SLIP_DB_REPLACEMENT_ ::= #[SLIP_ESCAPE_, 0xDD] 
SLIP_DELIMETER_BUF_  ::= #[SLIP_DELIMETER_]

/**
Implements the slip protocol
*/
class Slip:
  port_/uart.Port
  writer_/Writer
  parsed_/List := []
  remaining_/ByteArray := #[]
  want_escape_/bool := false

  /**
  Constructs a slip protocol running on the given pins. $rx_pin for receiving data and $tx_pin for transmitting
  data. The port will operate at speed $baud_rate.
  */
  constructor --rx_pin/Pin  --tx_pin/Pin --baud_rate/int:
    port_ = uart.Port --rx=rx_pin --tx=tx_pin --baud_rate=baud_rate
    writer_ = Writer port_

  /**
  Constructs a slip protocol running on the given uart $port.
  */
  constructor --port/uart.Port:
    port_ = port
    writer_ = Writer port_

  /**
  Encapsulates and transmits the $message.
  */
  send message/ByteArray:
    encapsulated := encapsulate message
    writer_.write encapsulated

  send_encapsulated encapsulated/ByteArray:
    writer_.write encapsulated

  encapsulate message/ByteArray -> ByteArray:
    buf := Buffer.with_initial_size message.size*1.2.to_int
    buf.put_byte SLIP_DELIMETER_

    pos := 0
    while pos<message.size:
      nextC0 := message.index_of 0xC0 --from=pos
      nextDB := message.index_of 0xDB --from=pos

      if nextC0 == -1 and nextDB == -1:
        buf.write message[pos..]
        break

      if nextC0 != -1 and (nextC0 < nextDB or nextDB == -1):
        buf.write message[pos..nextC0]
        buf.write SLIP_C0_REPLACEMENT_
        pos = nextC0+1
      else:
        buf.write message[pos..nextDB]
        buf.write SLIP_DB_REPLACEMENT_
        pos = nextDB+1

    buf.put_byte SLIP_DELIMETER_
    return buf.bytes

  /**
  Receives the next encapsulated message akipping all bytes received outside delimters. 
  This method blocks until a message has been fully received.
  */
  receive -> ByteArray:
    while true:
        if parsed_.size != 0: 
          msg/ByteArray := parsed_.remove_last
          return msg
        
        bytes := port_.read
        add_to_parsed_ bytes

  add_to_parsed_ bytes/ByteArray:
    assert: parsed_.size == 0
    decoded := Buffer.with_initial_size bytes.size
    bytes.do:
      if want_escape_:
        if it == 0xDC: decoded.put_byte SLIP_DELIMETER_
        else if it == 0xDD: decoded.put_byte SLIP_ESCAPE_
        else: throw "Byte encoding error, expected 0xC0 or 0xDB, but received: 0x$(%x it)"
        want_escape_ = false
      else:
        if it == SLIP_ESCAPE_: want_escape_ = true
        else: decoded.put_byte it

    remaining_ = remaining_ + decoded.bytes

    idx := 0
    parsed := []
    end := -1
    while true:
      while remaining_.size > idx and remaining_[idx] != SLIP_DELIMETER_: idx++
      if idx >= remaining_.size: break
      start := idx++

      while remaining_.size > idx and remaining_[idx] != SLIP_DELIMETER_: idx++
      if idx >= remaining_.size: break
      end = idx++

      if start + 1 == end:
        // Out of sequence detection. "Empty" SLIP messages indicate that we started reading in the middle of a message, so adjust
        idx--
        continue

      parsed.add remaining_[start+1..end]

    parsed.do --reversed=true:
      parsed_.add it

    if end != -1:
      remaining_ = remaining_[end+1..].copy

  /**
  Changes the baud rate of the port to $baud_rate.
  */
  change_baud_rate baud_rate/int:
    port_.set_baud_rate baud_rate

  /**
  Closes this slip protocol
  */
  close:
    port_.close