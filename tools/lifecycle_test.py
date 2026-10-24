import time,json
from device_test import adb,tap,state,snap,ROOT
before=state()
tap(848,176)
time.sleep(.3)
muted=state()
assert muted['muted'] != before['muted'], 'mute touch did not persist'
adb('shell','input','keyevent','KEYCODE_HOME')
time.sleep(.6)
paused=state()
adb('shell','am','force-stop','org.littlelux.demo')
time.sleep(12)
adb('shell','am','start','-W','-n','org.littlelux.demo/com.godot.game.GodotAppLauncher')
time.sleep(2)
after=state()
snap('android-welcome-back.png')
assert after['owned']==paused['owned']
assert after['tutorial']==paused['tutorial']==8
assert after['crop']==paused['crop'] and after['recipe']==paused['recipe']
assert after['muted']==muted['muted']
assert after['coins']>=paused['coins']
events=adb('shell','run-as','org.littlelux.demo','cat','files/events.jsonl')
assert 'offline_reward_claim' in events
(ROOT/'docs/evidence/android-events.jsonl').write_text(events)
(ROOT/'docs/evidence/android-lifecycle.json').write_text(json.dumps({'before':before,'paused':paused,'after':after,'checks':'mute persisted; background+force-stop+12s+relaunch; workers/tutorial/selections retained; offline coins nonnegative'},indent=2))
print('LIFECYCLE PASS; offline/resume coin delta',after['coins']-paused['coins'])
