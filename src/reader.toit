import bytes show Buffer
import reader show Reader
import encoding.url

import .constants

STATE_WANT_ESCAPE_     ::= 0
STATE_PARSING_MESSAGE_ ::= 1
STATE_BETWEEN_MESSAGES_        ::= 2

class SlipReader:
  parsed_/Deque := Deque
  current_message_/Buffer? := null
  state_/int := STATE_BETWEEN_MESSAGES_

  want_escape_/bool := false
  in_message_/bool := false
  reader/Reader

  constructor .reader/Reader:

  /**
  Receives the next encapsulated message akipping all bytes received outside delimters.
  This method blocks until a message has been fully received.

  Returns null on end of stream.
  */
  receive -> ByteArray?:
    while true:
      if parsed_.size != 0:
        msg/ByteArray := parsed_.remove_first
        return msg

      bytes := reader.read
      if not bytes: return null

      add_to_parsed_ bytes

  add_to_current_message byte/int:
    if current_message_: current_message_.write_byte byte

  add_to_parsed_ bytes/ByteArray:
    assert: parsed_.size == 0
    block_start := 0
    for pos := 0; pos < bytes.size; pos++:
      current ::= bytes[pos]
      if state_ == STATE_BETWEEN_MESSAGES_:
        if current == SLIP_DELIMETER_:
          current_message_ = Buffer.with_initial_size 25
          state_ = STATE_PARSING_MESSAGE_
          block_start = pos + 1
      else if state_ == STATE_PARSING_MESSAGE_:
        if current == SLIP_ESCAPE_:
          current_message_.write bytes[block_start..pos]
          state_ = STATE_WANT_ESCAPE_
        else if current == SLIP_DELIMETER_:
          if current_message_.size == 0 and block_start == pos:
            // Two delimeters have been detected right after each other. This most probably mean
            // that the parsing started in the middle of a stream. The action taken is to ignore
            // one of the delimeters
            block_start = pos + 1
          else:
            current_message_.write bytes[block_start..pos]
            parsed_.add current_message_.bytes
            state_ = STATE_BETWEEN_MESSAGES_
      else if state_ == STATE_WANT_ESCAPE_:
        if current == 0xDC: current_message_.write_byte SLIP_DELIMETER_
        else if current == 0xDD: current_message_.write_byte SLIP_ESCAPE_
        else: throw "Byte encoding error, expected 0xDC or 0xDD, but received: 0x$(%x current)"
        state_ = STATE_PARSING_MESSAGE_
        block_start = pos + 1
      else:
        unreachable
    if state_ == STATE_PARSING_MESSAGE_ and block_start != bytes.size:
      current_message_.write bytes[block_start..]
