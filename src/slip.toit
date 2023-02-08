import gpio show Pin
import uart 
import bytes show Buffer
import log
import encoding.hex
import writer show Writer
import monitor

import .constants
import .reader
import .writer

export SlipReader SlipWriter

/**
Implements the slip protocol
*/
class Slip:
  port_/uart.Port
  reader_/SlipReader
  writer_/SlipWriter

  /**
  Constructs a slip protocol running on the given pins. $rx_pin for receiving data and $tx_pin for transmitting
  data. The port will operate at speed $baud_rate.
  */
  constructor --rx_pin/Pin  --tx_pin/Pin --baud_rate/int:
    port_ = uart.Port --rx=rx_pin --tx=tx_pin --baud_rate=baud_rate
    writer_ = SlipWriter (Writer port_)
    reader_ = SlipReader port_
  /**
  Constructs a slip protocol running on the given uart $port.
  */
  constructor --port/uart.Port:
    port_ = port
    writer_ = SlipWriter (Writer port_)
    reader_ = SlipReader port_

  /**
  Encapsulates and transmits the $message.
  */
  send message/ByteArray: writer_.send message

  /**
  Receives the next encapsulated message akipping all bytes received outside delimters. 
  This method blocks until a message has been fully received.
  */
  receive -> ByteArray: return reader_.receive

  /**
  Changes the baud rate of the port to $baud_rate.
  */
  change_baud_rate baud_rate/int:
    port_.baud_rate = baud_rate

  /**
  Closes this slip protocol
  */
  close:
    port_.close
