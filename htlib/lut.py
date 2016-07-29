from .iface import *
import random
from collections import namedtuple

class LUTControl(IFaceRef):
 
  intermediate_t=namedtuple("lut_intermediate_t","cells sim") 

  def random_lut(s):
    cells=[
      random.randint(0,(1<<(s.iface.LUT_BRAM_WIDTH))-1)
      for i in range(1<<s.iface.SEGMENT_BITS)
      ]
    return cells

  def random_lut_input(s):
    return random.randint(0,(1<<s.iface.SEGMENT_BITS)-1)

  def lut_compile(s,*cells):
    
    bits=[
      [ (v>>shamt)&1 for shamt in range(s.iface.LUT_BRAM_WIDTH) ]
      for v in cells]

    words=[
      sum([ bit<<shamt for shamt,bit in enumerate(bv)])
      for bv in bits]
    
    def sim(x):
      return cells[x]
    
    return words,sim

  def lut_words(s,choices):
    nwords=s.iface.RAM_CONFIG_BUFFER_SIZE
    words=sum([
      [ 
        (v>>(s.iface.CFG_WORD_SIZE*shamt))&((1<<s.iface.CFG_WORD_SIZE)-1) 
        for shamt in range(nwords) ]
      for v in choices
    ],[])
    return words


