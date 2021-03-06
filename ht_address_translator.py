## @package ht_address_tranlator
# Hardware test script for the address translator unit (PLA)
#
# This is a command-line tool used for interfacing with an instantiation of the
# PLA hardware test implemented on an FPGA connected via UART.
# Three test commands exist: Software, hardware and automatic.
# Software/Hardware tests accept a number of terms as command-line argument 
# which are translated into PLA configuration. The user is then offered a 
# prompt in which inputs are entered as bit vectors. These inputs are then
# fed into the simulator (Software) or the instantiation (Hardware) and the
# respective result is printed out. These tests are used to manually verify
# the correctness of a PLA implementation.
# The automatic test assumes the correct implementation of the PLA simulation
# (which must be verified using the Software test) and uses it to test random
# PLAs on the hardware by comparing random inputs-output pairs to the simulated
# results.
#
# For further information on command-line flags look at the command-line
# argument handling state machine.
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
      spec=ctrl.random_pla()
      inter=ctrl.pla_compile(spec)
      ctrl.config_pla(spec)
      
      with htlib.ProgressBar(0,randomInputCount,parent=pb_pla) as pb_input:
        for i_input in range(randomInputCount):
          x=ctrl.random_pla_input()
          y_sim=inter.sim(x)
          y_pla=iface.command(htlib.CMD_COMPUTE_PLA,x)
          if y_sim!=y_pla:
            sys.stderr.write(
              "\r\x1b[31;1mERROR\x1b[30;0m: "
              "mismatch (code: <%s>, x: %.8x, y_sim: %.8x, y_pla: %.8x)\n"
              %(" ".join(spec.code),x,y_sim,y_pla))
          pb_input.increment(1)


elif fHardware: # compile a PLA, download to hardware and enter shell
  print("\x1b[34;1mRunning\x1b[30;0m: hardware test (manual)")
  ctrl.config_pla(ctrl.specification_t(pla_terms))
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


