#!/usr/bin/env python3
import htlib
import sys
import math
import random
import time

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
ctrl=htlib.IDECControl(iface)

# test i/o
print("\x1b[34;1mRunning\x1b[30;0m: echo test")
iface.test_echo()

# retrieve architecture specifics
print("\x1b[34;1mRunning\x1b[30;0m: load config")
iface.load_config()
iface.print_config()

# test configuration stream
print("\x1b[34;1mRunning\x1b[30;0m: config test")
iface.test_config(iface.CFG_INPUT_DECODER_REGISTER_COUNT)

def fmt_bv(x,cb):
  bv=("{0:%ib}"%cb).format(x)
  bv=" ".join([bv[i:i+8] for i in range(0,len(bv),8)])
  return bv

# automatically generate and test decoder configurations
print(
  "\x1b[34;1mRunning\x1b[30;0m: automatic test (%i configs, %i points)"
  %(randomConfigCount,randomInputCount))
random.seed(time.time())
with htlib.ProgressBar(0,randomConfigCount) as pb_idec:
  for i_cfg in range(randomConfigCount):
    choices=ctrl.random_idec()
    (words,sim)=ctrl.idec_compile(*choices)
    ctrl.config_idec(*choices)
    
    with htlib.ProgressBar(0,randomInputCount,parent=pb_idec) as pb_input:
      for i_input in range(randomInputCount):
        x=ctrl.random_idec_input()
        y_sim=sim(x)
        y_idec=iface.commandi(htlib.CMD_COMPUTE_IDEC,x)
        if y_sim!=y_idec:
          sys.stderr.write(
            "\r\x1b[31;1mERROR\x1b[30;0m: "
            "mismatch (code: <%s>)\n  x:      %s\n  y_sim:  %s\n  y_idec: %s\n"
            %(" ".join([str(v) for v in choices]),
            fmt_bv(x,iface.INPUT_WORDS*iface.WORD_SIZE),
            fmt_bv(y_sim,iface.SELECTOR_BITS+iface.INTERPOLATION_BITS),
            fmt_bv(y_idec,iface.SELECTOR_BITS+iface.INTERPOLATION_BITS)))
        pb_input.increment(1)


