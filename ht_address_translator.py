#!/usr/bin/env python3
import htlib
import sys
import math
import random
import time


## Parses a product of the form [0-9]*(![0-9]*) into an integer used for
# and-plane rows
def parse_product(raw):
  if raw.find("!")>-1:
    (pos,neg)=raw.split("!",1)
  else:
    pos=raw
    neg=""
  
  term=[0]*2*iface.SELECTOR_BITS

  for c in pos:
    if c in list("1234567890"):
      term[int(c)+iface.SELECTOR_BITS]=1
  for c in neg:
    if c in list("1234567890"):
      term[int(c)]=1
  return sum([v*(1<<i) for i,v in enumerate(term)])

## Compiles a list of products (one for each output bit) into a PLA
#
# Returns the and plane rows, or plane columns and a simulation function of
# signature integer -> integer.
def pla_compile(*args):
  if len(args)>iface.SEGMENT_BITS:
    raise htlib.TestFailure("cannot represent PLA: too many output bits")

  arg_products=[
    [parse_product(v) for v in arg.split(",")]
    for arg in args]
  
  products={ p for p in sum(arg_products,[]) }
  
  if len(products)>iface.PLA_INTERCONNECTS:
    raise htlib.TestFailure("cannot represent PLA: too many products needd")
  
  product_list=list(sorted(products))
  products_map={ p:i for i,p in enumerate(product_list) }
  
  and_plane=[
    product_list[i] if i<len(product_list) else 0
    for i in range(iface.PLA_INTERCONNECTS)]

  sums=[
    sum([1<<products_map[prod] for prod in products])
    for products in arg_products]

  or_plane=sums+[0]*(iface.SEGMENT_BITS-len(sums))
  
  def sim(sel):
    bits=[ 
      0 if (sel&(1<<i)) else 1
      for i in range(iface.SELECTOR_BITS)]
    bits+=[ 
      1 if (sel&(1<<i)) else 0
      for i in range(iface.SELECTOR_BITS)]
    
    sel_ex=sum([ bit<<i for i,bit in enumerate(bits) ])
    and_eval=sum([1<<i if (sel_ex&v)==v else 0 for i,v in enumerate(and_plane)])
    or_eval=sum([1<<i if (and_eval&v)!=0 else 0 for i,v in enumerate(or_plane)])

    return or_eval


  return and_plane,or_plane,sim

## Translates an and and or plane as computed by pla_compile into a stream of
# registers to be applied to a hardware core
#
# Note that in order to apply the configuration correctly, the words must be
# transmitted in reversed order.
def pla_words(and_plane,or_plane):
  and_words=math.ceil(iface.SELECTOR_BITS*2/iface.CFG_WORD_SIZE)
  or_words=math.ceil(iface.PLA_INTERCONNECTS/iface.CFG_WORD_SIZE)
  and_plane=sum([
    [ (v>>(32*shamt))&((1<<iface.CFG_WORD_SIZE)-1) for shamt in range(and_words) ]
    for v in and_plane
  ],[])
  or_plane=sum([
    [ (v>>(32*shamt))&((1<<iface.CFG_WORD_SIZE)-1) for shamt in range(and_words) ]
    for v in or_plane
  ],[])

  return and_plane+or_plane

## Compiles and downloads a PLA onto the connected hardware.
def config_pla(*args):
  (and_plane,or_plane,sim)=pla_compile(*args)
  words=pla_words(and_plane,or_plane)
  for w in reversed(words):
    iface.command(htlib.CMD_CFG_WORD,w)

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
      choices=[random.randint(0,3) for i in range(iface.SELECTOR_BITS)]
      code=[
        (
          "%s!%s"
          %(
            "".join([str(i) if v==0 else "" for i,v in enumerate(choices)]),
            "".join([str(i) if v==1 else "" for i,v in enumerate(choices)])
          ))
        for choices in [
          [random.randint(0,3) for i in range(iface.SELECTOR_BITS)]
          for i_bit in range(iface.SEGMENT_BITS)]]
      (and_plane,or_plane,sim)=pla_compile(*code)
      config_pla(*code)
      
      with htlib.ProgressBar(0,randomInputCount,parent=pb_pla) as pb_input:
        for i_input in range(randomInputCount):
          x=random.randint(0,(1<<iface.SELECTOR_BITS)-1)
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
  config_pla(*pla_terms)
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
  (and_plane,or_plane,sim)=pla_compile(*pla_terms)
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


