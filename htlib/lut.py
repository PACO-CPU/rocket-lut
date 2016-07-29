from .iface import *
import random
from collections import namedtuple

## Control class for the lookup table pipeline stage.
#
# Offers facilities for generating random lookup tables, inputs and a simulation
# method.
# As no hardware test exists for this component, no configuration routine is
# available.
class LUTControl(IFaceRef):
  
  ## Represents a raw specification of a lookup table
  specification_t=namedtuple("lut_specification_t","cells")
  
  ## Represents a compiled lookup table for use in generating bitstreams
  # and a simulation method used for validating the lookup stage.
  intermediate_t=namedtuple("lut_intermediate_t","cells sim") 
  

  ## Generates a random lookup table specification
  #
  # @returns specification of type specification_t ready for use in lut_compile.
  def random_lut(s):
    cells=[
      random.randint(0,(1<<(s.iface.LUT_BRAM_WIDTH))-1)
      for i in range(1<<s.iface.SEGMENT_BITS)
      ]
    return LUTControl.specification_t(cells)
  
  ## Generates a random input for the lookup stage itself.
  def random_lut_input(s):
    return random.randint(0,(1<<s.iface.SEGMENT_BITS)-1)
  

  ## Compiles a lookup specification into a lookup intermediate.
  #
  # Outputs the intermediate words and simulation method as an instance of
  # intermediate_t.
  def lut_compile(s,spec):
    
    bits=[
      [ (v>>shamt)&1 for shamt in range(s.iface.LUT_BRAM_WIDTH) ]
      for v in spec.cells]

    words=[
      sum([ bit<<shamt for shamt,bit in enumerate(bv)])
      for bv in bits]
    
    def sim(x):
      return spec.cells[x]
    
    return LUTControl.intermediate_t(words,sim)
  
  ## Translates an intermediate lookup table representation into a list of
  # configuration words.
  #
  # Note that in contrast to all other cores, this data is transmitted via a
  # random-access interface, thus the words occur in _correct_ order.
  def lut_words(s,inter):
    nwords=s.iface.RAM_CONFIG_BUFFER_SIZE
    words=sum([
      [ 
        (v>>(s.iface.CFG_WORD_SIZE*shamt))&((1<<s.iface.CFG_WORD_SIZE)-1) 
        for shamt in range(nwords) ]
      for v in inter.cells
    ],[])
    return words


