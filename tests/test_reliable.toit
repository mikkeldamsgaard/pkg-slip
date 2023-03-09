import reader
import writer
import test
import monitor

import reader
import monitor show Semaphore

import ..src.slip
import ..src.reliable
import ..src.reliable.message

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

class ReliableStub:
  in/Pipe := Pipe
  out/Pipe := Pipe

  in_reader/SlipReader
  in_writer/SlipWriter

  out_reader/SlipReader
  out_writer/SlipWriter

  reliable/ReliableSlip

  mutex/monitor.Mutex := monitor.Mutex
  constructor:
    in_reader = SlipReader in
    in_writer = SlipWriter (writer.Writer in)

    out_reader = SlipReader out
    out_writer = SlipWriter (writer.Writer out)

    reliable = ReliableSlip in_reader out_writer

  other -> ReliableSlip:
    return ReliableSlip out_reader in_writer

  manual_read [handler]:
    msg := ReliableMessage_ out_reader.receive
    handler.call msg

  send_ack msg/ReliableMessage_:
    send_message
        ReliableMessage_ msg.message_id MESSAGE_TYPE_ACK

  send_message msg/ReliableMessage_:
    mutex.do: in_writer.send msg.raw_

test_ping:
  stub := ReliableStub
  other := stub.other

  stub.reliable.send "ping".to_byte_array
  received := other.receive
  test.expect_equals "ping" received.to_string_non_throwing

test_double_ack:
  stub := ReliableStub
  gate := monitor.Gate
  task::
    stub.reliable.send "ping".to_byte_array
    gate.unlock
  stub.manual_read: | msg/ReliableMessage_ |
    stub.send_ack msg
    stub.send_ack msg
    gate.enter
    test.expect_equals "ping" msg.payload.to_string_non_throwing

  gate.lock
  task::
    stub.reliable.send "ping".to_byte_array
    gate.unlock
    stub.reliable.send "ping2".to_byte_array
    gate.unlock

  stub.manual_read: | msg/ReliableMessage_ |
      stub.send_ack msg
      stub.send_ack msg
      gate.enter
      test.expect_equals "ping" msg.payload.to_string_non_throwing
  gate.lock

  stub.manual_read: | msg/ReliableMessage_ |
      stub.send_ack msg
      gate.enter
      test.expect_equals "ping2" msg.payload.to_string_non_throwing

test_ignore_retransmitted:
  stub := ReliableStub
  msg := ReliableMessage_ 0 MESSAGE_TYPE_DATA "ping".to_byte_array

  stub.send_message msg
  stub.send_message msg

  msg2 := stub.reliable.receive
  test.expect_equals "ping" msg2.to_string_non_throwing

  e := catch:
    with_timeout --ms=50:
      stub.reliable.receive

  test.expect_equals DEADLINE_EXCEEDED_ERROR e

test_retransmit:
  stub := ReliableStub
  gate := monitor.Gate

  task::
    stub.reliable.send "ping".to_byte_array
    gate.unlock

  stub.manual_read: | msg/ReliableMessage_ |
    test.expect_equals "ping" msg.payload.to_string_non_throwing

  stub.manual_read: | msg/ReliableMessage_ |
    test.expect_equals "ping" msg.payload.to_string_non_throwing
    stub.send_ack msg
    gate.enter

test_crc_error:
  stub := ReliableStub
  msg_with_crc_error := ReliableMessage_ 0 MESSAGE_TYPE_DATA "ping".to_byte_array
  msg_with_crc_error.raw_[0] = ~msg_with_crc_error.raw_[0]

  stub.send_message msg_with_crc_error
  e := catch:
    with_timeout --ms=50:
      stub.reliable.receive

  test.expect_equals DEADLINE_EXCEEDED_ERROR e

test_message_id_overflow:
  // just send 513 messages
  stub := ReliableStub
  other := stub.other

  task:: 513.repeat: stub.reliable.send "$it".to_byte_array

  with_timeout --ms=2000:
    513.repeat:
      test.expect_equals "$it" other.receive.to_string_non_throwing