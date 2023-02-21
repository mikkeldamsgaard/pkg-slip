import test
import bytes
import writer
import reader

import ..src.slip show SlipReader SlipWriter

test_incomplete:
  buffer := bytes.Buffer

  slip_writer := SlipWriter (writer.Writer buffer)
  slip_writer.send #[1]
  slip_writer.send #[2]

  slip_reader := SlipReader (bytes.Reader buffer.bytes[1..])

  test.expect_equals #[2] slip_reader.receive
  test.expect_null (print slip_reader.receive)

test_incomplete_on_boundary:
  buffer := bytes.Buffer

  slip_writer := SlipWriter (writer.Writer buffer)
  slip_writer.send #[1]
  slip_writer.send #[2]

  slip_reader := SlipReader (bytes.Reader buffer.bytes[2..])

  test.expect_equals #[2] slip_reader.receive
  test.expect_null (print slip_reader.receive)

test_only_delimeter:
  buffer := bytes.Buffer

  slip_writer := SlipWriter (writer.Writer buffer)
  slip_writer.send #[]

  slip_reader := SlipReader (bytes.Reader buffer.bytes[1..])

  test.expect_null (print slip_reader.receive)

test_empty:
  buffer := bytes.Buffer

  slip_writer := SlipWriter (writer.Writer buffer)
  slip_writer.send #[]

  slip_reader := SlipReader (bytes.Reader buffer.bytes)
  test.expect_null slip_reader.receive

test_out_of_band:
  buffer := bytes.Buffer
  buffer_writer := writer.Writer buffer
  slip_writer := SlipWriter (writer.Writer buffer)
  slip_writer.send #['x']
  buffer_writer.write #['y']
  slip_writer.send #['z']

  slip_reader := SlipReader (bytes.Reader buffer.bytes)
  test.expect_equals #['x'] slip_reader.receive
  test.expect_equals #['z'] slip_reader.receive

class ListReader implements reader.Reader:
  bufs/List
  index/int := 0
  constructor .bufs:

  read -> ByteArray?:
    if index < bufs.size:
      print "Returning chunk $index, size: $(bufs[index].size): $bufs[index]"
      return bufs[index++]
    else:
      return null

test_broken_up_reads:
  set_random_seed "seed"

  buf := ByteArray 8192
  8192.repeat: buf[it] = random 256

  buffer := bytes.Buffer
  buffer_writer := writer.Writer buffer
  slip_writer := SlipWriter (writer.Writer buffer)
  slip_writer.send buf
  encoded_buffer := buffer.bytes
  bufs/List := List
  List.chunk_up 0 encoded_buffer.size 1000 : | from to size |
     bufs.add encoded_buffer[from..to]

  list_reader := ListReader bufs

  slip_reader := SlipReader list_reader
  received_buf := slip_reader.receive

  test.expect_equals buf received_buf

class ChunkWriter:
  bufs/List := List
  write buf/ByteArray -> int:
    if buf.size > 100:
      bufs.add buf[0..100]
      return 100
    else:
      bufs.add buf[0..buf.size]
      return buf.size

test_broken_up_writes:
  set_random_seed "seed"

  buf := ByteArray 8192
  8192.repeat: buf[it] = random 256

  chunk_writer := ChunkWriter
  slip_writer := SlipWriter (writer.Writer chunk_writer)
  slip_writer.send buf

  list_reader := ListReader chunk_writer.bufs
  slip_reader := SlipReader list_reader
  received := slip_reader.receive

  test.expect_equals buf received

main args:
  test.add_test "test_incomplete":: test_incomplete
  test.add_test "test_incomplete_on_boundary":: test_incomplete_on_boundary
  test.add_test "test_only_delimeter":: test_only_delimeter
  test.add_test "test_empty":: test_empty
  test.add_test "test_out_of_band":: test_out_of_band
  test.add_test "test_broken_up_reads":: test_broken_up_reads
  test.add_test "test_broken_up_writes":: test_broken_up_writes
  test.run args