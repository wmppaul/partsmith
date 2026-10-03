from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import hashlib,json
r=Path('Tests/quality_control/heading-local-ownership-2026-10-03/matcher-fixtures');r.mkdir(exist_ok=True)
font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Times New Roman.ttf',38);cases=[]
def make(name,globalKind,localKind,expected):
 image=Image.new('RGB',(1200,900),'white');d=ImageDraw.Draw(image)
 def block(y,kind):
  d.text((120,y),'Allegro.',font=font,fill='black')
  if kind.startswith('metronome'):
   d.ellipse((272,y+24,286,y+33),fill='black');d.line((285,y+3,285,y+29),fill='black',width=2)
   if 'dotted' in kind:d.ellipse((292,y+25,295,y+28),fill='black')
   d.text((305,y),'= '+('128' if '128' in kind else '108'),font=font,fill='black')
  if kind=='stacked':d.text((120,y-42),'SCHERZO',font=font,fill='black')
  if kind=='cut-capital':d.rectangle((120,y,127,y+42),fill='white')
  if kind=='cut-period':d.rectangle((242,y,258,y+42),fill='white')
  if kind=='line-fringe':d.line((121,y+42,252,y+42),fill='black',width=1)
  if kind=='tip-fringe':d.polygon([(450,y+44),(454,y+39),(458,y+44)],fill='black')
  if kind=='gray-fringe':d.ellipse((450,y+28,454,y+32),fill=(254,254,254))
 block(140,globalKind);block(570,localKind)
 p=r/(name+'.png');image.save(p)
 cases.append({'id':name,'image':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'globalBounds':[100,90,480,190],'localBounds':[100,520,480,620],'recognizedGlobalText':'Allegro.','recognizedLocalText':'Allegro.','expectEquivalent':expected,'reason':'Complete original blocks including all added marks must be compared; matching OCR words do not discharge extra source ink.'})
make('identical-complete-blocks','plain','plain',True)
make('unrecognized-metronome-row','metronome108','plain',False)
make('unrecognized-different-metronome-number','metronome108','metronome128',False)
make('unrecognized-missing-metronome-dot','metronome108-dotted','metronome108',False)
make('unrecognized-stacked-title','stacked','plain',False)
make('local-capital-clipped','plain','cut-capital',False)
make('local-period-clipped','plain','cut-period',False)
make('global-staff-line-fragment','line-fringe','plain',False)
make('global-tiny-notation-tip','tip-fringe','plain',False)
make('global-faint-original-fragment','gray-fringe','plain',False)
(r/'cases.json').write_text(json.dumps({'beforeMatcherInspection':True,'cases':cases},indent=2)+'\n')
