#!/usr/bin/env python3
import os,sys
rootpath=os.path.abspath(os.path.dirname(__file__))
sys.path.append(os.path.join(rootpath,"../"))
import htlib
import random
import time

randomInputCount = 50
random.seed(time.time())
random.seed(12)

iface=htlib.IFace()
iface.load_config_file("../lut_package.vhd")
ctrl=htlib.LUTCoreControl(iface)

iface.print_config()

specification=ctrl.random_core(singleInput=2)
intermediate=ctrl.core_compile(specification)
raw_words = ctrl.core_bitstream(specification)

specification3=ctrl.random_core(singleInput=False)
intermediate3=ctrl.core_compile(specification3)
raw_words3 = ctrl.core_bitstream(specification3)


iopairs=[
  (lambda x:(x,intermediate.sim(x<<64)))(ctrl.random_core_input()&0xffffffff)
  for i in range(randomInputCount)
  ]+[ 
    (0,intermediate.sim(0)) 
  ]

iopairs3=[
  (lambda x:(x,intermediate3.sim(x)))(ctrl.random_core_input())
  for i in range(randomInputCount)
  ]+[ 
    (0,intermediate3.sim(0)) 
  ]

# generate bitstream
with open('test_data.c', 'w') as f:
  f.write(
    "#define BITSTREAM_SIZE %s\n"
    "#define INPUT_SIZE %s\n"
    "uint64_t bitstream[BITSTREAM_SIZE] = {%s};\n"
    "uint64_t input_vec[INPUT_SIZE]  = {%s};\n"
    "uint64_t output_vec[INPUT_SIZE] = {%s};\n"

    "uint64_t bitstream3[BITSTREAM_SIZE] = {%s};\n"
    "uint64_t input_vec3_1[INPUT_SIZE]  = {%s};\n"
    "uint64_t input_vec3_2[INPUT_SIZE]  = {%s};\n"
    "uint64_t input_vec3_3[INPUT_SIZE]  = {%s};\n"
    "uint64_t output_vec3[INPUT_SIZE] = {%s};\n"

    %(
      len(raw_words),
      len(iopairs),
      ",".join(["%suL"%v for v in raw_words]),
      ",".join(["%suL"%i for i,o in iopairs]),
      ",".join(["%suL"%o for i,o in iopairs]),

      ",".join(["%suL"%v for v in raw_words3]),
      ",".join(["%suL"%((i>>  0)%(1<<64)) for i,o in iopairs3]),
      ",".join(["%suL"%((i>> 64)%(1<<64)) for i,o in iopairs3]),
      ",".join(["%suL"%((i>>128)%(1<<64)) for i,o in iopairs3]),
      ",".join(["%suL"%o for i,o in iopairs3])
      ))

