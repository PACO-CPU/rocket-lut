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


# test i/o
print("\x1b[34;1mRunning\x1b[30;0m: echo test")
iface.test_echo()

# retrieve architecture specifics
print("\x1b[34;1mRunning\x1b[30;0m: load config")
iface.load_config()
print("  word size: .............. %s"%iface.WORD_SIZE)
print("  input words: ............ %s"%iface.INPUT_WORDS)
print("  selector bits: .......... %s"%iface.SELECTOR_BITS)
print("  interpolation bits: ..... %s"%iface.INTERPOLATION_BITS)
print("  segment bits: ........... %s"%iface.SEGMENT_BITS)
print("  pla interconnects: ...... %s"%iface.PLA_INTERCONNECTS)
print("  base bits: .............. %s"%iface.BASE_BITS)
print("  incline bits: ........... %s"%iface.INCLINE_BITS)
print("  address translator delay: %s"%iface.ADDRESS_TRANSLATOR_DELAY)
print("  interpolator delay: ..... %s"%iface.INTERPOLATOR_DELAY)

# test configuration stream
print("\x1b[34;1mRunning\x1b[30;0m: config test")
iface.test_config(iface.CFG_INPUT_DECODER_REGISTER_COUNT)

# automatically generate and test decoder configurations
print(
  "\x1b[34;1mRunning\x1b[30;0m: automatic test (%i configs, %i points)"
  %(randomConfigCount,randomInputCount))
random.seed(time.time())
with htlib.ProgressBar(0,randomConfigCount) as pb_pla:
  for i_cfg in range(randomConfigCount):
    choices=[
      random.randint(0,iface.INPUT_WORDS*iface.WORD_SIZE-1) 
      for i in range(iface.SELECTOR_BITS+iface.INTERPOLATION_BITS)]
    (words,sim)=choices_compile(*choices)
    config_hw(*choices)
    
    with htlib.ProgressBar(0,randomInputCount,parent=pb_pla) as pb_input:
      for i_input in range(randomInputCount):
        x=random.randint(0,(1<<(iface.WORD_SIZE*iface.INPUT_WORDS))-1)
        y_sim=sim(x)
        y_pla=iface.commandi(htlib.CMD_COMPUTE_IDEC,x)
        if y_sim!=y_pla:
          sys.stderr.write(
            "\r\x1b[31;1mERROR\x1b[30;0m: "
            "mismatch (code: <%s>, x: %.8x, y_sim: %.8x, y_pla: %.8x)\n"
            %(" ".join([str(v) for v in choices]),x,y_sim,y_pla))
        pb_input.increment(1)


