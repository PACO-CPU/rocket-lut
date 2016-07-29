from .iface import *
import random
from collections import namedtuple

class IDECControl(IFaceRef):
  
  intermediate_t=namedtuple("idec_intermediate_t","choices sim")

  def random_idec(s):
    choices=[
      random.randint(0,s.iface.INPUT_WORDS*s.iface.WORD_SIZE-1) 
      for i in range(s.iface.SELECTOR_BITS+s.iface.INTERPOLATION_BITS)] 
    return choices

  def random_idec_input(s):
    return random.randint(0,(1<<(s.iface.WORD_SIZE*s.iface.INPUT_WORDS))-1)

  def idec_compile(s,*args):
    choices=[
      0 if i>=len(args) else 1<<args[i]
      for i in range(s.iface.SELECTOR_BITS+s.iface.INTERPOLATION_BITS)]

    def sim(x):
      bits=[ 
        (x>>i)&1 
        for i in range(s.iface.INPUT_WORD_SIZE)]
      r=0
      for i,arg in enumerate(args):
        r+=bits[arg]<<i
      return r 
    return choices,sim

  def idec_words(s,choices):
    nwords=s.iface.CFG_INPUT_DECODER_REGISTERS_PER_BIT
    words=sum([
      [ 
        (v>>(s.iface.CFG_WORD_SIZE*shamt))&((1<<s.iface.CFG_WORD_SIZE)-1) 
        for shamt in range(nwords) ]
      for v in choices
    ],[])
    return words


  def config_idec(s,*args):
    (choices,sim)=s.idec_compile(*args)
    words=s.idec_words(choices)
    for w in reversed(words):
      s.iface.command(CMD_CFG_WORD,w)


