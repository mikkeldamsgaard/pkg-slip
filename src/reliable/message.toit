import binary
import crypto.crc

MESSAGE_TYPE_ACK ::= 0
MESSAGE_TYPE_DATA ::= 1

class ReliableMessage_:
  raw_/ByteArray

  constructor .raw_:

  constructor message_id/int message_type/int payload/ByteArray=#[]:
    raw_ = ByteArray payload.size + 6
    raw_[4] = message_id
    raw_[5] = message_type
    if payload.size > 0:
      raw_.replace 6 payload
    binary.LITTLE_ENDIAN.put_uint32 raw_ 0 (crc.crc32 raw_[4..])

  message_id -> int: return raw_[4]
  message_type -> int: return raw_[5]
  payload -> ByteArray: return raw_[6..]

  verify_checksum -> bool:
    return (crc.crc32 raw_[4..]) == (binary.LITTLE_ENDIAN.read_uint raw_ 4 0)
