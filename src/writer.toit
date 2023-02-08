import gpio show Pin
import uart 
import bytes show Buffer
import log
import encoding.hex
import writer show Writer
import monitor

import .constants

/**
Implements the slip protocol
*/
class SlipWriter:
  writer_/Writer

  constructor .writer_/Writer:

  /**
  Encapsulates and transmits the $message.
  */
  send message/ByteArray:
    send_encapsulated_
        encapsulate_ message

  send_encapsulated_ encapsulated/ByteArray:
    size := encapsulated.size
    from := 0
    while from < size:
      written := writer_.write encapsulated[from..size]
      print ">>>>  $(encapsulated[from..from+written].to_string_non_throwing)"
      from += written
      if from != size:
        yield

    //writer_.write encapsulated

  encapsulate_ message/ByteArray -> ByteArray:
    buf := Buffer.with_initial_size message.size*1.2.to_int
    buf.write_byte SLIP_DELIMETER_

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

    buf.write_byte SLIP_DELIMETER_
    return buf.bytes

