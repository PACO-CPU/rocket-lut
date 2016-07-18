#!/usr/bin/env python3
import htlib
import sys
import math
import random
import time

# command-line argument handling
fHardware=False
fTestRandom=False
randomPLACount=1000
randomInputCount=1000
pla_terms=[]
port="/dev/ttyUSB0"
baudrate=921600

try:
  s=None
  for arg in sys.argv[1:]:
    if s==None:
      if arg[:1]=="-":
        if arg in { "-h", "--hardware" }: fHardware=True
        elif arg in { "-r", "--test-random" }: fTestRandom=True
        elif arg in { "-p", "--port" }: s="--port"
        elif arg in { "-b", "--baud" }: s="--baud"
        else:
          raise Exception("unknown switch: %s"%arg)
      else:
        pla_terms.append(arg)
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
ctrl=htlib.PLAControl(iface)

# test i/o
print("\x1b[34;1mRunning\x1b[30;0m: echo test")
iface.test_echo()

# retrieve architecture specifics
print("\x1b[34;1mRunning\x1b[30;0m: load config")
iface.load_config()
iface.print_config()

# test configuration stream
print("\x1b[34;1mRunning\x1b[30;0m: config test")
iface.test_config(iface.CFG_PLA_REGISTER_COUNT)

if fTestRandom: # automatically generate and test PLA configurations
  print(
    "\x1b[34;1mRunning\x1b[30;0m: automatic test (%i PLAs, %i points)"
    %(randomPLACount,randomInputCount))
  random.seed(time.time())
  with htlib.ProgressBar(0,randomPLACount) as pb_pla:
    for i_pla in range(randomPLACount):
      code=ctrl.random_pla()
      (and_plane,or_plane,sim)=ctrl.pla_compile(*code)
      ctrl.config_pla(*code)
      
      with htlib.ProgressBar(0,randomInputCount,parent=pb_pla) as pb_input:
        for i_input in range(randomInputCount):
          x=ctrl.random_pla_input()
          y_sim=sim(x)
          y_pla=iface.command(htlib.CMD_COMPUTE_PLA,x)
          if y_sim!=y_pla:
            sys.stderr.write(
              "\r\x1b[31;1mERROR\x1b[30;0m: "
              "mismatch (code: <%s>, x: %.8x, y_sim: %.8x, y_pla: %.8x)\n"
              %(" ".join(code),x,y_sim,y_pla))
          pb_input.increment(1)


elif fHardware: # compile a PLA, download to hardware and enter shell
  print("\x1b[34;1mRunning\x1b[30;0m: hardware test (manual)")
  ctrl.config_pla(*pla_terms)
  try:
    while True:
      sys.stdout.write("> ")
      sys.stdout.flush()
      ln=sys.stdin.readline()
      if len(ln)<1: break
      s=int(ln.strip(),2)
      a=iface.command(htlib.CMD_COMPUTE_PLA,s)
      print("res: {0:8b}".format(a))
  except KeyboardInterrupt:
    pass
else: # compile a PLA, simulate it and enter sheller shell
  print("\x1b[34;1mRunning\x1b[30;0m: simulation test (manual)")
  (and_plane,or_plane,sim)=ctrl.pla_compile(*pla_terms)
  try:
    while True:
      sys.stdout.write("> ")
      sys.stdout.flush()
      ln=sys.stdin.readline()
      if len(ln)<1: break
      s=int(ln.strip(),2)
      a=sim(s)
      print("res: {0:8b}".format(a))
  except KeyboardInterrupt:
    pass


