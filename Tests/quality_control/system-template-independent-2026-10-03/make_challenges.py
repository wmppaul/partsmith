import json,pathlib,copy
r=pathlib.Path(__file__).parent;b=r/'evaluation-v1';jobs=json.loads((b/'jobs.json').read_text());cases=[]
def load(short):
 j=next(x for x in jobs if short in x['id']);d=b/j['id'];pages=json.loads((d/'inventory.json').read_text())['pages']; pages=[{k:v for k,v in p.items() if k not in ['inkComponents','sharedHeadings','sharedNavigation','sharedEndings']} for p in pages]
 return {'id':short,'scoreID':j['id'],'sourcePath':j['sourcePath'],'pages':pages,'profile':json.loads((d/'profile.json').read_text()),'overrides':json.loads((d/'templates.json').read_text())}
def add(c,id,expect,**meta):
 c=copy.deepcopy(c);c.update(id=id,expectation=expect,**meta);cases.append(c);return c
def limited(c,indices):
 c=copy.deepcopy(c);c['pages']=[p for p in c['pages'] if p['pageIndex'] in indices];c['overrides']=[p for p in c['overrides'] if p['pageIndex'] in indices];return c
for short in ['notte','erlkonig','mendelssohn']:
 c=load(short);a=add(c,short+'-no-seeds','noSuggestions');a['overrides']=[]
 a=add(c,short+'-first-system-only','onlyKnownSourceRoster');a['overrides']=[copy.deepcopy(c['overrides'][0])];a['overrides'][0]['systems']=[a['overrides'][0]['systems'][0]]
 a=add(c,short+'-seed-duration-not-target-duration','correctSourceSuggestionsAndNilCounts');
 for p in a['overrides']:
  for s in p['systems']:s['startBarNumber']=999;s['barCount']=42
 c=limited(c,[0]);a=add(c,short+'-missing-source-image','noSuggestions',unavailableImagePages=[0]);a=add(c,short+'-cancelled','noSuggestionsCancelled',cancelImmediately=True)
# Exact source rank negatives from frozen protocol. Selected ranks are 1-based physical source.
for short,pi,si,ranks,part in [('notte',0,0,[2,3],'piano'),('notte',0,2,[6,7],'piano'),('erlkonig',0,3,[8,9],'piano'),('erlkonig',10,2,[8,9],'piano'),('mendelssohn',1,0,[1,2],'organ'),('mendelssohn',1,1,[4,5,6],'organ'),('mendelssohn',2,1,[5,6,7],'organ'),('mendelssohn',1,0,[1,3,2],'organ')]:
 c=limited(load(short),[pi]);c['overrides']=[{'pageIndex':pi,'reason':'Independent malformed/subgroup source challenge','systems':[{'systemIndex':si,'bands':[{'partID':part,'candidateIDs':[x-1 for x in ranks]}],'omittedParts':[{'partID':p['id'],'reason':'Challenge only'} for p in c['profile']['parts'] if p['id']!=part]}]}]
 add(c,f'{short}-p{pi+1}-subgroup-'+','.join(map(str,ranks)),'noSuggestions',selectedSourceRanks=ranks)
for short,pi,ranks in [('mendelssohn',3,[6,8]),('mendelssohn',2,[10]),('notte',1,[1]),('notte',1,[2]),('notte',1,[3])]:
 c=load(short);c=limited(c,sorted({p['pageIndex'] for p in c['overrides']}|{pi}));p=next(p for p in c['pages'] if p['pageIndex']==pi);p['staves']=[s for s in p['staves'] if s['id'] not in [r-1 for r in ranks]]
 add(c,f'{short}-p{pi+1}-missing-'+','.join(map(str,ranks)),'noIncompleteOrWrongSourceSystemSuggestions',removedSourceRanks=ranks,mutationPageIndex=pi)
# Phantom five nominal lines in actual whitespace inside opening Piano pair.
c=limited(load('erlkonig'),[0]);p=c['pages'][0];a,lower=p['staves'][:2];s=copy.deepcopy(a);s['id']=1000;space=(a['staffLineFractions'][-1]-a['staffLineFractions'][0])/4;top=(a['staffLineFractions'][-1]+lower['staffLineFractions'][0])/2-2*space;s['staffLineFractions']=[top+i*space for i in range(5)];s['topFraction']=top-space;s['bottomFraction']=top+5*space;p['staves'].insert(1,s);add(c,'erlkonig-phantom-source-staff','noSuggestions')
# Profile mismatch and overlapping reviewed staff ownership.
c=limited(load('notte'),[0]);c['profile']['parts'][1]['staffCount']=3;add(c,'notte-changed-profile-count','noSuggestions')
c=limited(load('notte'),[0]);c['overrides'][0]['systems'][2]['bands'][0]['candidateIDs']=[0];add(c,'notte-overlapping-reviewed-seeds','noSuggestions')
# Frozen standalone ambiguous source fixture. Split choir/organ connectors can safely cause global abstention.
f=json.loads((r/'same-count-source-fixture.json').read_text());st=[]
for sy in f['systems']:
 for rank,ys in zip(sy['staffRanksOneBased'],sy['staffLineYs']):st.append({'id':rank-1,'staffLineFractions':[y/f['height'] for y in ys],'topFraction':(ys[0]-5)/f['height'],'bottomFraction':(ys[-1]+5)/f['height'],'confidence':1,'warnings':[]})
c={'id':'same-count-independent-source','sourcePath':str(r/'same-count-source-fixture.png'),'scoreID':'independent-synthetic','pages':[{'pageIndex':0,'pageWidth':800,'pageHeight':1030,'imageWidth':800,'imageHeight':1030,'staves':st,'warnings':[],'textSuggestions':[],'analysisSkewDegrees':0}],'profile':{'parts':[{'id':'soprano','name':'Soprano','staffCount':1},{'id':'alto','name':'Alto','staffCount':1},{'id':'bass','name':'Bass','staffCount':1},{'id':'organ','name':'Organ','staffCount':3}],'requiresSystemAssignment':True},'overrides':[{'pageIndex':0,'reason':'Frozen source labels','systems':[{'systemIndex':i,'bands':[{'partID':name,'candidateIDs':([i*5+j] if j<2 else list(range(i*5+2,i*5+5)))} for j,name in enumerate(s['reviewedSeedRoster'])],'omittedParts':[{'partID':p,'reason':'Absent source staff'} for p in ['soprano','alto','bass','organ'] if p not in s['reviewedSeedRoster']]} for i,s in enumerate(f['systems'][:2])]}]}
add(c,c['id'],'noSourceSupportedAmbiguousChoice')
(r/'challenge-inputs.json').write_text(json.dumps(cases,indent=2)+'\n');print(len(cases))
