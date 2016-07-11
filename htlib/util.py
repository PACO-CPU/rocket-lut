import sys

class ProgressBar:
  Image10=["0",".",".",".","1",".",".",".","2",".",".",".","3",".",".",".","4",".",".",".","5",".",".",".","6",".",".",".","7",".",".",".","8",".",".",".","9",".",".",".","10"]
  
  Image100=["00",".",".",".","01",".",".",".","02",".",".",".","03",".",".",".","04",".",".",".","05",".",".",".","06",".",".",".","07",".",".",".","08",".",".",".","09",".",".",".","10\n10",".",".",".","11",".",".",".","12",".",".",".","13",".",".",".","14",".",".",".","15",".",".",".","16",".",".",".","17",".",".",".","18",".",".",".","19",".",".",".","20\n20",".",".",".","21",".",".",".","22",".",".",".","23",".",".",".","24",".",".",".","25",".",".",".","26",".",".",".","27",".",".",".","28",".",".",".","29",".",".",".","30\n30",".",".",".","31",".",".",".","32",".",".",".","33",".",".",".","34",".",".",".","35",".",".",".","36",".",".",".","37",".",".",".","38",".",".",".","39",".",".",".","40\n40",".",".",".","41",".",".",".","42",".",".",".","43",".",".",".","44",".",".",".","45",".",".",".","46",".",".",".","47",".",".",".","48",".",".",".","49",".",".",".","50\n50",".",".",".","51",".",".",".","52",".",".",".","53",".",".",".","54",".",".",".","55",".",".",".","56",".",".",".","57",".",".",".","58",".",".",".","59",".",".",".","60\n60",".",".",".","61",".",".",".","62",".",".",".","63",".",".",".","64",".",".",".","65",".",".",".","66",".",".",".","67",".",".",".","68",".",".",".","69",".",".",".","70\n70",".",".",".","71",".",".",".","72",".",".",".","73",".",".",".","74",".",".",".","75",".",".",".","76",".",".",".","77",".",".",".","78",".",".",".","79",".",".",".","80\n80",".",".",".","81",".",".",".","82",".",".",".","83",".",".",".","84",".",".",".","85",".",".",".","86",".",".",".","87",".",".",".","88",".",".",".","89",".",".",".","90\n90",".",".",".","91",".",".",".","92",".",".",".","93",".",".",".","94",".",".",".","95",".",".",".","96",".",".",".","97",".",".",".","98",".",".",".","99",".",".",".","100"]
  def __init__(self,min,max, parent=None, image=None, fout=sys.stdout, reprint=False):
    self.image=image if image!=None else ProgressBar.Image10
    self.parent=parent
    self.min=min
    self.max=max
    self.next=self.min
    self.idx=0
    self.cur=self.min
    self.fout=fout
    self.reprint=reprint
  
  def __enter__(self):
    self.reset()
    return self
  
  def __exit__(self,a,b,c):
    self.finish()
  
  def reset(self,min=None,max=None):
    if min!=None: self.min=min
    if max!=None: self.max=max
    self.next=self.min
    self.idx=0
    self.cur=self.min
  
  def iterate(self,v):
    while self.next!=None and v>=self.next:
      if self.reprint:
        self.fout.write("\r%s"%"".join(self.image[:self.idx+1]))
      else:
        self.fout.write(self.image[self.idx])
      self.idx=self.idx+1
      if self.idx>=len(self.image):
        self.next=None
        self.fout.write("\n")
      else:
        self.next=self.next+(self.max-self.min)/(len(self.image)-1)
      self.fout.flush()
    self.cur=v
  
  def increment(self,v=1):
    if self.parent!=None:
      self.parent.increment(v/(self.max-self.min))
      self.cur+=v
      return
    self.iterate(self.cur+v)
  
  def finish(self):
    if self.parent!=None:
      self.parent.increment((self.max-self.cur)/(self.max-self.min))
      self.cur=self.max
      self.next=None
      return
    
    if self.next!=None:
      if self.reprint:
        self.fout.write("\r%s"%"".join(self.image))
        self.idx=len(self.image)
      else:
        while self.idx<len(self.image):
          self.fout.write(self.image[self.idx])
          self.idx=self.idx+1
      self.fout.write("\n")
      self.fout.flush()
      self.next=None
      self.cur=self.max


