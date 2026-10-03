from pathlib import Path
import json,hashlib,shutil,pymupdf as fitz
from PIL import Image,ImageDraw
R=Path.cwd();W=R/'.build/qc-schumann270922-review';O=R/'Tests/quality_control/schumann270922-complete-review';ID='lightly-skewed-05-schumann-frauenliebe-und-leben-op42-imslp-270922';B=R/'.build/auto-qc/connector8-harmonic/corpus'/ID;m=json.load(open(B/'parts/manifest.json'));src=fitz.open(m['source'])
# Source regions were marked manually from the whole rendered source, before comparing crop bounds.
regions=[]
def add(key,p,s,text,rect,affected,status,reason):
 regions.append({'id':key,'sourcePage':p,'system':s,'text':text,'sourceRegion':rect,'regionMethod':'Manual independent source inspection; enclosing review region, not detector/crop-derived glyph bounds','affectedParts':affected,'status':status,'reason':reason})
opening=[(1,1,'Larghetto.',[78,151,134,165]),(2,3,'Innig, lebhaft.',[79,325,151,339]),(5,3,'Mit Leidenschaft.',[79,301,163,315]),(7,1,'Innig.',[79,65,110,78]),(9,1,'Ziemlich schnell.',[74,69,157,82]),(11,1,'Langsam, mit innigem Ausdruck.',[71,68,225,82]),(13,1,'Fröhlich, innig.',[80,68,154,81]),(15,1,'Adagio.',[74,96,113,109])]
for n,(p,s,t,r) in enumerate(opening,1):add(f'opening-tempo-{n}',p,s,t,r,['piano'],'omitted','Opening tempo is complete in voice; it is outside the piano crop and no copied source marking exists.')
nums=[(1,1,[247,138,270,153]),(2,3,[247,303,272,320]),(5,3,[247,289,271,303]),(7,1,[247,46,270,61]),(9,1,[247,47,270,63]),(11,1,[246,48,270,64]),(13,1,[249,49,271,64]),(15,1,[247,62,270,77])]
for n,(p,s,r) in enumerate(nums,1):
 add(f'song-index-{n}',p,s,str(n)+'.',r,['piano'],'omitted','Song index is outside the piano crop.')
 if n>1:add(f'song-index-{n}-voice',p,s,str(n)+'.',r,['voice'],'clipped' if n==3 else 'omitted','Voice retains only the bottom of numeral 3.' if n==3 else 'Song index is absent from the voice output.')
add('etwas-langsamer',5,4,'Etwas langsamer.',[332,422,422,436],['piano'],'omitted','Voice has the new tempo; piano retains the preceding ritard. but no slower-tempo heading.')
add('adagio-song3',6,2,'Adagio.',[281,176,322,189],['piano'],'omitted','Printed above voice; piano has a ritard. and subsequent a tempo but loses this Adagio cue.')
add('nach-und-nach',8,1,'Nach und nach rascher.',[248,55,355,66],['piano'],'omitted','Gradual acceleration appears only in the voice output.')
add('lebhafter',12,1,'Lebhafter.',[299,89,350,100],['piano'],'clipped','Piano source crop starts at y=94.384615 pt, through the word; voice contains the complete instruction below its staff.')
add('schneller-a-tempo',14,1,'Schneller. / a tempo',[271,47,322,68],['piano'],'omitted','Piano retains ritard. but omits the later faster/a-tempo instruction, leaving the tempo transition incomplete.')
add('postlude-adagio',16,2,'Adagio.',[107,266,147,280],['voice'],'omitted','Printed above the piano postlude; the voice retains silent bars and the final fermata but lacks this tempo cue.')
add('postlude-tempo',16,2,'Tempo wie das erste Lied.',[197,269,330,283],['voice'],'omitted','Return to the opening song tempo is present in piano and absent from the silent voice bars.')
# Both instrument identities were inspected at every printed system, including the postlude's retained silent voice.
source_notes={
1:'Four systems. Song 1, title/composer and Larghetto. Low piano ledger chords and slurs in system 3 retained. Voice includes piano peaks in systems 3–4; piano includes clipped vocal text.',
2:'Five systems. Song 1 closes in system 2; song 2 begins in system 3. Both 1-staff voice and 2-staff piano continue. Song index 2 omitted. Piano ledger notes, pedal mark and long bass slur in system 3 retained; voice system 4 includes preceding piano bass/pedal fragments.',
3:'Five systems of song 2. Vocal lyric extensions, ornaments and ritard. are retained. Piano low ledger notes, repeated chords, pedal signs and repeated clef changes retained.',
4:'Five systems of song 2. Long vocal ties/slurs and low piano ledger notes retained. Large bass/pedal fragments above voice system 2 and upper-piano fragments beneath several voice strips.',
5:'Five systems. Song 2 closes in system 2; song 3 begins in system 3. Song index 3 is cut in half in voice. Etwas langsamer above system 4 is missing from piano. Piano high ledger passage in system 2 and low bass staccato notes in system 4 retained.',
6:'Five systems of song 3. Fermatas and local ritard./a tempo marks retained where locally printed; Adagio above voice system 2 absent from piano. Last piano arpeggiated chord, pedal releases, rests and fermatas retained.',
7:'Five systems of song 4. Song index 4 omitted. Voice and both piano staves retain all observed printed notation. The damaged left clef/staff area in the last piano system exists in the source scan and is not export clipping.',
8:'Five systems of song 4. Nach und nach rascher is omitted from piano. Repeated ritard. marks and low bass ledger/pedal signs retained. Final double bar and source rests present.',
9:'Five systems of song 5. Ziemlich schnell missing from piano, as is song number 5. Piano Immer mit Pedal is complete. Sixteenth/eighth accompaniment, low/high ledgers, clef changes and vocal lyric syllables retained.',
10:'Five systems finishing song 5. Both written ritard./a tempo pairs and final dim. remain complete. Voice system 5 includes the preceding piano bass/pedal remnants. No target notes or lyric syllables observed missing.',
11:'Five systems of song 6. Song number 6 omitted; opening tempo missing from piano. Whole-note bass ledgers/slurs and pedal releases retained. Voice strips include large preceding-piano bass/ledger fragments around systems 2 and 4.',
12:'Five systems finishing song 6. Lebhafter. is clipped at the piano crop top in system 1. Other piano dim., ritard., Adagio, low-ledger chords, clef changes, pedal signs and vocal lyrics retained. Voice system 5 includes the preceding low piano line.',
13:'Five systems of song 7. Song number 7 omitted and Fröhlich, innig missing from piano. Repeated sixteenth-note piano accompaniment, slurs and vocal text retained. Piano peaks are prominent under all five voice strips.',
14:'Five systems finishing song 7. Faster/a-tempo instruction missing from piano system 1. Voice Noch schneller and piano Presto are both present at system 3; the voice contains a clipped neighboring Presto fragment. Langsamer is complete in piano and incidentally complete in voice. Final piano slurs, low notes and pedal signs retained.',
15:'Four systems starting song 8. Song number 8 omitted; opening Adagio missing from piano. Voice/piano separation is comparatively clear. All observed chords, ties, accidentals, sf markings and vocal syllables retained.',
16:'Four systems finishing song 8. Voice finishes the lyric on Welt!, then remains printed with rests to the final fermata. All four voice staves retained, no inferred tacets. Piano postlude Adagio and Tempo wie das erste Lied are absent from voice. Both piano staves, extreme low ledger chords and final fermatas are complete.'}
source_pages=[{'sourcePage':p,'printedSystems':4 if p in (1,15,16) else 5,'staffPatternObserved':['voice','piano upper','piano lower'],'notes':source_notes[p],'sourceImage':str(W/f'edges-{p:02}.png'),'reviewed':True} for p in range(1,17)]
voice_turns=['Uninterrupted phrase: “meinem” continues “Himmel” on the next page.','Uninterrupted phrase: “wie so” continues “gut!” on the next page.','Uninterrupted phrase: “an das” continues “Herze mein” on the next page.','Uninterrupted phrase: “scheuen” continues “eine thörigte” on the next page.','Only a short printed quarter rest after “kann,” before “sollst du nicht”; no comfortable extended-rest turn established.','Uninterrupted phrase: “was” continues “lieben heisst” on the next page.','Final page; song 8 and its silent voice postlude are present.']
piano_turns=['Turn after song 1 double bar and fermata; suitable section boundary.','Continues song 2 during repeated accompaniment; no extended rest at turn.','Continues song 2 during accompaniment; no extended rest at turn.','Continues song 3 after a short rest in the repeated chord pattern; performance turn remains unproven.','Continues song 4 during flowing accompaniment; no extended rest at turn.','Turn after song 4 final double bar; suitable section boundary.','Continues song 5 while both-hand arpeggios are active; difficult turn.','Continues song 6 on sustained chordal accompaniment; player-specific turn needs review.','Turn after song 6 double bar; suitable section boundary.','Both hands have continuous sixteenth notes across this song-7 turn; difficult turn.','Turn in song 8 across sustained tied harmony; player-specific turn needs review.','Final page, complete piano postlude and fermatas.']
outputs=[];bands=[]
for part in m['parts']:
 for pn in range(1,part['outputPages']+1):
  bs=[b for b in part['placements'] if b['outputPage']==pn];issueids=[x['id'] for x in regions if part['id'] in x['affectedParts'] and any((b['sourcePage'],b['system'])==(x['sourcePage'],x['system']) for b in bs)]
  outputs.append({'part':part['id'],'outputPage':pn,'bandIDs':[b['id'] for b in bs],'reviewedImage':str(W/f"{part['id']}-{pn:02}.png"),'allBandsComparedWithSource':True,'targetNotesLyrics':'No missing target note, rest, signature, clef, articulation or vocal syllable observed in source/output comparison. See separately recorded directions.','directionIssues':issueids,'neighboringNotation':'Visible neighboring piano note/beam/slur/staff fragments, often underlines or extra notes below the intended voice.' if part['id']=='voice' and pn!=7 else ('Neighbor piano fragments in the first four song-7 strips; song-8/rest strips are comparatively clean.' if part['id']=='voice' else ('Clipped or complete neighboring vocal text and occasional vocal staff/notes remain above many piano systems.' if pn!=12 else 'Mostly clear piano; a small clipped Welt! lyric fragment remains above the postlude.')),'layout':'No page-edge clipping or misplaced crop found; complete source systems in order.','turn':(voice_turns if part['id']=='voice' else piano_turns)[pn-1],'lastPlacementBottomPoints':max(b['destinationRect'][3] for b in bs)})
 for b in part['placements']:
  bands.append({'id':b['id'],'part':part['id'],'sourcePage':b['sourcePage'],'system':b['system'],'outputPage':b['outputPage'],'sourceRect':b['sourceRect'],'reviewVersion':2,'identity':'Correct printed voice or two-staff piano group, source-inspected','coverage':'Present exactly once and in source order','targetNotesRestsClefsSignatures':'Visually retained','targetLyrics':'All printed vocal syllables and continuation lines visually retained' if part['id']=='voice' else 'Not applicable; voice text in this piano crop is neighboring ink','localArticulationDynamicsSlursPedals':'Visually retained; shared tempo/direction issues are recorded separately','sharedDirectionIssueIDs':[x['id'] for x in regions if part['id'] in x['affectedParts'] and (b['sourcePage'],b['system'])==(x['sourcePage'],x['system'])],'neighborPolicy':'Context retained; no clean-isolation pass claimed. See full-source/output-page review.'})
review={'status':'draft-fails-shared-directions-and-performance-layout','scope':'Complete 16-page source, all 77 systems, both parts, all 154 bands and all 19 exported pages.','method':'Every full source page with crop overlays visually compared against every full output page. Source identities/system counts checked independently. High-risk clipped directions also enlarged. No detector-based threshold was used as a musical pass.','sourcePages':source_pages,'bands':bands,'outputPages':outputs,'sharedDirections':regions,'notes':'The baseline export has no automatic shared-direction pass or source-header detection. This audit does not claim that enabling the new experimental workflow fixes these findings; that requires a fresh run and review. Production was read-only during this review.'}
(O/'review.json').write_text(json.dumps(review,indent=2,ensure_ascii=False)+'\n')
for n in ['provenance.json','plan-currency.json','output-map.txt','render.py']:shutil.copy2(W/n,O/n)
(O/'write-review.py').write_text(Path(__file__).read_text())
# Render true PDF source and true existing PDF output, not a reconstruction, for decisive landmarks.
for key,p,s,part_id,clip in [('lebhafter',12,1,'piano',[286,83,355,111]),('song-index-3',5,3,'voice',[240,284,280,313]),('schneller',14,1,'piano',[265,42,330,78])]:
 part=next(x for x in m['parts'] if x['id']==part_id);b=next(x for x in part['placements'] if x['sourcePage']==p and x['system']==s);out=fitz.open(B/'parts'/part['file'])
 sr=b['sourceRect'];dr=b['destinationRect'];z=(dr[2]-dr[0])/(sr[2]-sr[0]);dst=[dr[0]+(clip[0]-sr[0])*z,dr[1]+(clip[1]-sr[1])*z,dr[0]+(clip[2]-sr[0])*z,dr[1]+(clip[3]-sr[1])*z]
 pm=src[p-1].get_pixmap(matrix=fitz.Matrix(6,6),clip=fitz.Rect(clip));first=Image.frombytes('RGB',(pm.width,pm.height),pm.samples)
 actual=fitz.Rect(dst)&fitz.Rect(dr)
 second=None
 if not actual.is_empty:
  pm=out[b['outputPage']-1].get_pixmap(matrix=fitz.Matrix(6,6),clip=actual);second=Image.frombytes('RGB',(pm.width,pm.height),pm.samples)
 canvas=Image.new('RGB',(max(first.width,second.width if second else 420)+20,first.height+(second.height if second else 90)+72),'white');draw=ImageDraw.Draw(canvas)
 draw.text((10,5),'Original source',fill='black');canvas.paste(first,(10,22));y=first.height+50
 draw.text((10,y-17),'Actual output pixels retained from this source region',fill='black')
 if second:canvas.paste(second,(10,y))
 else:draw.multiline_text((10,y+8),"None. The entire source heading is outside\nthis part's retained crop.",fill='black',spacing=6)
 canvas.save(O/f'{key}-comparison.png')
# Preserve hashes of all reviewed rendered pages; full-size pixels remain in scratch and can be reproduced from the authoritative PDFs.
(O/'rendered-image-hashes.json').write_text(json.dumps([{'path':str(f),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in sorted(W.glob('*.png'))],indent=2)+'\n')
print('Wrote complete review:',len(bands),'bands',len(outputs),'output pages',len(regions),'separately recorded shared direction/index defects')
