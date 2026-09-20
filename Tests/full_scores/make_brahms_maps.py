"""Build reviewer-owned Brahms maps from explicitly audited source structure.
Source-space geometry is populated from native inventory, then visually audited.
Do not interpret detected staff order as instrument identity without the reviewed counts.
"""
import json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
CASES={
'quartet':{
 'source':'sample_scores/medium_skewed/05_brahms_string_quartet_no3_op67_imslp_09200.pdf',
 'parts':[{'id':'violin1','name':'Violin I','staffCount':1,'sourceLabel':'1. Violine'},{'id':'violin2','name':'Violin II','staffCount':1,'sourceLabel':'2. Violine'},{'id':'viola','name':'Viola','staffCount':1,'sourceLabel':'Bratsche'},{'id':'cello','name':'Violoncello','staffCount':1,'sourceLabel':'Violoncello'}],
 'counts':[4,5,5,5,5,5,5,5,5,5,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5],
 'movements':[(1,'I. Vivace'),(10,'II. Andante'),(14,'III. Agitato (Allegretto non troppo)'),(19,'IV. Poco Allegretto con Variazioni')],
 'sections':[(17,2,'Trio'),(18,4,'Coda'),(22,4,'Doppio Movimento')],
 'nonmusic':{},
 'notes':'Every source musical system has all four labeled single-staff string parts in order. Rehearsal letters, top-only alternate endings and Da Capo/Coda navigation must be shared with lower parts. Original page1-3 Violin I excerpt was only a seed; all25 source pages re-surveyed.'},
 'trio':{
 'source':'sample_scores/lightly_skewed/02_brahms_clarinet_trio_op114_imslp_114011.pdf',
 'parts':[{'id':'clarinet','name':'Clarinet in A','staffCount':1,'sourceLabel':'Klarinette in A'},{'id':'cello','name':'Violoncello','staffCount':1,'sourceLabel':'Violoncello'},{'id':'piano','name':'Piano','staffCount':2,'sourceLabel':'Pianoforte'}],
 'counts':[3]+[4]*32+[0,0],
 'movements':[(1,'I. Allegro'),(12,'II. Adagio'),(18,'III. Andante grazioso'),(26,'IV. Allegro')],
 'sections':[(11,2,'Poco meno Allegro')],
 'nonmusic':{34:'Blank page following final cadence on PDFpage33.',35:'Publisher catalogue headed JOHANNES BRAHMS SÄMMTLICHE WERKE; no musical score.'},
 'notes':'Every musical system prints Clarinet in A, Violoncello and the two Piano staves. Piano grand staff must remain joined. Optional viola substitute is mentioned in title but no separate viola staff is printed. Complete music ends PDFpage33; p34blank and p35catalogue accounted for explicitly. Un poco sostenuto at PDFp25s3 begins inside the system and must be shared at its source position, not labeled at the start.'}}

def skeleton(name,c):
 out={'schemaVersion':1,'source':c['source'],'sourceSHA256':hashlib.sha256((ROOT/c['source']).read_bytes()).hexdigest(),'notationPolicy':'preserve-target','reviewStatus':'source_structure_reviewed_geometry_pending','profile':{'parts':c['parts']},'movements':[{'pageIndex':p-1,'systemIndex':0,'label':t} for p,t in c['movements']],'sections':[{'pageIndex':p-1,'systemIndex':s-1,'label':t} for p,s,t in c['sections']],'expectedSystemCount':sum(c['counts']),'expectedPhysicalStaffCount':sum(c['counts'])*4,'pages':[],'sharedMarkings':[],'notes':c['notes']}
 for p,n in enumerate(c['counts'],1):
  page={'pageIndex':p-1,'pageNumber':p,'expectedSystems':n,'expectedPhysicalStaves':4*n,'staffOrder':[q['id'] for q in c['parts'] for _ in range(q['staffCount'])],'review':'Complete raw page inspected for system/staff count, instrument continuity and movement structure; crop geometry pending.'}
  if not n:page.update({'status':'nonmusic','reason':c['nonmusic'][p],'systems':[]})
  out['pages'].append(page)
 return out

if __name__=='__main__':
 for name,c in CASES.items():
  path=ROOT/'Tests/full_scores'/f'brahms-{name}-map.json'
  if not path.exists():path.write_text(json.dumps(skeleton(name,c),indent=2,ensure_ascii=False)+'\n')
  print(path)
