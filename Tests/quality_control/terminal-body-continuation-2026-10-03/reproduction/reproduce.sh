#!/bin/bash
set -euo pipefail
report_dir="$(cd "$(dirname "$0")/.." && pwd)"
repo_dir="$(cd "$report_dir/../../.." && pwd)"
study_dir="$1"
if [[ -e "$study_dir" ]]; then echo "Choose a new output directory; never overwrite frozen evidence." >&2; exit 2; fi
mkdir -p "$study_dir"
study_dir="$(cd "$study_dir" && pwd)"
cd "$repo_dir"
unzip -q "$report_dir/frozen-core.zip" -d "$study_dir"
python3 - "$report_dir" "$study_dir" "$repo_dir" <<'PY'
from pathlib import Path
import gzip,json,sys,hashlib
report,out,repo=map(Path,sys.argv[1:])
binding=json.loads((report/'evidence-bindings.json').read_text())
for variant,files in binding['frozenCoreSources'].items():
 for rel,expected in files.items():assert hashlib.sha256((out/variant/rel).read_bytes()).hexdigest()==expected
cases=json.loads(gzip.decompress((report/'results/diagnostic-cases.json.gz').read_bytes()))
for item in cases:
 item['source']=str(repo/'sample_scores'/item['source'].split('/sample_scores/',1)[1])
 if item.get('imagePath'):item['imagePath']=str(report/'source-review-images/p38-original-rectified-raster.png')
(out/'cases.json').write_text(json.dumps(cases))
PY
core="$study_dir/rejected-v1/Core"
bash "$report_dir/reproduction/build.sh" "$core" tools/test_crop_quality.swift "$study_dir/crop765"
"$study_dir/crop765" > "$study_dir/crop765.log"
bash "$report_dir/reproduction/build.sh" "$core" Tests/quality_control/stem-ownership-2026-10-03/controls297.swift "$study_dir/controls297"
"$study_dir/controls297" "$study_dir/results297.json" > "$study_dir/controls297.log"
bash "$report_dir/reproduction/build.sh" "$core" Tests/quality_control/stem-ownership-2026-10-03/expanded336.swift "$study_dir/expanded336"
"$study_dir/expanded336" "$study_dir/results336.json" > "$study_dir/expanded336.log"
bash "$report_dir/reproduction/build.sh" "$core" "$report_dir/reproduction/replay.swift" "$study_dir/replay"
"$study_dir/replay" "$study_dir/cases.json" "$study_dir/replay-output" > "$study_dir/replay.log"
bash "$report_dir/reproduction/build.sh" "$core" "$report_dir/reproduction/replay-plans.swift" "$study_dir/replay-plans"
"$study_dir/replay-plans" "$study_dir/cases.json" "$study_dir/replay-output/witnesses.json" Tests/quality_control/profiles/medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521.json "$study_dir/replayed-plans.json"
