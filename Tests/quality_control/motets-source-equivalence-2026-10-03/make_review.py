from pathlib import Path
from PIL import Image,ImageDraw
D=Path('.build/motets-source-equivalence-2026-10-03');(D/'review').mkdir(exist_ok=True)
for i in range(0,18,2):
 canvas=Image.new('RGB',(1260,1840),'#eeeeee');d=ImageDraw.Draw(canvas)
 for r,p in enumerate([i+1,i+2]):
  for c,edition in enumerate(['101579','101580']):
   im=Image.open(D/edition/f'page-{p:02d}.png').convert('RGB');im.thumbnail((610,865));x=10+c*630;y=30+r*915
   d.text((x,y-20),f'IMSLP {edition} / physical page {p}',fill='black');canvas.paste(im,(x,y))
 canvas.save(D/'review'/f'pages-{i+1:02d}-{i+2:02d}.png')
canvas=Image.new('RGB',(1240,780),'white');d=ImageDraw.Draw(canvas)
for c,e in enumerate(['101579','101580']):
 im=Image.open(D/e/'page-04.png').convert('RGB').crop((600,600,1200,1350));canvas.paste(im,(c*620+10,25));d.text((c*620+10,6),f'{e}: page 4 pixels [600,600,1200,1350]',fill='black')
canvas.save(D/'review'/'page-04-native-detail.png')
