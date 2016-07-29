#!/usr/bin/env python3
import os,sys
rootpath=os.path.abspath(os.path.dirname(__file__))
sys.path.append(os.path.join(rootpath,"../"))
import htlib
import math
import random
import time

randomInputCount = 50

iface=htlib.IFace()
ctrl=htlib.LUTCoreControl(iface)

specification=ctrl.random_core()
intermediate=ctrl.core_compile(specification)
raw_words = ctrl.core_bitstream(specification)

# generate bitstream
os.system("rm bitstream.h")
f = open('bitstream.h', 'w')

f.write("#define BITSTREAM_SIZE " + str(len(raw_words)) + "\n")
f.write("uint64_t bitstream[BITSTREAM_SIZE] = {\n")

for w in raw_words:

    if int(w) >= (1 << 64):
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

for i in range(randomInputCount):
    x = ctrl.random_core_input()
    y = intermediate.sim(x)
    fi.write(str(x) + ",\n")
    fo.write(str(y) + ",\n")

fi.write("};")
fo.write("};")

fi.close()
fo.close()

