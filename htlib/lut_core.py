from .iface import *
from .input_decoder import *
from .address_translator import *
from .lut import *
from .interpolator import *
import random
from collections import namedtuple

class LUTCoreControl(IDECControl,PLAControl,LUTControl,InterControl):
  
  specification_t=namedtuple("lut_core_intermediate_t","idec pla lut")
  intermediate_t=namedtuple("lut_core_intermediate_t","idec pla lut inter sim")
  status_t=namedtuple(
    "lut_core_status_t",
    "raw flags e_invalid_cfg e_premature_exe e_instr_code cfg_count")

  def random_core(s):
    idec=s.random_idec()
    pla =s.random_pla()
    lut =s.random_lut()
    
    return LUTCoreControl.specification_t(idec,pla,lut)

  def random_core_input(s):
    return s.random_idec_input()

  def core_compile(s,spec):
    idec=IDECControl.intermediate_t(*s.idec_compile(*spec.idec))
    pla =PLAControl.intermediate_t(*s.pla_compile(*spec.pla))
    lut =LUTControl.intermediate_t(*s.lut_compile(*spec.lut))
    inter=InterControl.intermediate_t(s.inter_compile())

    def sim(x):
      y_idec=idec.sim(x)
      interpolator=(y_idec)&((1<<s.iface.INTERPOLATION_BITS)-1)
      selector=(y_idec>>s.iface.INTERPOLATION_BITS)&((1<<s.iface.SELECTOR_BITS)-1)

      y_pla=pla.sim(selector)
      address=y_pla
      
      y_lut =lut.sim(address)
      incline=(y_lut)&((1<<s.iface.INCLINE_BITS)-1)
      base=(y_lut>>s.iface.INCLINE_BITS)&((1<<s.iface.BASE_BITS)-1)
      
      y_inter=inter.sim(selector,interpolator,base,incline)

      return y_inter

    return LUTCoreControl.intermediate_t(idec,pla,lut,inter,sim)
  
  def config_core(s,spec,prefix=None):
    intermediate=s.core_compile(spec)
    words=(
      # RAM config phase
      s.lut_words(intermediate.lut.cells) +
      # CHAIN config phase
      list(reversed(
        s.idec_words(intermediate.idec.choices) +
        s.pla_words(intermediate.pla.and_plane,intermediate.pla.or_plane)
      )))
    return words  
    for w in words:
      s.iface.command0(CMD_CORE_CFG,w)
    s.core_assert(raw=(s.iface.CFG_REGISTER_COUNT<<8)|0x00)

  def core_reset(s):
    s.iface.command0(CMD_CORE_RST)

  def core_status(s):
    raw=s.iface.command(CMD_CORE_STAT)
    return LUTCoreControl.status_t(
      raw, raw&0xff, (raw)&1, (raw>>1)&1, (raw>>2)&1, (raw>>8)&0xffff)

  def core_exec(s,v,block=True):
    if block:
      return s.iface.commandi(CMD_CORE_EXE,v)
    else:
      s.iface.command0i(CMD_CORE_EXE,v)

  def core_exec_begin(s,v,block=True):
    s.iface.command0i(CMD_CORE_EXE_BEGIN,v)

  def core_assert(s,
    raw=None,
    flags=None,e_invalid_cfg=None,e_premature_exe=None,e_instr_code=None,
    cfg_count=None,msg="assertion failed"):
    
    stat=s.core_status()
    
    if raw!=None and stat.raw!=raw: 
      raise Exception(
        "lut core status error: expected %.8x, got %.8x"%(raw,stat.raw))





 

