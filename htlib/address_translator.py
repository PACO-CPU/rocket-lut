from .iface import *
import random
from collections import namedtuple


## Control class corresponding to ht_address_translator.
#
# Offers facilities to generate random PLA configurations and inputs as well as
# a simulation method and configuration of hardware instantiation.
class PLAControl(IFaceRef):
  
  ## Type encapsulating a raw address translator (PLA) specification
  specification_t=namedtuple("pla_specification_t","code")
  
  ## Encapsulates an intermediate representation of a PLA.
  #
  # Contains information required to configure a hardware instantiation as
  # well as a method for simulating that PLA.
  intermediate_t=namedtuple("pla_intermediate_t","and_plane or_plane sim")
  
  ## generates a random PLA specification.
  #
  # The result is a specificiation accepted by pla_compile, pla_words and 
  # config_pla.
  def random_pla(s):
    code=[
      (
        "%s!%s"
        %(
          "".join([str(i) if v==0 else "" for i,v in enumerate(choices)]),
          "".join([str(i) if v==1 else "" for i,v in enumerate(choices)])
        ))
      for choices in [
        [random.randint(0,3) for i in range(s.iface.SELECTOR_BITS)]
        for i_bit in range(s.iface.SEGMENT_BITS)]]
    return PLAControl.specification_t(code)
  
  # Generates a random input for a PLA.
  #
  # This can be used as input to a hardware instantiation or a simulation
  # method as returned by pla_compile.
  def random_pla_input(s):
    return random.randint(0,(1<<s.iface.SELECTOR_BITS)-1)

  ## Parses a product of the form [0-9]*(![0-9]*) into an integer used for
  # and-plane rows
  def parse_product(s,raw):
    if raw.find("!")>-1:
      (pos,neg)=raw.split("!",1)
    else:
      pos=raw
      neg=""
    
    term=[0]*2*s.iface.SELECTOR_BITS

    for c in pos:
      if c in list("1234567890"):
        term[int(c)+s.iface.SELECTOR_BITS]=1
    for c in neg:
      if c in list("1234567890"):
        term[int(c)]=1
    return sum([v*(1<<i) for i,v in enumerate(term)])

  ## Compiles a list of products (one for each output bit) into a PLA
  #
  # Returns the and plane rows, or plane columns and a simulation function of
  # signature integer -> integer.
  def pla_compile(s,spec):
    if len(spec.code)>s.iface.SEGMENT_BITS:
      raise htlib.TestFailure("cannot represent PLA: too many output bits")

    arg_products=[
      [s.parse_product(v) for v in arg.split(",")]
      for arg in spec.code]
    
    products={ p for p in sum(arg_products,[]) }
    
    if len(products)>s.iface.PLA_INTERCONNECTS:
      raise htlib.TestFailure("cannot represent PLA: too many products needd")
    
    product_list=list(sorted(products))
    products_map={ p:i for i,p in enumerate(product_list) }
    
    and_plane=[
      product_list[i] if i<len(product_list) else 0
      for i in range(s.iface.PLA_INTERCONNECTS)]

    sums=[
      sum([1<<products_map[prod] for prod in products])
      for products in arg_products]

    or_plane=sums+[0]*(s.iface.SEGMENT_BITS-len(sums))

    return s.pla_compile_raw(and_plane,or_plane)
    
  ## Final PLA compilation step operating on and and or planes instead of 
  # string-based specifications.
  def pla_compile_raw(s,and_plane,or_plane):
    def sim(sel):
      bits=[ 
        0 if (sel&(1<<i)) else 1
        for i in range(s.iface.SELECTOR_BITS)]
      bits+=[ 
        1 if (sel&(1<<i)) else 0
        for i in range(s.iface.SELECTOR_BITS)]
      
      sel_ex=sum([ bit<<i for i,bit in enumerate(bits) ])
      and_eval=sum([1<<i if (sel_ex&v)==v else 0 for i,v in enumerate(and_plane)])
      or_eval=sum([1<<i if (and_eval&v)!=0 else 0 for i,v in enumerate(or_plane)])

      return or_eval


    return PLAControl.intermediate_t(and_plane,or_plane,sim)


  ## Translates an and and or plane as computed by pla_compile into a stream of
  # registers to be applied to a hardware core
  #
  # Note that in order to apply the configuration correctly, the words must be
  # transmitted in reversed order.
  # @input inter intermediate representation of type intermediate_t.
  def pla_words(s,inter):
    and_words=math.ceil(s.iface.SELECTOR_BITS*2/s.iface.CFG_WORD_SIZE)
    or_words=math.ceil(s.iface.PLA_INTERCONNECTS/s.iface.CFG_WORD_SIZE)
    and_plane=sum([
      [ 
        (v>>(s.iface.CFG_WORD_SIZE*shamt))&((1<<s.iface.CFG_WORD_SIZE)-1) 
        for shamt in reversed(range(and_words)) ]
      for v in inter.and_plane
    ],[])
    or_plane=sum([
      [ 
        (v>>(s.iface.CFG_WORD_SIZE*shamt))&((1<<s.iface.CFG_WORD_SIZE)-1) 
        for shamt in reversed(range(and_words)) ]
      for v in inter.or_plane
    ],[])

    # This fills up the or_plane with zeros , if one column consits of more than
    # WORD_LEN configuration words. Otherwise the hardware would expect more
    # words for the or plane than we generate here.
    or_plane2=[]
    used_or_regs = math.ceil(len(or_plane)/s.iface.SEGMENT_BITS)

    for seg_line in or_plane:
        or_plane2 = or_plane2 + [0] * (or_words-used_or_regs) + [seg_line]
    return and_plane+or_plane2

  ## Compiles and downloads a PLA onto the connected hardware.
  def config_pla(s,spec):
    inter=s.pla_compile(spec)
    words=s.pla_words(inter)
    for w in reversed(words):
      s.iface.command(CMD_CFG_WORD,w)


