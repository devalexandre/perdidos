"""Build local review gallery and contact sheets from exported Blender previews."""
from pathlib import Path
import json, html
from PIL import Image, ImageDraw, ImageFont
HERE=Path(__file__).resolve().parent
cat=json.loads((HERE/'catalog.json').read_text())
regions=dict(pindorama='Terra de Pindorama',mouras='Reino das Mouras',sol='Ilhas do Sol Nascente',fiordes='Fiordes de Gelo',colunas='Costa das Colunas',areias='Areias do Nilo',brumas='Brumas Verdes',estepe='Estepe de Ferro',jade='Império de Jade',obsidiana='Selvas de Obsidiana')
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',15)
page=['<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Novos monstros regionais</title><style>body{background:#171c27;color:#edf0f4;font:16px system-ui;max-width:1200px;margin:auto;padding:24px}h1{font-size:30px}nav{display:flex;flex-wrap:wrap;gap:14px}a{color:#83d6c8}.forms{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}img{width:100%;border-radius:12px}figure{margin:0}article{margin:30px 0 46px}figcaption{padding:8px}small,p{color:#bac4d4}@media(max-width:650px){.forms{grid-template-columns:1fr}}</style><h1>30 novos monstros regionais</h1><p>Modelos Blender editáveis · Normal, Boss e Atroz · Arte preparada, sem spawns ativos.</p><p>As prévias mostram a modelagem 3D. Os sprites pixel art são produzidos pelo renderizador nativo quando necessário. Escala das imagens ajustada para revisão de detalhes.</p><nav>']
page += [f'<a href="#{key}">{name}</a>' for key,name in regions.items()]
page+=['</nav>']
manifest=[]
for region,rows in cat.items():
 page.append(f'<section id="{region}"><h2>{regions[region]}</h2>')
 board=Image.new('RGB',(960,1040),(25,30,41)); draw=ImageDraw.Draw(board)
 draw.text((12,10),regions[region]+' | Normal / Boss / Atroz',font=font,fill='white')
 for ri,row in enumerate(rows):
  mid=row[0]
  page.append(f'<article><h3>{row[1]}</h3><p>{html.escape(row[7])}</p><div class="forms">')
  for col,stage in enumerate((1,3,4)):
   file=f'{mid}_s{stage}'
   im=Image.open(HERE/'previews'/f'{file}.png').convert('RGB')
   assert im.size==(384,384)
   board.paste(im.resize((320,300)),(col*320,40+ri*330))
   draw.text((col*320+8,340+ri*330),row[col+1],font=font,fill='white')
   blend=HERE.parent/'blend'/f'{file}.blend'
   assert blend.stat().st_size>10000
   label=('Normal','Boss','Atroz')[col]
   page.append(f'<figure><a href="../blend/{file}.blend"><img loading="lazy" src="previews/{file}.png" alt="{html.escape(row[col+1])}"></a><figcaption><strong>{label}</strong> · {row[col+1]}<br><a href="../blend/{file}.blend">Abrir modelo .blend</a></figcaption></figure>')
   manifest.append(dict(id=mid,region=region,name=row[col+1],stage=stage,blend=f'blend/{file}.blend',runtime_enabled=False))
  page.append('</div></article>')
 board.save(HERE/f'{region}.jpg',quality=90)
 page.append('</section>')
page.append('</html>')
(HERE/'index.html').write_text('\n'.join(page))
(HERE/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
assert len(manifest)==90
print('Validated: 30 species, 90 .blend files, 90 previews, 10 regional boards.')
