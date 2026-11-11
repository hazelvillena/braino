from pathlib import Path
import re, shutil
root=Path(__file__).resolve().parent.parent
out=root/'Braino.app/Contents/Resources/UI'
out.mkdir(parents=True,exist_ok=True)
html=(root/'preview/index.html').read_text().replace('href="/','href="./').replace('src="/','src="./')
html=html.replace('<script type="module" src="./app.mjs"></script>','<script src="./app.bundle.js"></script>')
(out/'index.html').write_text(html)
model=re.sub(r'\bexport ', '', (root/'preview/model.mjs').read_text())
app=(root/'preview/app.mjs').read_text().split('\n',1)[1]
(out/'app.bundle.js').write_text('(()=>{\n'+model+'\n'+app+'\n})();')
shutil.copy2(root/'preview/styles.css',out/'styles.css')
shutil.copy2(root/'Assets/BrainoGlyph.png',out/'icon.png')
