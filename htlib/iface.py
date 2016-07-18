import serial
import struct
import random
import math
from .error import TestFailure

CMD_ECHO = 0x01
CMD_CFG_WORD = 0x10
CMD_COMPUTE_IDEC = 0x22
CMD_COMPUTE_PLA = 0x21
CMD_COMPUTE_INTER = 0x23
CMD_CFG_INPUT_WORDS = 0x0b
CMD_CFG_SELECTOR_BITS = 0x02
CMD_CFG_INTERPOLATION_BITS = 0x03
CMD_CFG_SEGMENT_BITS = 0x04
CMD_CFG_PLA_INTERCONNECTS = 0x05
CMD_CFG_BASE_BITS = 0x06
CMD_CFG_INCLINE_BITS = 0x07
CMD_CFG_INPUT_DECODER_DELAY = 0x0a
CMD_CFG_ADDRESS_TRANSLATOR_DELAY = 0x08
CMD_CFG_INTERPOLATOR_DELAY = 0x09
class IFace(serial.Serial):
  
  def __init__(s,port,baud):
    serial.Serial.__init__(s,port=port,baudrate=baud)
    s._word_size=32
    s._selector_bits=8
    s._interpolation_bits=8
    s._segment_bits=4
    s._pla_interconnects=12
    s._base_bits=48
    s._incline_bits=32
    s._input_words=1
  
    s._address_translator_delay=1
    s._interpolator_delay=4
  
  def command8(s,cmd):
    raw=struct.pack("<B",cmd)
    s.write(raw)
    raw=s.read(1)
    return struct.unpack("<B",raw)[0]
    
  def command(s,cmd,data):
    raw=struct.pack("<BI",cmd,data)
    s.write(raw)
    raw=s.read(4)
    return struct.unpack("<I",raw)[0]

  def command_inter(s,cmd,selector,interpolator,base,incline):
    word=0
    word=(word<<s.SELECTOR_BITS) | selector
    word=(word<<s.INTERPOLATION_BITS) | interpolator 
    word=(word<<s.BASE_BITS) | base
    word=(word<<s.INCLINE_BITS) | incline
    
    byte_count=math.ceil(
      (s.SELECTOR_BITS+s.INTERPOLATION_BITS+s.BASE_BITS+s.INCLINE_BITS)/32)*4

    raw=bytes([cmd]+[(word>>(8*shamt))&0xff for shamt in range(byte_count)])
    
    if False:
      word_count=math.ceil(
        (s.SELECTOR_BITS+s.INTERPOLATION_BITS+s.BASE_BITS+s.INCLINE_BITS)/32)

      words=[
        (word>>(32*shamt))&0xffffffff 
        for shamt in reversed(range(word_count))]

      raw=struct.pack("<B%s"%("I"*word_count),cmd,*words)
      
    s.write(raw)
    raw=s.read(4)
    return struct.unpack("<I",raw[:4])[0]
  
  def commandi(s,cmd,data):
    words=[
      (data>>(s.WORD_SIZE*shamt))&((1<<s.WORD_SIZE)-1)
      for shamt in reversed(range(s.INPUT_WORDS))]
    raw=struct.pack("<B%s"%("I"*s.INPUT_WORDS),cmd,*words)
    s.write(raw)
    raw=s.read(4)
    return struct.unpack("<I",raw)[0]

  def load_config(s):
    s._input_words=s.command8(CMD_CFG_INPUT_WORDS)
    s._selector_bits=s.command8(CMD_CFG_SELECTOR_BITS)
    s._interpolation_bits=s.command8(CMD_CFG_INTERPOLATION_BITS)
    s._segment_bits=s.command8(CMD_CFG_SEGMENT_BITS)
    s._pla_interconnects=s.command8(CMD_CFG_PLA_INTERCONNECTS)
    s._base_bits=s.command8(CMD_CFG_BASE_BITS)
    s._incline_bits=s.command8(CMD_CFG_INCLINE_BITS)

    s._input_decoder_delay=s.command8(CMD_CFG_INPUT_DECODER_DELAY)
    s._address_translator_delay=s.command8(CMD_CFG_ADDRESS_TRANSLATOR_DELAY)
    s._interpolator_delay=s.command8(CMD_CFG_INTERPOLATOR_DELAY)

  def test_echo(s):
    for i in range(100):
      x=random.randint(0,0xffffffff)
      y=s.command(CMD_ECHO,x)
      if x!=y: 
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
  
  def print_config(s):
    print("  word size: .............. %s"%s.WORD_SIZE)
    print("  input words: ............ %s"%s.INPUT_WORDS)
    print("  selector bits: .......... %s"%s.SELECTOR_BITS)
    print("  interpolation bits: ..... %s"%s.INTERPOLATION_BITS)
    print("  segment bits: ........... %s"%s.SEGMENT_BITS)
    print("  pla interconnects: ...... %s"%s.PLA_INTERCONNECTS)
    print("  base bits: .............. %s"%s.BASE_BITS)
    print("  incline bits: ........... %s"%s.INCLINE_BITS)
    print("  input decoder delay: .... %s"%s.INPUT_DECODER_DELAY)
    print("  address translator delay: %s"%s.ADDRESS_TRANSLATOR_DELAY)
    print("  interpolator delay: ..... %s"%s.INTERPOLATOR_DELAY)

  @property
  def WORD_SIZE(s):
    return s._word_size

  @property
  def CFG_WORD_SIZE(s):
    return s.WORD_SIZE

  @property
  def INPUT_WORDS(s):
    return s._input_words

  @property
  def SELECTOR_BITS(s):
    return s._selector_bits

  @property
  def INTERPOLATION_BITS(s):
    return s._interpolation_bits

  @property
  def SEGMENT_BITS(s):
    return s._segment_bits

  @property
  def PLA_INTERCONNECTS(s):
    return s._pla_interconnects

  @property
  def BASE_BITS(s):
    return s._base_bits

  @property
  def INCLINE_BITS(s):
    return s._incline_bits

  @property
  def INPUT_DECODER_DELAY(s):
    return s._input_decoder_delay

  @property
  def ADDRESS_TRANSLATOR_DELAY(s):
    return s._address_translator_delay

  @property
  def INTERPOLATOR_DELAY(s):
    return s._interpolator_delay
  
  @property
  def INPUT_WORD_SIZE(s):
    return s.WORD_SIZE*s.INPUT_WORDS

  @property
  def LUT_BRAM_WIDTH(s):
    return s.RAM_CONFIG_BUFFER_SIZE*(1<<s.SEGMENT_BITS)

  @property
  def RAM_CONFIG_BUFFER_SIZE(s):
    return math.ceil(s.LUT_BRAM_WIDTH/CFG_WORD_SIZE)

  @property
  def RAM_CONFIG_BUFFER_SIZE_BITS(s):
    return s.RAM_CONFIG_BUFFER_SIZE*s.CFG_WORD_SIZE

  @property
  def CFG_LUT_REGISTER_COUNT(s):
    return s.RAM_CONFIG_BUFFER_SIZE*(1<<s.SEGMENT_BITS)

  @property
  def CFG_INPUT_DECODER_REGISTERS_PER_BIT(s):
    return math.ceil(s.INPUT_WORD_SIZE/s.CFG_WORD_SIZE)

  @property
  def CFG_INPUT_DECODER_REGISTER_COUNT(s):
    return (
      s.CFG_INPUT_DECODER_REGISTERS_PER_BIT*
      (s.SELECTOR_BITS+s.INTERPOLATION_BITS)
      )

  @property
  def CFG_PLA_AND_REGISTERS_PER_ROW(s):
    return math.ceil(s.SELECTOR_BITS*2/s.CFG_WORD_SIZE)

  @property
  def CFG_PLA_AND_REGISTER_COUNT(s):
    return s.CFG_PLA_AND_REGISTERS_PER_ROW*s.PLA_INTERCONNECTS

  @property
  def CFG_PLA_OR_REGISTERS_PER_COLUMN(s):
    return math.ceil(s.PLA_INTERCONNECTS/s.CFG_WORD_SIZE)

  @property
  def CFG_PLA_OR_REGISTER_COUNT(s):
    return s.CFG_PLA_OR_REGISTERS_PER_COLUMN*s.SEGMENT_BITS

  @property
  def CFG_PLA_REGISTER_COUNT(s):
    return (
      s.CFG_PLA_AND_REGISTER_COUNT +
      s.CFG_PLA_OR_REGISTER_COUNT )

  @property
  def CFG_CHAIN_REGISTER_COUNT(s):
    return (
      s.CFG_INPUT_DECODER_REGISTER_COUNT +
      s.CFG_PLA_REGISTER_COUNT )

  @property
  def CFG_REGISTER_COUNT(s):
    return s.CFG_LUT_REGISTER_COUNT+s.CFG_CHAIN_REGISTER_COUNT

class IFaceRef:
  def __init__(s,iface):
    s._iface=iface

  @property
  def iface(s):
    return s._iface
