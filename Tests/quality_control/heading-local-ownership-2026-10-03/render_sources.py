from pathlib import Path
import pymupdf as fitz,json,hashlib
out=Path('Tests/quality_control/heading-local-ownership-2026-10-03');cases=[
('mozart86903','sample_scores/medium_skewed/01_mozart_piano_quartet_k478_imslp_86903.pdf',[(1,[30,140,350,318]),(12,[20,34,340,195])]),
('schumann06822','sample_scores/medium_skewed/03_schumann_piano_quintet_op44_imslp_06822.pdf',[(2,[30,110,260,311]),(19,[28,455,260,675]),(26,[28,30,260,245])]),
('frauenliebe270922','sample_scores/lightly_skewed/05_schumann_frauenliebe_und_leben_op42_imslp_270922.pdf',[(1,[32,140,230,265]),(6,[240,155,400,291]),(15,[28,76,250,220])])]
rows=[]
for name,source,pages in cases:
 pdf=fitz.open(source)
 for n,b in pages:
  path=out/f'original-{name}-p{n:02}.png';pdf[n-1].get_pixmap(matrix=fitz.Matrix(3,3),clip=fitz.Rect(b),alpha=False).save(path)
  rows.append({'score':name,'source':source,'sourceSHA256':hashlib.sha256(Path(source).read_bytes()).hexdigest(),'page':n,'contextBounds':b,'image':str(path),'imageSHA256':hashlib.sha256(path.read_bytes()).hexdigest()})
(out/'original-images.json').write_text(json.dumps(rows,indent=2)+'\n')
