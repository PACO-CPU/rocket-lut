#!/usr/bin/env python3
import htlib
import sys
import math
import random
import time

def incline_sex(incline):
  if incline&(1<<(iface.INCLINE_BITS-1)):
    incline=incline-(1<<iface.INCLINE_BITS)
  return incline

def sim(selector,interpolator,base,incline):
  incline=incline_sex(incline)
  mult=(selector<<iface.INTERPOLATION_BITS) | interpolator

  return (base+mult*incline)&0xffffffff

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


# test i/o
print("\x1b[34;1mRunning\x1b[30;0m: echo test")
iface.test_echo()

# retrieve architecture specifics
print("\x1b[34;1mRunning\x1b[30;0m: load config")
iface.load_config()
print("  word size: .............. %s"%iface.WORD_SIZE)
print("  selector bits: .......... %s"%iface.SELECTOR_BITS)
print("  interpolation bits: ..... %s"%iface.INTERPOLATION_BITS)
print("  segment bits: ........... %s"%iface.SEGMENT_BITS)
print("  pla interconnects: ...... %s"%iface.PLA_INTERCONNECTS)
print("  base bits: .............. %s"%iface.BASE_BITS)
print("  incline bits: ........... %s"%iface.INCLINE_BITS)
print("  address translator delay: %s"%iface.ADDRESS_TRANSLATOR_DELAY)
print("  interpolator delay: ..... %s"%iface.INTERPOLATOR_DELAY)

# automatically generate and test decoder configurations
print(
  "\x1b[34;1mRunning\x1b[30;0m: automatic test (%i points)"
  %(randomInputCount))
random.seed(time.time())
with htlib.ProgressBar(0,randomInputCount) as pb_input:
  for i in range(randomInputCount):
    selector=random.randint(0,(1<<(iface.SELECTOR_BITS))-1)
    interpolator=random.randint(0,(1<<(iface.INTERPOLATION_BITS))-1)
    base=random.randint(0,(1<<(iface.BASE_BITS))-1)
    incline=random.randint(0,(1<<(iface.INCLINE_BITS))-1)
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


