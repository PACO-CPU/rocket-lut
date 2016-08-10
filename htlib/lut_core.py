from .iface import *
from .input_decoder import *
from .address_translator import *
from .lut import *
from .interpolator import *
import random
from collections import namedtuple

## Control class corresponding to ht_lut_core.
#
# Offers facilities for generating random lut core configurations within the
# realm defined by the target hardware's architecture, simulating it and
# generating configuration bitstreams.
class LUTCoreControl(IDECControl,PLAControl,LUTControl,InterControl):
  
  ## type encapsulating a lut core configuration
  #
  # Encapsulates the specification data for the input decoder (idec),
  # address translator (pla) and lookup (lut) as defined by the IDECControl, 
  # PLAControl and LUTControl classes, respectively.
  specification_t=namedtuple("lut_core_intermediate_t","idec pla lut")

  ## type encapsulating a compiled lut core with simulation and configuration
  # data
  #
  # This combines the intermediate representation of the input decoder (idec)
  # class, the address translator (pla) class, the lookup class (lut) and the
  # interpolator class (inter). These types are defined by the
  # IDECControl, PLAControl, LUTControl and InterControl classes, respectively.
  # Additionally, sim is a wrapper function executing all the pipeline stages
  # at once using just an input word and outputting the final result.
  intermediate_t=namedtuple("lut_core_intermediate_t","idec pla lut inter sim")

  ## Structure holding information on the current status of an instantiated
  # lut hardware core.
  #
  # Information is presented as the raw word in the `raw` field as well as
  # split into meaningful blocks: Boolean status parts `flags` and the 
  # number of applied configuration flags `cfg_count`. `flags` is further split
  # into `e_invalid_cfg`, `e_premature_exe` and `e_instr_code`, representing
  # the error flags for an invalidly executed configuration instruction, a
  # prematurely (before configuration finished) executed compute instruction and
  # an invalid instruction encoding.
  status_t=namedtuple(
    "lut_core_status_t",
    "raw flags e_invalid_cfg e_premature_exe e_instr_code cfg_count")

  ## Generates a random LUT hardware core
  def random_core(s,singleInput=False):
    idec=s.random_idec(singleInput=singleInput)
    pla =s.random_pla()
    lut =s.random_lut()
    
    return LUTCoreControl.specification_t(idec,pla,lut)
  
  ## Generates a random input to a hardware core for use in simulation or
  # hardware testing
  def random_core_input(s):
    return s.random_idec_input()
  

  ## Reads a bitstream encoded as a list of configuration words and compiles it
  # into an intermediate lut core representation
  def decompile_bitstream(s,words):
    ram=words[:s.iface.CFG_LUT_REGISTER_COUNT]
    chain=list(reversed(words[s.iface.CFG_LUT_REGISTER_COUNT:]))
    idec=chain[:s.iface.CFG_INPUT_DECODER_REGISTER_COUNT]
    chain=chain[s.iface.CFG_INPUT_DECODER_REGISTER_COUNT:]
    pla_and=chain[:s.iface.CFG_PLA_AND_REGISTER_COUNT]
    chain=chain[s.iface.CFG_PLA_AND_REGISTER_COUNT:]
    pla_or=chain
    chain=[]

    def decode_words(words,n,m,ws):
      return [
        sum([v<<(ws*(m-j-1)) for j,v in enumerate(words[i:i+m])])
        for i in range(0,n*m,m)]
    def decode_words_rev(words,n,m,ws):
      return [
        sum([v<<(ws*(j)) for j,v in enumerate(words[i:i+m])])
        for i in range(0,n*m,m)]

    
    ram=decode_words_rev(ram,
      2**s.iface.SEGMENT_BITS,
      s.iface.RAM_CONFIG_BUFFER_SIZE,
      s.iface.WORD_SIZE)
    idec=decode_words(idec,
      s.iface.SELECTOR_BITS+s.iface.INTERPOLATION_BITS,
      s.iface.CFG_INPUT_DECODER_REGISTERS_PER_BIT,
      s.iface.WORD_SIZE)
    pla_and=decode_words(pla_and,
      s.iface.PLA_INTERCONNECTS,
      s.iface.CFG_PLA_AND_REGISTERS_PER_ROW,
      s.iface.WORD_SIZE)
    pla_or=decode_words(pla_or,
      s.iface.SEGMENT_BITS,
      s.iface.CFG_PLA_OR_REGISTERS_PER_COLUMN,
      s.iface.WORD_SIZE)

    idec =s.idec_compile_raw(idec)
    pla  =s.pla_compile_raw(pla_and,pla_or)
    lut  =s.lut_compile(LUTControl.specification_t(ram))
    inter=s.inter_compile()
    
    return s.core_compile_raw(idec,pla,lut,inter)

  ## translates a lut core specification into its intermediate form
  #
  # @param spec An instance of specification_t e.g. generated by random_core.
  # @return an instance of intermediate_t.
  def core_compile(s,spec):
    idec =s.idec_compile(spec.idec)
    pla  =s.pla_compile(spec.pla)
    lut  =s.lut_compile(spec.lut)
    inter=s.inter_compile()
    return s.core_compile_raw(idec,pla,lut,inter)

  ## Assembles compiled input decoder PLA, LUT and interpolator intermediates
  # into a lut core intermediate
  def core_compile_raw(s,idec,pla,lut,inter):
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
  
  ## Translates a lut core specification into a list of configuration words
  # ready to be sent as configuration data to a lut core instantiation.
  def core_bitstream(s,spec):
    intermediate=s.core_compile(spec)
    words=(
      # RAM config phase
      s.lut_words(intermediate.lut) +
      # CHAIN config phase
      list(reversed(
        s.idec_words(intermediate.idec) +
        s.pla_words(intermediate.pla)
      )))
    return words
    
  ## Translates a lut core specification into configuration words and utilizes 
  # the configuration facilities of ht_lut_core to apply this bitstream to
  # an instantiation.
  def config_core(s,spec):
    words=s.core_bitstream(spec)

    for w in words:
      s.iface.command0(CMD_CORE_CFG,w)
    s.core_assert(raw=(s.iface.CFG_REGISTER_COUNT<<8)|0x00)
  
  ## Resets a lut hardware core
  #
  # A reset invalidates any configuration data and clears error flags, thus
  # all configuration must be done again before execution can be requested.
  def core_reset(s):
    s.iface.command0(CMD_CORE_RST)
  
  ## Retrieves a status output from a lut hardware core.
  #
  # @return An instance of status_t.
  def core_status(s):
    raw=s.iface.command(CMD_CORE_STAT)
    return LUTCoreControl.status_t(
      raw, raw&0xff, (raw)&1, (raw>>1)&1, (raw>>2)&1, (raw>>8)&0xffff)
  
  ## Executes the computation of a single input on a lut hardware core
  # instantiation.
  #
  # @param v Input to compute, this must be an integer representable as
  # input (WORD_SIZE * INPUT_WORDS bits). Accepts inputs generated by
  # random_core_input.
  # @param block Set to true to wait for the result word (default). Otherwise
  # the execution is requested but no result is returned. Note that the 
  # hardware test state machine will still try to transmit the results after
  # computation has finished. If this is not desired, core_exec_begin should be
  # used instead.
  def core_exec(s,v,block=True):
    if block:
      return s.iface.commandi(CMD_CORE_EXE,v)
    else:
      s.iface.command0i(CMD_CORE_EXE,v)
  
  # Requests a single execution of a lut hardware core, disregarding any
  # result.
  #
  # This will cause the hardware test state machine to only insert a word into
  # the pipeline and return to the idle state immediately, not waiting for 
  # computation to complete.
  def core_exec_begin(s,v,block=True):
    s.iface.command0i(CMD_CORE_EXE_BEGIN,v)
  
  # Retrieves a status output from the lut hardware core and compares it with
  # an expected value.
  #
  # @throws Exception The received status does not match the expected one.
  def core_assert(s,
    raw=None,
    flags=None,e_invalid_cfg=None,e_premature_exe=None,e_instr_code=None,
    cfg_count=None,msg="assertion failed"):
    
    stat=s.core_status()
    
    if raw!=None and stat.raw!=raw: 
      raise Exception(
        "lut core status error: expected %.8x, got %.8x"%(raw,stat.raw))





 

