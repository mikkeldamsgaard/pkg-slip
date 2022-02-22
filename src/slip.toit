import gpio show Pin
import uart 
import bytes show Buffer
import log show  default Logger
import encoding.hex

SLIP_DELIMETER_      ::= 0xC0
SLIP_ESCAPE_         ::= 0xDB
SLIP_C0_REPLACEMENT_ ::= #[SLIP_ESCAPE_, 0xDC]
SLIP_DB_REPLACEMENT_ ::= #[SLIP_ESCAPE_, 0xDD] 


class Slip:
  logger/Logger ::= default.with_name "slip"

  port_/uart.Port
  parsed_/List := []
  remaining_/ByteArray := #[]
  want_escape_/bool := false

  constructor --rx_pin/Pin  --tx_pin/Pin --baud_rate/int:
    port_ = uart.Port --rx=rx_pin --tx=tx_pin --baud_rate=baud_rate 
    
  send message/ByteArray:
    buf := Buffer.with_initial_size (message.size*1.1+2).to_int
    buf.put_byte SLIP_DELIMETER_
    message.do:
      if it == 0xC0: buf.write SLIP_C0_REPLACEMENT_
      else if it == 0xDB: buf.write SLIP_DB_REPLACEMENT_
      else: buf.put_byte it
    buf.put_byte SLIP_DELIMETER_
    
    port_.write 
        buf.bytes

  receive --timeout_ms=250 -> ByteArray:
    while true:
        if parsed_.size != 0: return parsed_.remove_last
        
        bytes := port_.read
        logger.debug "SLIP: read some bytes: $bytes.size"
        add_to_parsed bytes

  add_to_parsed bytes/ByteArray:
    assert: parsed_.size == 0
    decoded := Buffer.with_initial_size bytes.size
    logger.debug "SLIP bytes read: $(hex.encode bytes)"
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

  change_baud_rate baud_rate/int:
    port_.set_baud_rate baud_rate

  close:
    port_.close