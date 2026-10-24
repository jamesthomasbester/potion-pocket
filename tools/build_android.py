"""Uses installed build tools only; no game content is imported."""
import os, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
GODOT=os.environ.get('GODOT','/media/james/dev-drive/mistbourne/.local/toolchain/godot/godot')
JDK=os.environ.get('JAVA_HOME','/media/james/dev-drive/strata-dig-deeper/.tools/jdk')
env=dict(os.environ,JAVA_HOME=JDK,PATH=JDK+'/bin:'+os.environ['PATH'])
r=subprocess.run([GODOT,'--headless','--path',str(ROOT),'--export-debug','Android Debug',str(ROOT/'builds/little-lux-debug.apk')],env=env,text=True,capture_output=True)
(ROOT/'builds/export.log').write_text(r.stdout+r.stderr)
print((r.stdout+r.stderr)[-2000:])
raise SystemExit(r.returncode or int('ERROR:' in r.stderr))
