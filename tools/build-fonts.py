#!/usr/bin/env python3
"""Build NerdWorkbench from the vendored Topaz Unicode snapshot (fonttools 4.66.1)."""
from pathlib import Path
import hashlib
import json
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen
ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'assets/fonts/unicode'
OUT = ROOT / 'assets/fonts/nerdworkbench'
OUT.mkdir(exist_ok=True)

def rename(font, family, style):
    values = {1:family, 2:style, 3:family+' '+style+' 1.0', 4:family+' '+style,
              5:'Version 1.0', 6:(family+'-'+style).replace(' ',''),16:family,17:style,
              9:'Nerdibeard; derived from Topaz Unicode by Screwtape',
              13:'Derived from Topaz Unicode, distributed under its ISC license. See LICENSE.'}
    for key,value in values.items():
        font['name'].removeNames(nameID=key)
        font['name'].setName(value,key,3,1,0x409)
    font['head'].modified = 3863164800  # reproducible build epoch

for style in ['Regular','Bold']:
    source = SRC / ('topaz_unicode_ks13_'+style.lower()+'.ttf')
    for kind,ratio in [('Mono',1.5),('UI',1.75)]:
        f=TTFont(source, recalcTimestamp=False)
        # Defined 12x16 Mono and 14x16 UI cells, rather than per-widget scale transforms.
        if ratio != 1:
            f['glyf'].removeHinting()
            for name in f.getGlyphOrder():
                g=f['glyf'][name]
                if g.isComposite():
                    for component in g.components: component.x=round(component.x*ratio)
                elif g.numberOfContours>0:
                    for i,(x,y) in enumerate(g.coordinates): g.coordinates[i]=(round(x*ratio),y)
                width,lsb=f['hmtx'][name]
                f['hmtx'][name]=(round(width*ratio),round(lsb*ratio))
            f['hhea'].advanceWidthMax=round(f['hhea'].advanceWidthMax*ratio)
            f['OS/2'].xAvgCharWidth=round(f['OS/2'].xAvgCharWidth*ratio)
        # UI close mark: use the existing multiplication-sign outline.
        cmap=f.getBestCmap()
        if 0x2715 not in cmap:
            for table in f['cmap'].tables:
                if table.isUnicode(): table.cmap[0x2715]=cmap[0xD7]
        rename(f,'NerdWorkbench '+kind,style)
        f.save(OUT/('NerdWorkbench'+kind+'-'+style+'.ttf'))
(OUT/'LICENSE').write_bytes((SRC/'LICENSE').read_bytes())
# Original 8x8 pixel UI symbols; MIT, drawn here rather than copied from an icon font.
from fontTools.fontBuilder import FontBuilder
icons = {
  0xf011c: ['.######.','.#....#.','.#....#.','.#....#.','.#....#.','.#....#.','.#.##.#.','.######.'],
  0xf0928: ['........','.######.','##....##','..####..','.#....#.','...##...','...##...','........'],
  0xf099d: ['.######.','.#....#.','.#.##.#.','.#.##.#.','.#....#.','..#..#..','...##...','........'],
  0xf0570: ['........','.##..##.','.##..##.','........','.##..##.','.##..##.','........','........'],
  0xf00af: ['...#....','...##...','.#.#.#..','..###...','..###...','.#.#.#..','...##...','...#....'],
  0xf02cb: ['..####..','.#....#.','#......#','#......#','##....##','##....##','##....##','........'],
  0xf061a: ['..#.#...','.######.','##....##','.#.##.#.','##.##.##','.#....#.','.######.','...#.#..'],
  0xf0379: ['########','#......#','#......#','#......#','########','...##...','..####..','........'],
  0xf02b6: ['..###...','..#.#...','.#...#..','.#...#..','#.....#.','########','........','........'],
  0xf0597: ['...##...','.######.','########','########','........','.#.#.#..','..#.#.#.','........'],
  0xf03d7: ['...##...','.######.','.##..##.','##....##','##....##','.##..##.','.######.','...##...'],
  0xf0079: ['........','.######.','##....#.','##.##.#.','##.##.#.','##....#.','.######.','........'],
}
fb=FontBuilder(1600,isTTF=True)
order=['.notdef']+['icon'+hex(cp)[2:] for cp in icons]
fb.setupGlyphOrder(order)
glyphs={}
for name,rows in [('.notdef',['........']*8)]+[(order[i+1],r) for i,r in enumerate(icons.values())]:
 pen=TTGlyphPen(None)
 for y,row in enumerate(rows):
  for x,c in enumerate(row):
   if c=='#':
    left=x*200;bottom=1400-(y+1)*200
    pen.moveTo((left,bottom));pen.lineTo((left+200,bottom));pen.lineTo((left+200,bottom+200));pen.lineTo((left,bottom+200));pen.closePath()
 glyphs[name]=pen.glyph()
fb.setupCharacterMap({cp:order[i+1] for i,cp in enumerate(icons)})
fb.setupGlyf(glyphs)
fb.setupHorizontalMetrics({name:(1600,0) for name in order})
fb.setupHorizontalHeader(ascent=1400,descent=-200)
fb.setupOS2(sTypoAscender=1400,sTypoDescender=-200,usWinAscent=1400,usWinDescent=200)
fb.setupNameTable({'familyName':'NerdWorkbench Icons','styleName':'Regular','uniqueFontIdentifier':'NerdWorkbench Icons 1.0','fullName':'NerdWorkbench Icons','psName':'NerdWorkbenchIcons','version':'Version 1.0','licenseDescription':'MIT; original pixel drawings by Nerdibeard / OpenClaw.'})
fb.setupPost();fb.setupMaxp()
fb.font['head'].created=3863164800;fb.font['head'].modified=3863164800;fb.font.recalcTimestamp=False
fb.save(OUT/'NerdWorkbenchIcons.ttf')
manifest={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.glob('*.ttf'))}
(OUT/'SHA256.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
