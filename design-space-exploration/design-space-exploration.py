import sys
import os
import threading
import random
import time
import shutil

worker_count=20

worker_files={
  "address_translator.vhd",
  "uart_receiver.vhd",
  "bram_controller.vhd",
  "interpolator.vhd",
  "ht_lut_core.vhd",
  "uart_transmitter.vhd",
  "baud_rate_generator.vhd",
  "test_package.vhd",
  "lut_core.vhd",
  "lut_controller.vhd",
  "single_port_ram.vhd",
  "ht_lut_core.ucf",
  "input_processor.vhd",
}

worker_files_prj={
  "prj/ht_lut_core.prj",
  "prj/ht_lut_core.xst",
  "prj/ht_lut_core.ut",
  "prj/ht_lut_core.cmd_log",
}

report_files={
  "ht_lut_core.bit",
  "ht_lut_core.bld",
  "ht_lut_core.drc",
  "ht_lut_core_map.map",
  "ht_lut_core_map.mrp",
  "ht_lut_core_map.",
  "ht_lut_core.par",
  "ht_lut_core.syr",
  "ht_lut_core.twr",
}

pending_variants=set()
completed_count=0

argument_count=4

variant_groups=[
  [
    ("SELECTOR_BITS",2,32,2),
    ("INTERPOLATION_BITS",2,32,2),
    ("SEGMENT_BITS",2,10,1),
    ("PLA_INTERCONNECTS",4,100,8),
    ("BASE_BITS",8,8,1),
    ("INCLINE_BITS",8,8,1),
    ("INPUT_DECODER_DELAY",0,0,1),
    ("ADDRESS_TRANSLATOR_DELAY",0,0,1),
    ("INTERPOLATOR_DELAY",0,0,1)
  ],
  [
    ("SELECTOR_BITS",8,8,1),
    ("INTERPOLATION_BITS",8,8,1),
    ("SEGMENT_BITS",4,4,1),
    ("PLA_INTERCONNECTS",12,12,1),
    ("BASE_BITS",8,64,4),
    ("INCLINE_BITS",4,64,4),
    ("INPUT_DECODER_DELAY",0,0,1),
    ("ADDRESS_TRANSLATOR_DELAY",0,0,1),
    ("INTERPOLATOR_DELAY",0,0,1)
  ],
]

variant_count=0
for fields in variant_groups:
  count1=1
  for id,first,last,step in fields:
    count1*=(last-first+1)//step
  variant_count+=count1
print("variant count: %i"%variant_count)
print("ETA:           %s h"%(variant_count/20*5/60))


def generate_variants(prefix,fields):
  if len(fields)<1: 
    yield tuple(prefix)
  else:
    prefix1=list(prefix)+[0]
    (id,first,last,step)=fields[0]
    for v in range(first,last+1,step):
      prefix1[-1]=v
      for variant in generate_variants(prefix1,fields[1:]):
        yield variant



with open("lut_package.vhd.dse","r") as f:
  lut_package_template=f.read()

if not os.path.exists("design-space-pending.dat"):
  with open("design-space-pending.dat","w") as f:
    f.write(
      "#%s\n"%("\t".join([v[0] for v in variant_groups[0]])))
    
    for fields in variant_groups:
      for variant in generate_variants([],fields):
        f.write("%s\n"%("\t".join(["%s"%v for v in variant])))

with open("design-space-pending.dat","r") as f:
  for ln in f:
    ln=ln.strip()
    if ln.startswith("#"): continue
    variant=tuple([int(v) for v in ln.split("\t")])
    pending_variants.add(variant)

if os.path.exists("design-space-points.dat"):
  with open("design-space-points.dat","r") as f:
    for ln in f:
      ln=ln.strip()
      if ln.startswith("#"): continue
      variant=tuple([float(v) for v in ln.split("\t")][:argument_count])
      if variant in pending_variants:
        pending_variants.remove(variant)
      completed_count+=1
    pass
mutex=threading.Lock()

def pop_pending():
  global mutex, pending_variants,completed_count
  with mutex:
    if len(pending_variants)<1: return None
    res=pending_variants.pop()
    print(
      "[pending: %s, running: %s, completed: %s] "
      "starting exploration of variant %s"
      %(len(pending_variants),worker_count,completed_count,repr(res)))
    return res

def push_completed(variant,result):
  global mutex,pending_variants,completed_count
  with mutex:
    with open("design-space-points.dat","a") as f:
      f.write("%s\n"%("\t".join(["%s"% v for v in list(variant)+list(result)])))
    completed_count+=1
    print(
      "[pending: %s, running: %s, completed: %s] "
      "completed exploration of variant %s. result: %s"
      %(
        len(pending_variants),worker_count,completed_count,
        repr(variant),repr(result)))


class Worker(threading.Thread):
  def __init__(s,dir):
    s._dir=dir
    threading.Thread.__init__(s)
  
  def cleanup(s):
    if os.path.exists(s._dir):
      shutil.rmtree(s._dir)
    
  def run(s):
    if os.path.exists(s._dir):
      shutil.rmtree(s._dir)

    os.makedirs(s._dir)

    for fn in worker_files:
      trg_file=os.path.join(s._dir,fn)
      shutil.copy(os.path.join("../",fn),os.path.join(s._dir,fn))

    while True:
      variant=pop_pending()
      if variant==None: break
      
      if not os.path.exists(os.path.join(s._dir,"prj/xst/projnav.tmp")):
        os.makedirs(os.path.join(s._dir,"prj/xst/projnav.tmp"));
      
      for fn in worker_files_prj:
        shutil.copy(fn,os.path.join(s._dir,fn))

      with open(os.path.join(s._dir,"lut_package.vhd"),"w") as f:
        args={
          variant_groups[0][i][0] : variant[i] 
          for i in range(len(variant))}
        f.write(lut_package_template.format(**args))
      
      try:
        os.system("cd %s/prj; bash ht_lut_core.cmd_log"%s._dir)
      except Exception as e:
        raise
      
      report_dir="details-%s"%("-".join(["%s"%v for v in variant]))
      if not os.path.exists(report_dir):
        os.makedirs(report_dir)
      for fn in report_files:
        try:
          fnsrc=os.path.join(s._dir,"prj",fn)
          shutil.copy(fnsrc,os.path.join(report_dir,fn))
          os.unlink(fnsrc)
        except Exception as e:
          pass
      
      try:
        shutil.rmtree(os.path.join(s._dir,"prj"))  
      except:
        pass

      push_completed(variant,[])

workers=[Worker("worker-%.3i"%i) for i in range(worker_count)]

try:
  for w in workers:
    w.start()
  for w in workers:
    w.join()

finally:
  for w in workers:
    w.cleanup()
