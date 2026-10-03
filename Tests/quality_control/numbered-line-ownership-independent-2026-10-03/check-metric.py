from pathlib import Path
import copy,json,subprocess,sys
root=Path(__file__).resolve().parent;out=root/'metric-self-check';out.mkdir(exist_ok=True)
cases=json.loads((root/'inputs/cases.json').read_text());rows=[]
for c in cases:
 for scale in c['scales']:
  targets=[{'owner':o['owner'],'partID':o['partID'],'sourcePixels':o['pixels'],'sourceEnvelope':o['envelope'],'sourceMaskSHA256':o['maskRawSHA256'],'crop':[0,0,c['width'],c['height']],'lostPixels':0,'lostPixelIndices':[],'wholeNeighborCoreIDs':[],'candidateIDs':[o['owner']]} for o in c['owners']]
  rows.append({'id':c['id'],'family':c['family'],'scale':scale,'sourceRawSHA256':c['sourceRawSHA256'],'sourceShape':[c['width'],c['height']],'analysisShape':[int(c['width']*scale),int(c['height']*scale)],'analysisReturned':True,'canApply':True,'bandCount':4,'targets':targets})
def run(name,a,b):
 old=out/(name+'-baseline.json');new=out/(name+'-candidate.json');result=out/(name+'-comparison.json')
 old.write_text(json.dumps({'cases':a}));new.write_text(json.dumps({'cases':b}));p=subprocess.run([sys.executable,str(root/'compare.py'),str(old),str(new),str(result)],capture_output=True,text=True)
 return p.returncode,json.loads(result.read_text()) if result.exists() else None
rc,j=run('same',rows,rows);assert rc==0 and not j['newlyLostOwnerObservations']
a=copy.deepcopy(rows);b=copy.deepcopy(rows);raw=(root/'inputs'/rows[0]['id']/'owner0.mask').read_bytes();pixels=[i for i,v in enumerate(raw) if v][:2]
a[0]['targets'][0].update(lostPixels=1,lostPixelIndices=[pixels[0]]);b[0]['targets'][0].update(lostPixels=1,lostPixelIndices=[pixels[1]])
rc,j=run('same-count-different-pixel',a,b);assert rc==0 and len(j['newlyLostOwnerObservations'])==1 and j['newlyLostOwnerObservations'][0]['newlyLostPixelIndices']==[pixels[1]]
b=copy.deepcopy(rows);b[0]['sourceRawSHA256']='wrong';rc,j=run('mismatched-source',rows,b);assert rc!=0
b=copy.deepcopy(rows);b[0]['targets'][0]['candidateIDs']=[1];rc,j=run('wrong-assignment',rows,b);assert rc==0 and len(j['candidateInvariantFailures'])==1
summary={'comparisonSelfChecks':4,'passed':4,'analyzerExecuted':False,'candidateInspected':False,'note':'Deliberately artificial result records exercise metric integrity, not crop performance.'}
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(summary)
