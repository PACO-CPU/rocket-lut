from .iface import *
import random
from collections import namedtuple
import sys

## Control class corresponding to ht_interpolator.
#
# As the interpolator is stateles, no random specification is generated.
# To stay consistent with other control classes a compilation method still
# exists that will only return a simulation method.

class InterControl(IFaceRef):
  intermediate_t=namedtuple("inter_intermediate_t","sim")
  
  ## Generates a random input for the interpolator.
  # 
  # @return 4-tuple selector, interpolator, base, incline
  def random_inter_input(s):
    
    selector=random.randint(0,(1<<(s.iface.SELECTOR_BITS))-1)
    interpolator=random.randint(0,(1<<(s.iface.INTERPOLATION_BITS))-1)
    base=random.randint(0,(1<<(s.iface.BASE_BITS))-1)
    incline=random.randint(0,(1<<(s.iface.INCLINE_BITS))-1)

    return selector,interpolator,base,incline

  ## Perfoms a conversion from two's complement value represented as unsigned
  # integer into a signed integer for incline values.
  def incline_sex(s,incline):
    if incline&(1<<(s.iface.INCLINE_BITS-1)):
      incline=incline-(1<<s.iface.INCLINE_BITS)
    return incline
  ## Perfoms a conversion from two's complement value represented as unsigned
  # integer into a signed integer for base values.
  def base_sex(s,base):
    if base&(1<<(s.iface.BASE_BITS-1)):
      base=base-(1<<s.iface.BASE_BITS)
    return base
  
  ## Generates a simulation method for the interpolator.
  def inter_compile(s):
    def sim(selector,interpolator,base,incline):
      incline=s.incline_sex(incline)
      base=s.base_sex(base)
      mult=(selector<<s.iface.INTERPOLATION_BITS) | interpolator
      return (base+mult*incline)&((1<<s.iface.WORD_SIZE)-1)
    
    return InterControl.intermediate_t(sim)

