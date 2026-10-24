"""Create the self-contained handoff archive; omit imports, binaries and videos."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
root=Path(__file__).resolve().parents[1]
with ZipFile(root/'builds/little-lux-project.zip','w',ZIP_DEFLATED) as archive:
    for path in root.rglob('*'):
        relative=path.relative_to(root)
        if not path.is_file() or any(p in {'.godot','.git','builds','__pycache__'} for p in relative.parts):
            continue
        if path.suffix in {'.mp4','.avi'}:
            continue
        archive.write(path,Path('little-lux')/relative)
print(root/'builds/little-lux-project.zip')
