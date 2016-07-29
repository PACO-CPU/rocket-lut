from .iface import *
import random
from collections import namedtuple

## Control class corresponding to ht_input_processor.
#
# Offers facilities for generating a random input processor as well as an
# input word for it; a simulation routine and a configuration bitstream which
# can also be downloaded into a connected hardware test instantiation.
class IDECControl(IFaceRef):
  
  ## type representing an input processor specification.
  #
  # Encapsulates a single array, `choices`.
  specification_t=namedtuple("idec_specification_t","choices")

  ## type representing a compiled input processor.
  #
  # Contains information for generating a bitstream and a method `sim` used
  # for simulating a hardware unit.
  intermediate_t=namedtuple("idec_intermediate_t","choices sim")
  

  ## Generates a random input processor
  #
  # @return a specification ready for use with idec_compile, idec_words and
  # config_idec.
  def random_idec(s):
    choices=[
      random.randint(0,s.iface.INPUT_WORDS*s.iface.WORD_SIZE-1) 
      for i in range(s.iface.SELECTOR_BITS+s.iface.INTERPOLATION_BITS)] 
    return IDECControl.specification_t(choices)
  
  ## Generates a random input decoder input valid for simulation or execution
  # in hardware.
  #
  # This is an input to the first part of the pipeline, thus it also serves as
  # a valid input for the entire lut core.
  def random_idec_input(s):
    return random.randint(0,(1<<(s.iface.WORD_SIZE*s.iface.INPUT_WORDS))-1)
  
  
  ## Compiles an input processor specification into an intermediate 
  # representation.
  #
  # @param args specification e.g. as returned by random_idec.
  # @return intermediate representation fields.
  def idec_compile(s,spec):
    choices=[
      0 if i>=len(spec.choices) else 1<<spec.choices[i]
      for i in range(s.iface.SELECTOR_BITS+s.iface.INTERPOLATION_BITS)]

    def sim(x):
      bits=[ 
        (x>>i)&1 
        for i in range(s.iface.INPUT_WORD_SIZE)]
      r=0
      for i,arg in enumerate(spec.choices):
        r+=bits[arg]<<i
      return r 
    return IDECControl.intermediate_t(choices,sim)
  
  ## compiles an input processor intermediate into configuration words used
  # by the configuration logic.
  #
  # Note that this will return the words in the order as they appear in the
  # input processor hardware. As it is daisy-chained by configuration logic,
  # this sequence must be _reversed_ during configuration.
  def idec_words(s,inter):
    nwords=s.iface.CFG_INPUT_DECODER_REGISTERS_PER_BIT
    words=sum([
      [ 
        (v>>(s.iface.CFG_WORD_SIZE*shamt))&((1<<s.iface.CFG_WORD_SIZE)-1) 
        for shamt in range(nwords) ]
      for v in inter.choices
    ],[])
    return words

  ## Compiles an input processor specification and downloads it to a connected
  # hardware test.
  def config_idec(s,spec):
    words=s.idec_words(spec)
    for w in reversed(words):
      s.iface.command(CMD_CFG_WORD,w)


