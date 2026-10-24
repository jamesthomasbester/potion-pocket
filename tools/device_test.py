"""Real-time, public-touch-control Android playthrough. No game-state writes.
Read-only run-as save inspection determines available actions; all progression is
through adb input tap/swipe. Installed test app has a separate package/save.
"""
import subprocess,time,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ADB='/media/james/dev-drive/strata-dig-deeper/.tools/android-sdk/platform-tools/adb'
def adb(*args, binary=False):
 return subprocess.check_output([ADB,*args],text=not binary)
def tap(x,y): adb('shell','input','tap',str(x),str(y))
def snap(name): (ROOT/'docs/evidence'/name).write_bytes(adb('exec-out','screencap','-p',binary=True))
def state():
 try: return json.loads(adb('shell','run-as','org.littlelux.demo','cat','files/little_lux.json'))
 except Exception: return {}
# Coordinates are supplied after inspecting the initial device screenshot.
if __name__=='__main__':
 print(adb('shell','wm','size'))
 print(adb('shell','run-as','org.littlelux.demo','ls','files'))
 snap('android-starting.png')
 print(state())

def play():
 adb('shell','am','force-stop','org.littlelux.demo')
 adb('shell','pm','clear','org.littlelux.demo')
 adb('shell','am','start','-W','-n','org.littlelux.demo/com.godot.game.GodotAppLauncher')
 start=time.monotonic()
 time.sleep(2)
 recorder=subprocess.Popen([ADB,'shell','screenrecord','--time-limit','100','--bit-rate','3000000','/sdcard/little-lux-intro.mp4'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 snap('android-starting.png')
 milestones={}
 selected=False
 costs={'gardener':32,'brewer':56,'cashier':80,'recipe':48,'renovation':320,'grow':48,'brew':64,'capacity':56,'service':40}
 ypos={'gardener':464,'brewer':784,'cashier':1104,'recipe':464,'grow':784,'brew':1104,'service':1424,'capacity':1744,'renovation':2064}
 while time.monotonic()-start<300:
  # Never issue blind taps into another application.
  activity=adb('shell','dumpsys','activity','activities')
  resumed=[l for l in activity.splitlines() if 'topResumedActivity=' in l or 'mResumedActivity:' in l]
  if resumed and not any('org.littlelux.demo' in l for l in resumed):
   raise RuntimeError('Little Lux lost foreground; stopping input: '+str(resumed))
  s=state()
  own=s.get('owned',{})
  if not own.get('gardener'):
   tap(796,2312);tap(282,2016)
   if 'garden' not in milestones and state().get('flags',{}).get('first_harvest'):
    snap('android-garden.png');milestones['garden']=time.monotonic()-start
   tap(282,2312)
  if not own.get('brewer'): tap(282,2016)
  if not own.get('cashier'): tap(796,2016)
  s=state()
  for key,cost in costs.items():
   if s.get('owned',{}).get(key): continue
   if s.get('coins',0)>=cost:
    tap(282 if key in ['gardener','brewer','cashier'] else 796,2164)
    tap(540,ypos[key]);tap(540,2276)
    if state().get('owned',{}).get(key):
     milestones[key]=round(time.monotonic()-start,1)
     print('DEVICE purchase',key,milestones[key],flush=True)
     if key=='cashier': snap('android-automated.png')
     if key=='renovation': snap('android-renovated.png')
   break
  if state().get('owned',{}).get('recipe') and not selected:
   tap(796,2312);tap(796,1868);snap('android-moonflower.png');tap(282,2312);tap(796,1868)
   selected=True
  time.sleep(.5)
 final=state()
 snap('android-five-minute.png')
 (ROOT/'docs/evidence/android-milestones.json').write_text(json.dumps({'wall_seconds':time.monotonic()-start,'milestones':milestones,'state':final},indent=2))
 print('DEVICE END',json.dumps(final),flush=True)
 recorder.wait(timeout=5)
 adb('pull','/sdcard/little-lux-intro.mp4',str(ROOT/'docs/evidence/android-intro.mp4'))
 adb('shell','rm','/sdcard/little-lux-intro.mp4')
 (ROOT/'builds/android-performance.txt').write_text(adb('shell','dumpsys','meminfo','org.littlelux.demo')+'\n'+adb('logcat','-d','-s','godot'))
 if not final.get('flags',{}).get('tutorial_complete'): raise RuntimeError('Intro did not finish within five minutes')

if __name__=='__main__' and '--play' in __import__('sys').argv: play()
