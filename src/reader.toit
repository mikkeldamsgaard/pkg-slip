import bytes show Buffer
import reader show Reader

import .constants

class SlipReader:
  parsed_/Deque := Deque
  current_message_/Buffer? := null
  want_escape_/bool := false
  reader/Reader

  constructor .reader/Reader:

  /**
  Receives the next encapsulated message akipping all bytes received outside delimters.
  This method blocks until a message has been fully received.
  */
  receive -> ByteArray:
    while true:
      if parsed_.size != 0:
        msg/ByteArray := parsed_.remove_first
        print "parsed size: $msg.size"
        return msg

      bytes := reader.read
      print "<<<< $bytes.to_string_non_throwing"
      add_to_parsed_ bytes

  add_to_current_message byte/int:
    if current_message_: current_message_.write_byte byte

  add_to_parsed_ bytes/ByteArray:
    assert: parsed_.size == 0

    bytes.do:
      if want_escape_:
        if it == 0xDC: add_to_current_message SLIP_DELIMETER_
        else if it == 0xDD: add_to_current_message SLIP_ESCAPE_
        else: throw "Byte encoding error, expected 0xDC or 0xDD, but received: 0x$(%x it)"
        want_escape_ = false
      else:
        if it == SLIP_ESCAPE_: want_escape_ = true
        else if it == SLIP_DELIMETER_:
          if current_message_:
            parsed_.add current_message_.bytes
            current_message_ = null
          else:
            current_message_ = Buffer.with_initial_size 25
        else:
          add_to_current_message it
      yield
