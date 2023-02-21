import test

import monitor show Semaphore
import writer show Writer
import ..src.slip show SlipReader SlipWriter
import ..src.constants
import reader
import bytes

class Pipe implements reader.Reader:
  pipe/Deque := Deque
  semaphore/Semaphore := Semaphore
  write buf -> int:
    pipe.add buf
    semaphore.up
    return buf.size

  read:
    semaphore.down
    return pipe.remove_first

do_transmit buf/ByteArray message/string:
  pipe/Pipe := Pipe
  reader := SlipReader pipe
  writer := SlipWriter (Writer pipe)

  writer.send buf

  test.expect_equals buf reader.receive message

test_one_byte:
  do_transmit #[1] "Sending and receiving one-byte array"

test_delimiter:
  do_transmit #[SLIP_DELIMETER_] "Sending delimiter"

test_escape:
  do_transmit #[SLIP_ESCAPE_] "Sending escape"

test_replacement:
  do_transmit SLIP_C0_REPLACEMENT_ "Sending replacement"
  do_transmit SLIP_DB_REPLACEMENT_ "Sending replacement"

test_big_random:
  set_random_seed "seed"

  buf := ByteArray 8192
  8192.repeat: buf[it] = random 256

  do_transmit buf "Random big buffer"

main args:
  test.add_test "one_byte" :: test_one_byte
  test.add_test "delimiter" :: test_delimiter
  test.add_test "escape" :: test_escape
  test.add_test "replacements" :: test_replacement
  test.add_test "big_random" :: test_big_random
  test.run args