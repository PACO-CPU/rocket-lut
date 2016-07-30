#!/usr/bin/env python3
import os,sys
rootpath=os.path.abspath(os.path.dirname(__file__))
sys.path.append(os.path.join(rootpath,"../"))
import htlib
import random

randomInputCount = 50

random.seed(12)

iface=htlib.IFace()
ctrl=htlib.LUTCoreControl(iface)

specification=ctrl.random_core()
intermediate=ctrl.core_compile(specification)
raw_words = ctrl.core_bitstream(specification)

iopairs=[
  (lambda x:(x,intermediate.sim(x)))(ctrl.random_core_input())
  for i in range(randomInputCount)
  ]+[ 
    (0,intermediate.sim(0)) 
  ]

# generate bitstream
with open('test_data.c', 'w') as f:
  f.write(
    "#define BITSTREAM_SIZE %s\n"
    "#define INPUT_SIZE %s\n"
    "uint64_t bitstream[BITSTREAM_SIZE] = {%s};\n"
    "uint64_t input_vec[INPUT_SIZE]  = {%s};\n"
    "uint64_t output_vec[INPUT_SIZE] = {%s};\n"
    %(
      len(raw_words),
      len(iopairs),
      ",".join(["%suL"%v for v in raw_words]),
      ",".join(["%suL"%i for i,o in iopairs]),
      ",".join(["%suL"%o for i,o in iopairs])
      ))

