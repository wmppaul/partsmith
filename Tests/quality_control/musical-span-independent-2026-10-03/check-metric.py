from pathlib import Path
import copy,json,subprocess,sys
root=Path(__file__).resolve().parent;out=root/'metric-self-check';out.mkdir(exist_ok=True);cases=json.loads((root/'inputs/cases.json').read_text());rows=[]
for c in cases:
 for scale in c['scales']:
  ts=[{'owner':o['owner'],'partID':o['partID'],'sourcePixels':o['pixels'],'sourceEnvelope':o['envelope'],'sourceMaskSHA256':o['maskRawSHA256'],'crop':[0,0,c['width'],c['height']],'lostPixels':0,'lostPixelIndices':[],'wholeNeighborCoreIDs':[],'allowedWholeNeighborIDs':o['allowedWholeNeighborIDs'],'spuriousWholeNeighborCoreIDs':[],'candidateIDs':[o['owner']]} for o in c['owners']]
  rows.append({'id':c['id'],'family':c['family'],'scale':scale,'sourceRawSHA256':c['sourceRawSHA256'],'sourceShape':[c['width'],c['height']],'analysisShape':[int(c['width']*scale),int(c['height']*scale)],'analysisReturned':True,'canApply':True,'bandCount':len(ts),'targets':ts,'components':[]})
def run(name,a,b):
 old=out/(name+'-baseline.json');new=out/(name+'-candidate.json');result=out/(name+'-comparison.json');old.write_text(json.dumps({'cases':a}));new.write_text(json.dumps({'cases':b}));p=subprocess.run([sys.executable,str(root/'compare.py'),str(old),str(new),str(result)],capture_output=True,text=True)
 return p.returncode,json.loads(result.read_text()) if result.exists() else None
rc,j=run('same',rows,rows);assert rc==0 and not j['newlyLostOwnerObservations']
idx=next(i for i,r in enumerate(rows) if r['id']=='original-case176');mask=(root/'inputs/original-case176/owner1.mask').read_bytes()
def crop_target(row,rect):
 t=row['targets'][1];lost=[i for i,v in enumerate(mask) if v and (i%720<rect[0]-1e-9 or i//720<rect[1]-1e-9 or i%720+1>rect[2]+1e-9 or i//720+1>rect[3]+1e-9)];t.update(crop=rect,lostPixels=len(lost),lostPixelIndices=lost)
a=copy.deepcopy(rows);b=copy.deepcopy(rows);crop_target(a[idx],[0,215,720,395]);crop_target(b[idx],[0,212,720,395]);assert a[idx]['targets'][1]['lostPixels']==659 and b[idx]['targets'][1]['lostPixels']==650
rc,j=run('only-nine-recovered',a,b);assert rc==0 and len(j['case176']['recoveredPixelIndices'])==9 and not j['case176']['targetAlgorithmClaimSatisfied']
crop_target(b[idx],[0,190,720,539]);rc,j=run('full-case176-recovered',a,b);assert rc==0 and j['case176']['targetAlgorithmClaimSatisfied'] and j['case176']['candidateLost']==0
ix=next(i for i,r in enumerate(rows) if r['id']=='staffline-filled-intact');b=copy.deepcopy(rows);b[ix]['components']=[{'bounds':[0,0,1,1],'staffIDs':[0,1],'isOwnershipAlternative':True}];rc,j=run('latent-false-shared-evidence',rows,b);assert rc==0 and sum(bool(x['newMultiOwnerAlternatives']) for x in j['negativeSourceEvidence'])==1
b=copy.deepcopy(rows);b[ix]['targets'][0]['wholeNeighborCoreIDs']=[1];b[ix]['targets'][0]['spuriousWholeNeighborCoreIDs']=[1];rc,j=run('new-spurious-neighbor',rows,b);assert rc==0 and sum(bool(x['newSpuriousWholeNeighborIDs']) for x in j['spuriousWholeNeighbors'])==1
b=copy.deepcopy(rows);b[0]['sourceRawSHA256']='wrong';rc,j=run('source-mismatch',rows,b);assert rc!=0
summary={'selfChecksPassed':6,'analyzerExecuted':False,'newCandidateInspected':False,'case176OnlyNineRecoveryRejected':True,'case176Full1400PixelRecoveryRequired':True,'latentFalseSharedAlternativeDetected':True,'newSpuriousNeighborDetected':True,'note':'Synthetic result records exercise the comparator. Exact case176 masks independently reproduce650/659 crop losses; no new algorithm has run.'}
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(summary)
