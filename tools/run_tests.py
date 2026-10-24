import os,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
godot=os.environ.get('GODOT','/media/james/dev-drive/mistbourne/.local/toolchain/godot/godot')
r=subprocess.run([godot,'--headless','--path',str(root),'-s','res://tools/tests.gd'],capture_output=True,text=True,timeout=120)
out=r.stdout+r.stderr
(root/'builds/tests.log').write_text(out)
print(out)
raise SystemExit(r.returncode or int('SCRIPT ERROR' in out or 'FAIL ' in out))
