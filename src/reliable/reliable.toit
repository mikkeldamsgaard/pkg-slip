import ..reader
import ..writer
import .message
import monitor

class ReliableSlip:
  slip_reader_/SlipReader
  slip_writer_/SlipWriter
  reader_task_/Task? := null
  incomming_/monitor.Channel

  ack_channel_/monitor.Channel := monitor.Channel 1

  send_mutex_/monitor.Mutex := monitor.Mutex
  slip_send_mutex_/monitor.Mutex := monitor.Mutex
  next_message_id_/int := 0
  received_message_id_/int? := null
  ack_processing_overheader_ms/int
  linespeed_bytes_per_second/int

  constructor .slip_reader_ .slip_writer_ --receive_buffer_size/int=5 --.ack_processing_overheader_ms/int=500 --.linespeed_bytes_per_second/int=11520:
    incomming_ = monitor.Channel receive_buffer_size
    reader_task_ = task :: run_reader_

  close:
    reader_task_.cancel

  receive -> ByteArray : return incomming_.receive

  send payload/ByteArray --ack_timeout_ms/int?=null:
    send_mutex_.do:
      msg := ReliableMessage_ next_message_id_ MESSAGE_TYPE_DATA payload
      next_message_id_ = (next_message_id_ + 1) % 0x100
      if not ack_timeout_ms:
        ack_timeout_ms = ack_processing_overheader_ms +
            msg.raw_.size * 1000 / linespeed_bytes_per_second

      retry_count := 5
      while true:
        send_ msg
        catch --unwind=(:it != DEADLINE_EXCEEDED_ERROR):
          with_timeout --ms=ack_timeout_ms:
            while true:
              ack_msg/ReliableMessage_ := ack_channel_.receive
              if ack_msg.message_id == msg.message_id:
                return
  //      print "timeout: msg_id: $msg.message_id, size: $payload.size, ack_timeout_ms: $ack_timeout_ms"
        if retry_count-- == 0: throw "Timeout waiting for ACK"

  send_ message/ReliableMessage_:
    slip_send_mutex_.do: slip_writer_.send message.raw_

  run_reader_:
    catch --unwind=(: it != CANCELED_ERROR):
      while true:
        msg := null
        e := catch --unwind=(: it == CANCELED_ERROR):
          msg = ReliableMessage_ slip_reader_.receive
          if not msg.verify_checksum:
             print "[warn] crc error"
             continue
        if e:
          print "[warn] slip error: $e"
          continue

        if msg.message_type == MESSAGE_TYPE_ACK:
          ack_channel_.try_send msg
        else:
          send_ (ReliableMessage_ msg.message_id MESSAGE_TYPE_ACK)
          //print "Acked $msg.message_id"
          if not received_message_id_ or
             received_message_id_ < msg.message_id or
             msg.message_id < received_message_id_ - 128: // For wrap around message ids.
            incomming_.send msg.payload
            received_message_id_ = msg.message_id
            if received_message_id_ == 0xFF: received_message_id_ = null