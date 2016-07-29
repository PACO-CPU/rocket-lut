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
CMD_CFG_CONTROLLER_DELAY = 0x0c
CMD_CFG_INPUT_DECODER_DELAY = 0x0a
CMD_CFG_ADDRESS_TRANSLATOR_DELAY = 0x08
CMD_CFG_INTERPOLATOR_DELAY = 0x09

CMD_CORE_RST = 0x30
CMD_CORE_STAT = 0x31
CMD_CORE_EXE = 0x32
CMD_CORE_CFG = 0x33
CMD_CORE_EXE_BEGIN = 0x34

CMD_DIAG_CLOCK_COUNTER = 0x40
CMD_DIAG_OUTPUT_COUNTER = 0x41

## Common interface for hardware tests.
#
# Connects to a hardware test instantiation via UART connection and maintains
# a set of architecture-specific constants by querying them from the
# hardware test.
# Also offers methods for interfacing common command-and-response patterns
# with the hardware test.

class IFace(serial.Serial):
  
  def __init__(s,port=None,baud=921600):
    if port!=None:
      serial.Serial.__init__(s,port=port,baudrate=baud)
    s._word_size=64
    s._selector_bits=8
    s._interpolation_bits=8
    s._segment_bits=4
    s._pla_interconnects=12
    s._base_bits=48
    s._incline_bits=32
    s._input_words=1
    
    s._controller_delay=1
    s._input_decoder_delay=1
    s._address_translator_delay=1
    s._interpolator_delay=4
  
  ## Executes a command with no response and zero or one words of details.
  #
  # @param cmd command (`CMD_*`) constant to execute, must be between 0 and 255.
  # @param data Optional word of data (must be between 0 and 2^WORD_SIZE-1).
  def command0(s,cmd,data=None):
    if data==None:
      raw=struct.pack("<B",cmd)
    else:
      if s._word_size==32:
        raw=struct.pack("<BI",cmd,data)
      else:
        raw=struct.pack("<BQ",cmd,data)
    s.write(raw)
  
  ## Executes a command with no response and a single data value represented as
  # a pipeline input.
  #
  # @param cmd command (`CMD_*`) constant to execute, must be between 0 and 255.
  # @param data Data value to be encoded as a tuple of INPUT_WORDS words.
  def command0i(s,cmd,data=None):
    words=[
      (data>>(s.WORD_SIZE*shamt))&((1<<s.WORD_SIZE)-1)
      for shamt in reversed(range(s.INPUT_WORDS))]

    ty="I" if s._word_size==32 else "Q"
    raw=struct.pack("<B%s"%(ty*s.INPUT_WORDS),cmd,*words)
    s.write(raw)
  
  ## Executes a command with a single byte response and zero or one words of
  # data.
  #
  # @param cmd command (`CMD_*`) constant to execute, must be between 0 and 255.
  # @param data Optional word of data (must be between 0 and 2^WORD_SIZE-1).
  # @return A single byte, as integer

  def command8(s,cmd,data=None):
    if data==None:
      raw=struct.pack("<B",cmd)
    else:
      if s._word_size==32:
        raw=struct.pack("<BI",cmd,data)
      else:
        raw=struct.pack("<BQ",cmd,data)
    s.write(raw)
    raw=s.read(1)
    return struct.unpack("<B",raw)[0]
    
  ## Executes a command with a single word response and zero or one words of
  # data.
  #
  # @param cmd command (`CMD_*`) constant to execute, must be between 0 and 255.
  # @param data Optional word of data (must be between 0 and 2^WORD_SIZE-1).
  # @return A single word, as integer
  def command(s,cmd,data=None):
    if data==None:
      raw=struct.pack("<B",cmd)
    else:
      if s._word_size==32:
        raw=struct.pack("<BI",cmd,data)
      else:
        raw=struct.pack("<BQ",cmd,data)
    s.write(raw)
    if s._word_size==32:
      raw=s.read(4)
      return struct.unpack("<I",raw[:4])[0]
    else:
      raw=s.read(8)
      return struct.unpack("<Q",raw[:8])[0]

  ## Executes a command with a single word response and a 4-tuple of data
  # represented as input to the interpolation unit.
  #
  # The 4-tuple is represented by first creating a bit-vector concatenation of
  # the four data inputs (selector, interpolator, base, incline) and then 
  # sending it with as many words as needed to cover all bits.
  #
  # @param cmd command (`CMD_*`) constant to execute, must be between 0 and 255.
  # @param selector First part of the 4-tuple of data.
  # @param interpolator Second part of the 4-tuple of data.
  # @param base Third part of the 4-tuple of data.
  # @param incline Fourth part of the 4-tuple of data.
  # @return A single word, as integer
  def command_inter(s,cmd,selector,interpolator,base,incline):
    word=0
    word=(word<<s.SELECTOR_BITS) | selector
    word=(word<<s.INTERPOLATION_BITS) | interpolator 
    word=(word<<s.BASE_BITS) | base
    word=(word<<s.INCLINE_BITS) | incline
    
    byte_count=math.ceil(
      (s.SELECTOR_BITS+s.INTERPOLATION_BITS+s.BASE_BITS+s.INCLINE_BITS)/32)*4

    raw=bytes([cmd]+[(word>>(8*shamt))&0xff for shamt in range(byte_count)])
    
    s.write(raw)
    if s._word_size==32:
      raw=s.read(4)
      return struct.unpack("<I",raw[:4])[0]
    else:
      raw=s.read(8)
      return struct.unpack("<Q",raw[:8])[0]
  
  ## Executes a command with a single word response and a single data value 
  # represented as a pipeline input.
  #
  # @param cmd command (`CMD_*`) constant to execute, must be between 0 and 255.
  # @param data Data value to be encoded as a tuple of INPUT_WORDS words.
  # @return A single word, as integer
  def commandi(s,cmd,data):
    words=[
      (data>>(s.WORD_SIZE*shamt))&((1<<s.WORD_SIZE)-1)
      for shamt in reversed(range(s.INPUT_WORDS))]
    
    ty="I" if s._word_size==32 else "Q"

    raw=struct.pack("<B%s"%(ty*s.INPUT_WORDS),cmd,*words)
    s.write(raw)
    if s._word_size==32:
      raw=s.read(4)
      return struct.unpack("<I",raw[:4])[0]
    else:
      raw=s.read(8)
      return struct.unpack("<Q",raw[:8])[0]

  ## Queries architecture-specific parameters from the connected hardware test
  # core.
  #
  # This updates the values for all properties except for WORD_SIZE and 
  # CFG_WORD_SIZE, which are hard-coded.
  def load_config(s):
    s._input_words=s.command8(CMD_CFG_INPUT_WORDS)
    s._selector_bits=s.command8(CMD_CFG_SELECTOR_BITS)
    s._interpolation_bits=s.command8(CMD_CFG_INTERPOLATION_BITS)
    s._segment_bits=s.command8(CMD_CFG_SEGMENT_BITS)
    s._pla_interconnects=s.command8(CMD_CFG_PLA_INTERCONNECTS)
    s._base_bits=s.command8(CMD_CFG_BASE_BITS)
    s._incline_bits=s.command8(CMD_CFG_INCLINE_BITS)

    s._controller_delay=s.command8(CMD_CFG_CONTROLLER_DELAY)
    s._input_decoder_delay=s.command8(CMD_CFG_INPUT_DECODER_DELAY)
    s._address_translator_delay=s.command8(CMD_CFG_ADDRESS_TRANSLATOR_DELAY)
    s._interpolator_delay=s.command8(CMD_CFG_INTERPOLATOR_DELAY)
  
  ## Performs a test case common to all hardware tests, ensuring that the
  # test state machine itself is reachable and operational.
  def test_echo(s):
    for i in range(100):
      x=random.randint(0,0xffffffff)
      y=s.command(CMD_ECHO,x)
      if x!=y: 
        print(
          "echo did not respond properly: expected %.8x, got %.8x"%(x,y))
  
  ## Tests a configuration daisy-chain by filling it, emptying it and checking
  # the returned words.
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
  
  ## Outputs details of the previously queried configuration data on stdout.
  def print_config(s):
    print("  word size: .............. %s"%s.WORD_SIZE)
    print("  input words: ............ %s"%s.INPUT_WORDS)
    print("  selector bits: .......... %s"%s.SELECTOR_BITS)
    print("  interpolation bits: ..... %s"%s.INTERPOLATION_BITS)
    print("  segment bits: ........... %s"%s.SEGMENT_BITS)
    print("  pla interconnects: ...... %s"%s.PLA_INTERCONNECTS)
    print("  base bits: .............. %s"%s.BASE_BITS)
    print("  incline bits: ........... %s"%s.INCLINE_BITS)
    print("  controller delay: ....... %s"%s.CONTROLLER_DELAY)
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
  def CONTROLLER_DELAY(s):
    return s._controller_delay

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
    return s.BASE_BITS+s.INCLINE_BITS

  @property
  def RAM_CONFIG_BUFFER_SIZE(s):
    return math.ceil(s.LUT_BRAM_WIDTH/s.CFG_WORD_SIZE)

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
