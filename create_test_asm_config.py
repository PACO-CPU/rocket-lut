#!/usr/bin/env python3
import htlib
import sys
import math
import random
import time
import os

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

randomInputCount = 50

iface=htlib.IFace(port,baudrate)
ctrl=htlib.LUTCoreControl(iface)

specification=ctrl.random_core()
intermediate=ctrl.core_compile(specification)
raw_words = ctrl.config_core(specification)

# generate bitstream
os.system("rm bitstream.h")
f = open('bitstream.h', 'w')

f.write("#define BITSTREAM_SIZE " + str(len(raw_words)) + "\n")
f.write("uint64_t bitstream[BITSTREAM_SIZE] = {\n")

for w in raw_words:

    if int(w) > (1 << 64):
        print("Error")
        exit(0)
    f.write("" + str(w) + ",\n")
    

f.write("};\n")
f.close()

# generate input vectors
os.system("rm output_vec.h")
os.system("rm input_vec.h")
fi = open('input_vec.h', 'w')
fo = open('output_vec.h', 'w')

fi.write("#define INPUT_SIZE " + str(randomInputCount) + "\n")
fi.write("uint64_t input_vec[" + str(randomInputCount) + "] = { \n")
fo.write("uint64_t output_vec[" + str(randomInputCount) + "] = { \n")

for i in range(0, randomInputCount):
    x = ctrl.random_core_input()
    y = intermediate.sim(x)
    fi.write(str(x) + ",\n")
    fo.write(str(y) + ",\n")

fi.write("};")
fo.write("};")

fi.close()
fo.close()

