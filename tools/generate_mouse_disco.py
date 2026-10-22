#!/usr/bin/env python3
"""Rebuild the original, seamlessly looping prototype mouse disco (120 BPM)."""
import math, struct, wave
from pathlib import Path
rate = 22050
seconds = 8
path = Path(__file__).resolve().parents[1] / 'audio/music/mouse_disco.wav'
notes = [130.81,130.81,155.56,174.61,130.81,196,174.61,155.56]
with wave.open(str(path), 'wb') as out:
    out.setparams((1,2,rate,0,'NONE','not compressed'))
    for i in range(rate*seconds):
        t=i/rate; beat=t%0.5; eighth=t%0.25
        bass=math.sin(math.tau*notes[int(t/0.5)%8]*t)*math.exp(-beat*12)*0.20
        kick=math.sin(math.tau*(55*beat+1.8*(1-math.exp(-beat*35))))*math.exp(-beat*24)*0.28
        hat=math.sin(t*math.tau*7800)*math.sin(t*math.tau*5311)*math.exp(-eighth*90)*0.07
        chord=sum(math.sin(math.tau*f*t) for f in (261.6256,311.127,391.9954))*0.025*math.exp(-(t%0.25)*18)
        edge=min(1,t/0.006,(seconds-t)/0.006)
        out.writeframesraw(struct.pack('<h',int((bass+kick+hat+chord)*edge*23000)))
