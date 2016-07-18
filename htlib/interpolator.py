from .iface import *
import random
from collections import namedtuple

class InterControl(IFaceRef):
  intermediate_t=namedtuple("inter_intermediate_t","sim")

  def random_inter_input(s):
    
    selector=random.randint(0,(1<<(s.iface.SELECTOR_BITS))-1)
    interpolator=random.randint(0,(1<<(s.iface.INTERPOLATION_BITS))-1)
    base=random.randint(0,(1<<(s.iface.BASE_BITS))-1)
    incline=random.randint(0,(1<<(s.iface.INCLINE_BITS))-1)

    return selector,interpolator,base,incline


  def incline_sex(s,incline):
    if incline&(1<<(s.iface.INCLINE_BITS-1)):
      incline=incline-(1<<s.iface.INCLINE_BITS)
    return incline

  def inter_compile(s):
    def sim(selector,interpolator,base,incline):
      incline=s.incline_sex(incline)
      mult=(selector<<s.iface.INTERPOLATION_BITS) | interpolator
      return (base+mult*incline)&0xffffffff
    
    return sim

