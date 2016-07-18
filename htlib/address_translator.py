from .iface import *
import random

class PLAControl(IFaceRef):
  
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
    return code

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
  def pla_compile(s,*args):
    if len(args)>s.iface.SEGMENT_BITS:
      raise htlib.TestFailure("cannot represent PLA: too many output bits")

    arg_products=[
      [s.parse_product(v) for v in arg.split(",")]
      for arg in args]
    
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


    return and_plane,or_plane,sim

  ## Translates an and and or plane as computed by pla_compile into a stream of
  # registers to be applied to a hardware core
  #
  # Note that in order to apply the configuration correctly, the words must be
  # transmitted in reversed order.
  def pla_words(s,and_plane,or_plane):
    and_words=math.ceil(s.iface.SELECTOR_BITS*2/s.iface.CFG_WORD_SIZE)
    or_words=math.ceil(s.iface.PLA_INTERCONNECTS/s.iface.CFG_WORD_SIZE)
    and_plane=sum([
      [ (v>>(32*shamt))&((1<<s.iface.CFG_WORD_SIZE)-1) for shamt in range(and_words) ]
      for v in and_plane
    ],[])
    or_plane=sum([
      [ (v>>(32*shamt))&((1<<s.iface.CFG_WORD_SIZE)-1) for shamt in range(and_words) ]
      for v in or_plane
    ],[])

    return and_plane+or_plane

  ## Compiles and downloads a PLA onto the connected hardware.
  def config_pla(s,*args):
    (and_plane,or_plane,sim)=s.pla_compile(*args)
    words=s.pla_words(and_plane,or_plane)
    for w in reversed(words):
      s.iface.command(CMD_CFG_WORD,w)


