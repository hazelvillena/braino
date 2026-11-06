#!/bin/zsh
set -eu
cd "${0:A:h}/.."
node --check preview/app.mjs
node --test tests/model.test.mjs
mkdir -p .cache/native-tests .cache/modules
python3 - <<'PY'
from pathlib import Path
source = Path('Sources/Braino.swift').read_text().split('// Braino design tokens:')[0]
Path('.cache/native-tests/main.swift').write_text(source + '\n' + Path('tests/native.swift').read_text())
PY
swiftc -target arm64-apple-macos14.0 -swift-version 5 -module-cache-path "$PWD/.cache/modules" .cache/native-tests/main.swift -o .cache/native-tests/check
.cache/native-tests/check "$PWD/.cache/native-tests/tasks.json"
