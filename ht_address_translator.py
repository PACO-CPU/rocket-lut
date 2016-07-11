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
  
  term=[0]*2*SELECTOR_BITS

  for c in pos:
    if c in list("1234567890"):
      term[int(c)+SELECTOR_BITS]=1
  for c in neg:
    if c in list("1234567890"):
      term[int(c)]=1
  return sum([v*(1<<i) for i,v in enumerate(term)])

## Compiles a list of products (one for each output bit) into a PLA
#
# Returns the and plane rows, or plane columns and a simulation function of
# signature integer -> integer.
def pla_compile(*args):
  if len(args)>SEGMENT_BITS:
    raise htlib.TestFailure("cannot represent PLA: too many output bits")

  arg_products=[
    [parse_product(v) for v in arg.split(",")]
    for arg in args]
  
  products={ p for p in sum(arg_products,[]) }
  
  if len(products)>INTERCONNECTS:
    raise htlib.TestFailure("cannot represent PLA: too many products needd")
  
  product_list=list(sorted(products))
  products_map={ p:i for i,p in enumerate(product_list) }
  
  and_plane=[
    product_list[i] if i<len(product_list) else 0
    for i in range(INTERCONNECTS)]

  sums=[
    sum([1<<products_map[prod] for prod in products])
    for products in arg_products]

  or_plane=sums+[0]*(SEGMENT_BITS-len(sums))
  
  def sim(sel):
    bits=[ 
      0 if (sel&(1<<i)) else 1
      for i in range(SELECTOR_BITS)]
    bits+=[ 
      1 if (sel&(1<<i)) else 0
      for i in range(SELECTOR_BITS)]
    
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
  and_words=math.ceil(SELECTOR_BITS*2/CFG_WORD_SIZE)
  or_words=math.ceil(INTERCONNECTS/CFG_WORD_SIZE)
  and_plane=sum([
    [ (v>>(32*shamt))&((1<<CFG_WORD_SIZE)-1) for shamt in range(and_words) ]
    for v in and_plane
  ],[])
  or_plane=sum([
    [ (v>>(32*shamt))&((1<<CFG_WORD_SIZE)-1) for shamt in range(and_words) ]
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
baudrate=115200

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


CFG_WORD_SIZE=32
SELECTOR_BITS=8
INTERCONNECTS=12
SEGMENT_BITS=4

and_words=math.ceil(SELECTOR_BITS*2/CFG_WORD_SIZE)
or_words=math.ceil(INTERCONNECTS/CFG_WORD_SIZE)

# test i/o
iface.test_echo()

# test configuration stream
iface.test_config(INTERCONNECTS*and_words+SEGMENT_BITS*or_words)

if fTestRandom: # automatically generate and test PLA configurations
  random.seed(time.time())
  with htlib.ProgressBar(0,randomPLACount) as pb_pla:
    for i_pla in range(randomPLACount):
      choices=[random.randint(0,3) for i in range(SELECTOR_BITS)]
      code=[
        (
          "%s!%s"
          %(
            "".join([str(i) if v==0 else "" for i,v in enumerate(choices)]),
            "".join([str(i) if v==1 else "" for i,v in enumerate(choices)])
          ))
        for choices in [
          [random.randint(0,3) for i in range(SELECTOR_BITS)]
          for i_bit in range(SEGMENT_BITS)]]
      (and_plane,or_plane,sim)=pla_compile(*code)
      config_pla(*code)
      
      with htlib.ProgressBar(0,randomInputCount,parent=pb_pla) as pb_input:
        for i_input in range(randomInputCount):
          x=random.randint(0,(1<<SELECTOR_BITS)-1)
          y_sim=sim(x)
          y_pla=iface.command(htlib.CMD_COMPUTE_PLA,x)
          if y_sim!=y_pla:
            sys.stderr.write(
              "\r\x1b[31;1mERROR\x1b[30;0m: "
              "mismatch (code: <%s>, x: %.8x, y_sim: %.8x, y_pla: %.8x)\n"
              %(" ".join(code),x,y_sim,y_pla))
          pb_input.increment(1)


elif fHardware: # compile a PLA, download to hardware and enter shell
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
else: # compile a PLA, simulate it and enter shell
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


