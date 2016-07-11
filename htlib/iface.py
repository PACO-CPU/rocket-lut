import serial
import struct
import random
from .error import TestFailure

CMD_ECHO = 0x01
CMD_CFG_WORD = 0x10
CMD_COMPUTE_PLA = 0x21

class IFace(serial.Serial):
  
  def __init__(s,port,baud):
    serial.Serial.__init__(s,port=port,baudrate=baud)

  def command(s,cmd,data):
    raw=struct.pack("<BI",cmd,data)
    s.write(raw)
    raw=s.read(4)
    return struct.unpack("<I",raw)[0]
  
  def test_echo(s):
    for i in range(100):
      x=random.randint(0,0xffffffff)
      y=s.command(CMD_ECHO,x)
      if x!=y: 
        #raise TestFailure(
        print(
          "echo did not respond properly: expected %.8x, got %.8x"%(x,y))

  def test_config(s,count):
    for i in range(count):
      s.command(CMD_CFG_WORD,i+1024)
    for i in range(count):
      old=s.command(CMD_CFG_WORD,i+2048)
      if old!=i+1024:
        print(
          "config did not return the correct word when shifting over: "
          "expected %.8x, got %.8x"
          %(i+1024,old))


