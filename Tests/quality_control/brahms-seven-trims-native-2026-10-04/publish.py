from pathlib import Path
import json,hashlib,tarfile,shutil
r=Path.cwd();w=r/'.build/brahms93521-reviewed-overlap-trim-2026-10-03';q=r/'Tests/quality_control/brahms-seven-trims-native-2026-10-04';peer=r/'Tests/quality_control/brahms-seven-trims-independent-2026-10-04';dest=r/'output/pdf/auto-qc-2026-10-04/brahms-quartet-93521-reviewed-trims'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();put=lambda p,d:p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n')
pm=json.loads((peer/'manifest.json').read_text())
for x in pm['files']:assert sha(peer/x['path'])==x['sha256']
rows=json.loads((peer/'evidence-members.json').read_text())
with tarfile.open(peer/'review-evidence.tar.gz') as t:
 assert {m.name for m in t.getmembers() if m.isfile()}=={x['path'] for x in rows}
 for x in rows:assert hashlib.sha256(t.extractfile(x['path']).read()).hexdigest()==x['sha256']
assert len(rows)==53
assert not dest.exists();dest.parent.mkdir(exist_ok=True);shutil.copytree(w/'parts',dest)
for p in (w/'parts').rglob('*'):
 if p.is_file():assert sha(p)==sha(dest/p.relative_to(w/'parts'))
shutil.copyfile(peer/'review.md',dest/'REVIEW.md')
(dest/'README.md').write_text('''# Brahms — String Quartet No. 3, Op. 67

Complete source-reviewed draft from IMSLP93521 with seven broad crops tightened manually. All 151 systems remain in every part: 604 bands, 42 copied source directions and 64 output pages. The earlier Viola “in tempo” repair is retained.

- [Violin I](Violin%20I.pdf) — 17 pages
- [Violin II](Violin%20II.pdf) — 16 pages
- [Viola](Viola.pdf) — 16 pages
- [Violoncello](Violoncello.pdf) — 15 pages
- [Editable Partsmith project](Brahms%20%E2%80%94%20String%20Quartet%20No.3,%20Op.67.partsmithproject)

The project embeds the complete original score and nine saved page corrections. In the current Partsmith app, choose a part and **Preview**, click a system and drag its blue top or bottom crop handle. Release applies the edit; Escape cancels and Undo restores it. The crop stays synced with Source view, saving and PDF export.

Independent review checked all seven edited passages against original/corrected source and all 35 changed output pages. The other 29 pages are pixel-identical to the reviewed parent. Intended notes and markings are preserved in the seven trims. Neighboring fragments remain where notation overlaps vertically and in unchanged crops; page turns still need musical judgment. This is an assisted draft, not an unattended Auto result. See [the independent review](REVIEW.md).

`manifest.json` is the frozen generation record: its pending-review label predates the final review above. `original-detection-plan.json` records the earlier automatic detection, not the final manual crop edges. `source-guard-before-edit.json` records the retained prior Viola repair. `proposed-edits-before-output.json` lists the seven new edits; `delivery-hashes.json` binds this complete delivery.
''')
put(dest/'delivery-hashes.json',{'sourceSHA256':'662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a','generationManifestSHA256':sha(dest/'manifest.json'),'independentReviewManifestSHA256':sha(peer/'manifest.json'),'files':[{'path':p.relative_to(dest).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(dest.rglob('*')) if p.is_file() and p.name!='delivery-hashes.json']})
put(q/'publication.json',{'delivery':str(dest.relative_to(r)),'deliveryReceiptSHA256':sha(dest/'delivery-hashes.json'),'generationManifestSHA256':sha(dest/'manifest.json'),'peerManifestSHA256':sha(peer/'manifest.json'),'rootVerifiedPeerPayloads':53,'allPublishedNativeFilesByteExact':True,'pages':64,'bands':604,'sourceCopies':42,'manualCropEdges':7})
put(q/'manifest.json',{'status':'Reviewed manual trim alternative; residual fragments and turn limitations remain','files':[{'path':p.relative_to(q).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(q.rglob('*')) if p.is_file() and p.name!='manifest.json']})
print(dest)
