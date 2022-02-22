import gpio show Pin
import uart 
import bytes show Buffer
import log show  default Logger
import encoding.hex

SLIP_DELIMETER_      ::= 0xC0
SLIP_ESCAPE_         ::= 0xDB
SLIP_C0_REPLACEMENT_ ::= #[SLIP_ESCAPE_, 0xDC]
SLIP_DB_REPLACEMENT_ ::= #[SLIP_ESCAPE_, 0xDD] 

/**
Implements the slip protocol
*/
class Slip:
  logger_/Logger ::= default.with_name "slip"

  port_/uart.Port
  parsed_/List := []
  remaining_/ByteArray := #[]
  want_escape_/bool := false

  /**
  Constructs a slip protocol running on the given pins. $rx_pin for receiving data and $tx_pin for transmitting
  data. The port will operate at speed $baud_rate.
  */
  constructor --rx_pin/Pin  --tx_pin/Pin --baud_rate/int:
    port_ = uart.Port --rx=rx_pin --tx=tx_pin --baud_rate=baud_rate 
    
  /**
  Encapsulates and transmits the $message.
  */
  send message/ByteArray:
    buf := Buffer.with_initial_size (message.size*1.1+2).to_int
    buf.put_byte SLIP_DELIMETER_
    message.do:
      if it == 0xC0: buf.write SLIP_C0_REPLACEMENT_
      else if it == 0xDB: buf.write SLIP_DB_REPLACEMENT_
      else: buf.put_byte it
    buf.put_byte SLIP_DELIMETER_

    bytes := buf.bytes
    logger_.info "Sending packet of size $message.size, encoded size $bytes.size"
    port_.write bytes

  /**
  Receives the next encapsulated message akipping all bytes received outside delimters. 
  This method blocks until a message has been fully received.
  */
  receive -> ByteArray:
    while true:
        if parsed_.size != 0: 
          msg/ByteArray := parsed_.remove_last
          logger_.info "Received packet of $msg.size"
          return msg
        
        bytes := port_.read
        logger_.debug "SLIP: read some bytes: $bytes.size"
        add_to_parsed_ bytes

  add_to_parsed_ bytes/ByteArray:
    assert: parsed_.size == 0
    decoded := Buffer.with_initial_size bytes.size
    bytes.do:
      if want_escape_:
        if it == 0xDC: decoded.put_byte SLIP_DELIMETER_
        else if it == 0xDD: decoded.put_byte SLIP_ESCAPE_
        else: throw "Byte encoding error, expected 0xC0 or 0xDB, but received: 0x$(%x it)"
        want_escape_ = false;
      else:
        if it == SLIP_ESCAPE_: want_escape_ = true;
        else: decoded.put_byte it

    remaining_ = remaining_ + decoded.bytes

    idx := 0
    parsed := []
    end := -1
    while true:
      while remaining_.size > idx and remaining_[idx] != SLIP_DELIMETER_: idx++
      if idx >= remaining_.size: break;
      start := idx++

      while remaining_.size > idx and remaining_[idx] != SLIP_DELIMETER_: idx++
      if idx >= remaining_.size: break;
      end = idx++;

      //log "Add parsed. $start - $end, first=0x$(%x remaining_[0]), size=$remaining_.size"
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