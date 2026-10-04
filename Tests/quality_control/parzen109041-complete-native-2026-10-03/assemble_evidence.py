"""Reconstruct the exact reviewed archive from bounded Git payloads."""
from pathlib import Path
import hashlib
import json
import os

root = Path(__file__).resolve().parent
index = json.loads((root / 'evidence-chunks.json').read_text())
target = root / index['archive']
temporary = target.with_suffix(target.suffix + '.assembling')
combined = hashlib.sha256()
try:
    with temporary.open('wb') as output:
        for item in index['chunks']:
            data = (root / item['path']).read_bytes()
            if len(data) != item['bytes'] or hashlib.sha256(data).hexdigest() != item['sha256']:
                raise ValueError('Evidence chunk mismatch: ' + item['path'])
            combined.update(data)
            output.write(data)
    if combined.hexdigest() != index['sha256'] or temporary.stat().st_size != index['bytes']:
        raise ValueError('Assembled evidence archive mismatch')
    os.replace(temporary, target)
    print('Verified archive:', target)
finally:
    temporary.unlink(missing_ok=True)
