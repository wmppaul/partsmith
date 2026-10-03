#!/bin/bash
set -euo pipefail
report_dir="$(cd "$(dirname "$0")/.." && pwd)"
repo_dir="$(cd "$report_dir/../../.." && pwd)"
study_dir="$1"
if [[ -e "$study_dir" ]]; then echo "Choose a new directory; do not replace frozen evidence." >&2; exit 2; fi
mkdir -p "$study_dir"
study_dir="$(cd "$study_dir" && pwd)"
cd "$repo_dir"
unzip -q "$report_dir/frozen-core.zip" -d "$study_dir"
python3 - "$report_dir" "$study_dir" "$repo_dir" <<'PY'
from pathlib import Path
import json,gzip,hashlib,sys
report,out,repo=map(Path,sys.argv[1:])
b=json.loads((report/'evidence-bindings.json').read_text())
for name,files in b['frozenCoreSources'].items():
 for rel,h in files.items():assert hashlib.sha256((out/name/rel).read_bytes()).hexdigest()==h
cases=json.loads(gzip.decompress((report/'results/native-baseline-cases.json.gz').read_bytes()))
for c in cases:
 c['source']=str(repo/'sample_scores'/c['source'].split('/sample_scores/',1)[1])
 if c.get('imagePath'):c['imagePath']=str(repo/'Tests/quality_control/terminal-body-continuation-2026-10-03/source-review-images/p38-original-rectified-raster.png')
(out/'cases.json').write_text(json.dumps(cases))
PY
core="$study_dir/candidate-v1/Core"
independent="Tests/quality_control/terminal-body-independent-2026-10-03"
bash "$independent/build.sh" "$core" "$study_dir/controls180"
"$study_dir/controls180" "$study_dir/results180.json" "$study_dir/sources180"
python3 "$independent/compare.py" "$study_dir/results180.json" "$study_dir/comparison180.json"
bash "$independent/build-tied.sh" "$core" "$study_dir/tied36"
"$study_dir/tied36" "$study_dir/results36.json" "$study_dir/sources36"
python3 "$independent/compare.py" "$study_dir/results36.json" "$study_dir/comparison36.json" --tied
bash "$report_dir/reproduction/build.sh" "$core" tools/test_crop_quality.swift "$study_dir/crop765"
"$study_dir/crop765"
bash "$report_dir/reproduction/build.sh" "$core" Tests/quality_control/stem-ownership-2026-10-03/controls297.swift "$study_dir/controls297"
"$study_dir/controls297" "$study_dir/results297.json"
bash "$report_dir/reproduction/build.sh" "$core" Tests/quality_control/stem-ownership-2026-10-03/expanded336.swift "$study_dir/expanded336"
"$study_dir/expanded336" "$study_dir/results336.json"
bash "$report_dir/reproduction/build.sh" "$core" "$report_dir/reproduction/replay.swift" "$study_dir/replay"
"$study_dir/replay" "$study_dir/cases.json" "$study_dir/replay-output"
bash "$report_dir/reproduction/build.sh" "$core" "$report_dir/reproduction/replay-plans.swift" "$study_dir/replay-plans"
"$study_dir/replay-plans" "$study_dir/cases.json" "$study_dir/replay-output/witnesses.json" Tests/quality_control/profiles/medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521.json "$study_dir/replayed-plans.json"
