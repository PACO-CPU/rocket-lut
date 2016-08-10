from .iface import *
from collections import namedtuple

class ASCIIRenderer:
  
  def __init__(s):
    s._lines=[]
    s._lidx0=None
    s._cidx0=None
    s._cidx1=None

  def alloc(s,lidx0,cidx0,lidx1=None,cidx1=None):
    if lidx1==None: lidx1=lidx0
    if cidx1==None: cidx1=cidx0
    
    if lidx1<lidx0: return s.alloc(lidx1,cidx0,lidx0,cidx1)
    if cidx1<cidx0: return s.alloc(lidx0,cidx1,lidx1,cidx0)

    if s._lidx0==None:
      s._lines=[[" "]*(cidx1-cidx0+1) for i in range(lidx1-lidx0+1)]
      s._lidx0=lidx0
      s._lidx1=lidx1
      s._cidx0=cidx0
      s._cidx1=cidx1
      return
    
    if cidx0<s._cidx0:
      s._lines=[[" "]*(s._cidx0-cidx0)+ln for ln in s._lines]
      s._cidx0=cidx0
    if cidx1>s._cidx1:
      s._lines=[ln+[" "]*(cidx1-s._cidx1) for ln in s._lines]
      s._cidx1=cidx1

    if lidx0<s._lidx0:
      s._lines=[[" "]*(s._cidx1-s._cidx0+1) for i in range(s._lidx0-lidx0)]+s._lines
      s._lidx0=lidx0
    if lidx1>s._lidx1:
      s._lines=s._lines+[[" "]*(s._cidx1-s._cidx0+1) for i in range(lidx1-s._lidx1)]
      s._lidx1=lidx1

  def draw_char(s,x,y,sym):
    s.alloc(y,x)
    s._lines[y-s._lidx0][x-s._cidx0]=sym

  def __str__(s):
    return "\n".join(["".join(v) for v in s._lines]) 



class BitstreamVisualizer(IFaceRef):
  
  
  visualization_t=namedtuple(
    "visualization_t","points_empty points_full texts lines")

  def visualize(s,words):
    ram=words[:s.iface.CFG_LUT_REGISTER_COUNT]
    chain=list(reversed(words[s.iface.CFG_LUT_REGISTER_COUNT:]))
    idec=chain[:s.iface.CFG_INPUT_DECODER_REGISTER_COUNT]
    chain=chain[s.iface.CFG_INPUT_DECODER_REGISTER_COUNT:]
    pla_and=chain[:s.iface.CFG_PLA_AND_REGISTER_COUNT]
    chain=chain[s.iface.CFG_PLA_AND_REGISTER_COUNT:]
    pla_or=chain
    chain=[]

    def decode_words(words,n,m,ws):
      return [
        sum([v<<(ws*(m-j-1)) for j,v in enumerate(words[i:i+m])])
        for i in range(0,n*m,m)]
    def decode_words_rev(words,n,m,ws):
      return [
        sum([v<<(ws*(j)) for j,v in enumerate(words[i:i+m])])
        for i in range(0,n*m,m)]
    
    ram=decode_words_rev(ram,
      2**s.iface.SEGMENT_BITS,
      s.iface.RAM_CONFIG_BUFFER_SIZE,
      s.iface.WORD_SIZE)
    idec=decode_words(idec,
      s.iface.SELECTOR_BITS+s.iface.INTERPOLATION_BITS,
      s.iface.CFG_INPUT_DECODER_REGISTERS_PER_BIT,
      s.iface.WORD_SIZE)
    pla_and=decode_words(pla_and,
      s.iface.PLA_INTERCONNECTS,
      s.iface.CFG_PLA_AND_REGISTERS_PER_ROW,
      s.iface.WORD_SIZE)
    pla_or=decode_words(pla_or,
      s.iface.SEGMENT_BITS,
      s.iface.CFG_PLA_OR_REGISTERS_PER_COLUMN,
      s.iface.WORD_SIZE)
    

    points_empty=set()
    points_full=set()
    texts=set()
    lines=set()

    print("ram (raw, base, incline):")
    for raw in ram:
      incline=raw&((1<<s.iface.INCLINE_BITS)-1)
      base=(raw>>s.iface.INCLINE_BITS)
      print("  %24i %12i %12i"%(raw, base,incline))


    #                    x_or
    #                    |
    #     o o o o o x -- o x
    #     o o x o o o -- x o ------------- y_interconnects
    #     | | |          | |
    #  -- o o o        +---------+ ---+-------+
    #  -- o o o        |         |    |       |
    #  -- o x o        |         |    |       |
    #  -- o o x        |         |   h_ram    |
    #  -- o o o        |         |    |      h_inputs
    #  -- x o o        +---------+ ---+       |
    #  -- o o o                               |
    #  -- x x o  -----------------------------+
    #     
    #     |   |
    #     +-+-+
    #       n_inputs

    n_inputs=s.iface.SELECTOR_BITS+s.iface.INTERPOLATION_BITS
    h_inputs=s.iface.INPUT_WORDS*s.iface.WORD_SIZE
    h_interconnects=s.iface.PLA_INTERCONNECTS
    n_segbits=s.iface.SEGMENT_BITS
    

    for i in range(n_inputs):
      for j in range(h_inputs):
        if idec[i]&(1<<j): points_full.add((i+4,j))
        else: points_empty.add((i+4,j))
    
    y_pla=-h_interconnects-1
    x_pla=4+s.iface.INTERPOLATION_BITS

    for i in range(s.iface.SELECTOR_BITS*2):
      for j in range(h_interconnects):
        if pla_and[j]&(1<<i): points_full.add((i+x_pla,j+y_pla))
        else: points_empty.add((i+x_pla,j+y_pla))

    x_or=x_pla+s.iface.SELECTOR_BITS*2+1

    for i in range(n_segbits):
      for j in range(h_interconnects):
        if pla_or[i]&(1<<j): points_full.add((i+x_or,j+y_pla))
        else: points_empty.add((i+x_or,j+y_pla))
    

    return BitstreamVisualizer.visualization_t(
      points_empty,points_full,texts,lines)
  
  def render_ascii(s,vis):
    r=ASCIIRenderer()
    
    for (x,y) in vis.points_full:
      r.draw_char(x,y,"X")
    for (x,y) in vis.points_empty:
      r.draw_char(x,y,"-")


    return str(r)
        



