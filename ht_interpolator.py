#!/usr/bin/env python3
import htlib
import sys
import math
import random
import time
# command-line argument handling
randomInputCount=100000
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
ctrl=htlib.InterControl(iface)


# test i/o
print("\x1b[34;1mRunning\x1b[30;0m: echo test")
iface.test_echo()

# retrieve architecture specifics
print("\x1b[34;1mRunning\x1b[30;0m: load config")
iface.load_config()
iface.print_config()

# automatically generate and test decoder configurations
print(
  "\x1b[34;1mRunning\x1b[30;0m: automatic test (%i points)"
  %(randomInputCount))
random.seed(time.time())
sim=ctrl.inter_compile()
with htlib.ProgressBar(0,randomInputCount) as pb_input:
  for i in range(randomInputCount):
    (selector,interpolator,base,incline)=ctrl.random_inter_input()
    y_sim=sim(selector,interpolator,base,incline)
    y_inter=iface.command_inter(
      htlib.CMD_COMPUTE_INTER,selector,interpolator,base,incline)

    if y_sim!=y_inter:
      sys.stderr.write(
        "\r\x1b[31;1mERROR\x1b[30;0m: "
        "mismatch:\n"
        "  selector:     %s (%s)\n"
        "  interpolator: %s (%s)\n"
        "  base:         %s (%s)\n"
        "  incline:      %s (%s)\n"
        "  y_sim:        %s (%s)\n"
        "  y_idec:       %s (%s)\n"
        %(
          ("{0:%ib}"%iface.SELECTOR_BITS).format(selector),selector,
          ("{0:%ib}"%iface.INTERPOLATION_BITS).format(interpolator),interpolator,
          ("{0:%ib}"%iface.BASE_BITS).format(base),base,
          ("{0:%ib}"%iface.INCLINE_BITS).format(incline),incline,
          ("{0:%ib}"%iface.WORD_SIZE).format(y_sim),y_sim,
          ("{0:%ib}"%iface.WORD_SIZE).format(y_inter),y_inter
          ))
    pb_input.increment(1)


