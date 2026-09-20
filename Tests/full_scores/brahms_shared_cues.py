"""Source-verified Brahms common directions; PDF points, no re-engraving."""
# page, system (one-based), text, rectangle, optional target IDs
QUARTET=[
(1,1,'Vivace',[124,157,172,172]),(1,3,'A',[300,450,331,475]),
(2,1,'B',[292,42,319,69]),(2,5,'C',[60,596,85,622]),(3,3,'D',[310,331,339,357]),
(4,1,'1. / 2. alternate-ending brackets',[308,41,378,56]),(4,3,'E',[375,313,400,339]),
(5,1,'F; in tempo',[56,34,124,62]),(5,3,'G',[178,318,202,342]),(5,5,'H',[206,607,229,633]),
(6,2,'in tempo',[166,181,220,197]),
(7,1,'I',[351,28,376,53]),(7,5,'K',[61,591,85,616]),(8,3,'L',[340,314,365,340]),(9,1,'M',[426,28,451,54]),
(10,1,'Andante',[127,48,177,63]),(10,2,'A',[359,180,384,206]),(10,5,'B',[57,596,81,622]),
(11,2,'C',[281,218,306,244]),(12,2,'rit. un poco',[195,245,261,263]),(12,2,'D; in tempo',[272,225,340,264]),(13,3,'E',[64,395,88,421]),
(14,1,'Agitato (Allegretto non troppo)',[124,56,289,73]),(14,4,'A',[52,566,75,590]),
(15,3,'B; poco a poco in tempo',[286,322,421,347]),(16,2,'C',[62,157,85,183]),(16,5,'D',[62,598,86,624]),
(17,1,'Da Capo destination sign (cross)',[358,34,374,50]),(17,2,'Trio',[61,179,91,197]),(17,4,'E',[62,452,86,478]),
(18,1,'F',[56,38,80,63]),(18,3,"Da Capo sin’ al [source cross] e poi la Coda",[409,466,556,482],['violin1','violin2','viola']),(18,4,'Coda',[77,481,111,498]),
(19,1,'Poco Allegretto con Variazioni',[141,42,315,58]),
(20,5,'Fermata over final repeat barline',[548,631,564,641]),
(21,3,'1. / 2. alternate-ending brackets',[382,322,538,339]),(22,1,'2da volta rit.',[294,47,371,64]),(22,4,'Doppio Movimento',[80,481,188,500]),
(23,4,'1. / 2. alternate-ending brackets',[149,477,295,492]),(24,2,'1. / 2. alternate-ending brackets',[460,188,534,203])]

if __name__=='__main__':
 import json
 from pathlib import Path
 root=Path(__file__).resolve().parents[2]
 mpath=root/'Tests/full_scores/brahms-quartet-map.json';m=json.loads(mpath.read_text())
 m['sharedMarkings']=[{'pageIndex':p-1,'systemIndex':s-1,'text':text,'rect':rect,'anchorX':rect[0],'targetPartIDs':extra[0] if extra else ['violin2','viola','cello'],'reason':'Source-verified common tempo/navigation/rehearsal direction absent from the indicated lower staff crops. Copy this source fragment at its original horizontal alignment; do not cover target notation.','reviewStatus':'source_fragment_visually_verified'} for p,s,text,rect,*extra in QUARTET]
 mpath.write_text(json.dumps(m,indent=2,ensure_ascii=False)+'\n')

TRIO=[(1,1,'Allegro',[120,163,164,179]),(11,1,'rit.',[425,59,446,75]),(11,2,'Poco meno Allegro',[56,233,158,250]),(12,1,'Adagio',[97,53,138,71]),(18,1,'Andante grazioso',[108,53,204,72]),(25,3,'Un poco sostenuto',[143,416,240,434]),(26,1,'Allegro',[103,53,147,71])]
if __name__=='__main__':
 mpath=root/'Tests/full_scores/brahms-trio-map.json';m=json.loads(mpath.read_text())
 m['sharedMarkings']=[{'pageIndex':p-1,'systemIndex':s-1,'text':text,'rect':rect,'anchorX':rect[0],'targetPartIDs':['cello'],'reason':'Common tempo printed above Clarinet and Piano but absent above Cello. Copy this verified source fragment at original horizontal position without covering target notes.','reviewStatus':'source_fragment_visually_verified'} for p,s,text,rect in TRIO]
 mpath.write_text(json.dumps(m,indent=2,ensure_ascii=False)+'\n')
