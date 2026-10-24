"""Original synthesized PCM assets. No samples or external content."""
import math,wave,struct
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'game/audio'
out.mkdir(exist_ok=True)
rate=44100
for name,freq in {'harvest':520,'brew':180,'stock':740,'sale':1046,'dream_sale':1320,'upgrade':880,'tap':420,'ambience':130.81}.items():
 duration=8 if name=='ambience' else .28
 frames=[]
 for i in range(int(rate*duration)):
  t=i/rate
  if name=='ambience':
   env=math.sin(math.pi*t/duration)**2
   value=sum(math.sin(2*math.pi*f*t) for f in [130.81,164.81,196])/3*env*.025
  else:
   env=min(t*60,1)*(1-t/duration)**2
   value=(math.sin(2*math.pi*(freq*t+160*t*t))*.75+math.sin(2*math.pi*freq*2*t)*.15)*env*.15
  frames.append(struct.pack('<h',int(max(-1,min(1,value))*32767)))
 with wave.open(str(out/(name+'.wav')),'wb') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(b''.join(frames))
