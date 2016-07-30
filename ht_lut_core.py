## @package ht_lut_core
# Hardware test script for the lut core component test
#
# This is a command-line tool used for interfacing with an instantiation of the
# lut core hardware test implemented on an FPGA connected via UART.
# The automatic test assumes the correct implementation of the software 
# simulation of all pipeline stages which were verified manually. This 
# simulation is used to expose the hardware core to random inputs and comparing 
# its output with simulated ones.
#
# For further information on command-line flags look at the command-line
# argument handling state machine.

#!/usr/bin/env python3
import htlib
import sys
import math
import random
import time

def choices_compile(*args):
  
  choices=[
    0 if i>=len(args) else 1<<args[i]
    for i in range(iface.SELECTOR_BITS+iface.INTERPOLATION_BITS)]

  def sim(x):
    bits=[ 
      (x>>i)&1 
      for i in range(iface.INPUT_WORD_SIZE)]
    r=0
    for i,arg in enumerate(args):
      r+=bits[arg]<<i
    return r 
  return choices,sim

def choices_words(choices):
  nwords=iface.CFG_INPUT_DECODER_REGISTERS_PER_BIT
  words=sum([
    [ (v>>(32*shamt))&((1<<iface.CFG_WORD_SIZE)-1) for shamt in range(nwords) ]
    for v in choices
  ],[])
  return words


def config_hw(*args):
  (choices,sim)=choices_compile(*args)
  words=choices_words(choices)
  for w in reversed(words):
    iface.command(htlib.CMD_CFG_WORD,w)

# command-line argument handling
randomConfigCount=1000
randomInputCount=1000
configTestCount=10
port="/dev/ttyUSB0"
baudrate=921600

try:
  s=None
  for arg in sys.argv[1:]:
    if s==None:
      if arg[:1]=="-":
        if False: pass
        elif arg in { "-p", "--port" }: s="--port"
        elif arg in { "-b", "--baud" }: s="--baud"
        else:
          raise Exception("unknown switch: %s"%arg)
      else:
        raise Exception("stray argument: %s"%arg)
    elif s=="--port":
      port=arg
      s=None
    elif s=="--baud":
      baudrate=int(arg)
      s=None

except Exception as e:
  sys.stderr.write("\x1b[31;1mERROR\x1b[30;0m: %s\n"%e)
  sys.exit(1)

# execution
iface=htlib.IFace(port,baudrate)
ctrl=htlib.LUTCoreControl(iface)

# test i/o
print("\x1b[34;1mRunning\x1b[30;0m: echo test")
iface.test_echo()

# retrieve architecture specifics
print("\x1b[34;1mRunning\x1b[30;0m: load config")
iface.load_config()
iface.print_config()

# status test
print("\x1b[34;1mRunning\x1b[30;0m: status test")
ctrl.core_reset()
ctrl.core_assert(raw=0)

for i in range(configTestCount):
  sys.stdout.write("  %i "%i)
  n=random.randint(1,iface.CFG_REGISTER_COUNT);
  for j in range(n):
    iface.command0(htlib.CMD_CORE_CFG,0xaffedead)
    ctrl.core_assert(raw=(j+1)<<8)
    sys.stdout.write("\r  %i/%i: %.2f%%"%(i+1,configTestCount,(j+1/n)*100.0))
  ctrl.core_reset()
  ctrl.core_assert(raw=0)
sys.stdout.write("\r")

for j in range(iface.CFG_REGISTER_COUNT):
  iface.command0(htlib.CMD_CORE_CFG,0xaffedead)

ctrl.core_assert(raw=(iface.CFG_REGISTER_COUNT<<8)|0x00)
ctrl.core_exec(12,True)
ctrl.core_assert(raw=(iface.CFG_REGISTER_COUNT<<8)|0x00)
print("\n  delay: %s"%(iface.command(htlib.CMD_DIAG_CLOCK_COUNTER)))

iface.command0(htlib.CMD_CORE_CFG,0xaffedead)
ctrl.core_assert(raw=(iface.CFG_REGISTER_COUNT<<8)|0x01)
ctrl.core_exec_begin(12)
ctrl.core_assert(raw=(iface.CFG_REGISTER_COUNT<<8)|0x03)

ctrl.core_reset()
ctrl.core_assert(raw=0)


# automatically generate and test decoder configurations
print(
  "\x1b[34;1mRunning\x1b[30;0m: automatic test (%i configs, %i points)"
  %(randomConfigCount,randomInputCount))
random.seed(time.time())
with htlib.ProgressBar(0,randomConfigCount) as pb_cfg:
  for i_cfg in range(randomConfigCount):
    specification=ctrl.random_core()
    intermediate=ctrl.core_compile(specification)
    ctrl.core_reset()
    ctrl.config_core(specification)

    with htlib.ProgressBar(0,randomInputCount,parent=pb_cfg) as pb_input:
      for i_input in range(randomInputCount):
        x=ctrl.random_core_input()
        y_sim=intermediate.sim(x)
        y_phy=ctrl.core_exec(x)
        #y_idec=iface.command
        if y_sim!=y_phy:
          # todo: error output
          sys.stderr.write(
            "\r\x1b[31;1mERROR\x1b[30;0m: "
            "mismatch (x: 0x%x, y_sim=0x%x, y_phy=0x%x)\n"
            %(x,y_sim,y_phy))
        elif False:
          sys.stderr.write(
            "\r\x1b[32;1mSUCCESS\x1b[30;0m: "
            "(x: 0x%x, y_sim=0x%x, y_phy=0x%x)\n"
            %(x,y_sim,y_phy))
        pb_input.increment(1)


