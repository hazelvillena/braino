"""Protect the single-source desktop/preview interface boundary."""
from pathlib import Path
root=Path(__file__).resolve().parent.parent
bundle=root/'Braino.app/Contents/Resources/UI'
assert (bundle/'styles.css').read_bytes()==(root/'preview/styles.css').read_bytes(), 'Desktop CSS drifted from preview'
html=(bundle/'index.html').read_text()
assert 'type="module"' not in html and './app.bundle.js' in html
assert 'src="/' not in html and 'href="/' not in html
script=(bundle/'app.bundle.js').read_text()
source=(root/'preview/app.mjs').read_text().split('\n',1)[1]
assert source in script, 'Desktop behavior drifted from preview'
assert script.startswith('(()=>{')
assert (bundle/'icon.png').read_bytes()==(root/'Assets/BrainoGlyph.png').read_bytes()
print('Shared UI parity checks passed: exact CSS/behavior, offline asset paths and glyph.')
