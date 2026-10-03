#!/bin/bash
set -euo pipefail
.build/extraction-venv/bin/python - <<'PY'
from pathlib import Path
import json,hashlib
root=Path('.build/heading-blocks-2026-10-03/candidate-final');case=Path('.build/heading-blocks-2026-10-03/native-worker-final')
j=json.loads((case/'schumann-summary.json').read_text());assert j['issues']==[] and j['planCanApply'] and j['bandCount']==825 and j['projectUnchanged'] and j['progressCleared'],j
assert len(json.loads((case/'schumann-inventory.json').read_text())['pages'])==56
for name,h in json.loads((root/'source-hashes.json').read_text()).items():assert hashlib.sha256((root/name).read_bytes()).hexdigest()==h,name
for item in json.loads(Path('Tests/quality_control/schumann-heading-block-output/frozen-baseline-inputs.json').read_text()):assert hashlib.sha256(Path(item['path']).read_bytes()).hexdigest()==item['sha256'],item['path']
assert not Path('.build/schumann-heading-output-2026-10-03/parts').exists(),'Preserve completed output'
PY
.build/schumann-heading-output-2026-10-03/exporter \
 --inventory .build/heading-blocks-2026-10-03/native-worker-final/schumann-inventory.json \
 --profile Tests/quality_control/profiles/medium-skewed-03-schumann-piano-quintet-op44-imslp-06822.json \
 --title 'Schumann Piano Quintet Op44 — Auto QC' --composer '' \
 --out .build/schumann-heading-output-2026-10-03/parts
