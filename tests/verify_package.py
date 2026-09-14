"""Check exact data inputs, document links and the intended public file set."""
from pathlib import Path
import csv
import hashlib
import re
import struct
import zipfile
import json
from html.parser import HTMLParser

ROOT = Path(__file__).resolve().parents[1]
lock = json.loads((ROOT / 'renv.lock').read_text())
with (ROOT / 'outputs/tables/software-versions.csv').open() as f:
    for item in csv.DictReader(f):
        version = lock['R']['Version'] if item['package'] == 'R' else lock['Packages'][item['package']]['Version']
        assert version.replace('-', '.') == item['version'], item['package']
assert 'renv' in lock['Packages']
with (ROOT / 'docs/data-checksums.csv').open() as f:
    for item in csv.DictReader(f):
        path = ROOT / 'polish+companies+bankruptcy+data' / item['file']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == item['sha256'], path

excluded = {'.cache', '.git'}
public = [p for p in ROOT.rglob('*') if p.is_file() and not (set(p.relative_to(ROOT).parts) & excluded)]
for path in public:
    assert not path.is_symlink(), path
    assert not (set(path.relative_to(ROOT).parts) & {'.Rproj.user', '__MACOSX', '__pycache__'}), path
    assert path.name not in {'.DS_Store', '.Rhistory', '.RData', '.Ruserdata'} and not path.name.startswith(('._', '~$')) and path.suffix not in {'.zip', '.tmp', '.pyc'}, path
    if path.suffix in {'.md', '.R', '.csv', '.txt', '.Rproj', '.lock'} or path.name == '.gitignore':
        text = path.read_text()
        assert '/Users/' not in text and 'C:\\Users\\' not in text, path
    if path.suffix == '.md':
        for link in re.findall(r'!?\[[^\]]*\]\(([^)]+)\)', path.read_text()):
            if link.startswith(('https://', 'http://', '#', 'mailto:')):
                continue
            target = link.split('#')[0]
            assert (path.parent / target).exists(), (path, target)
    if path.suffix == '.csv':
        with path.open() as f:
            rows = list(csv.reader(f))
        assert len(rows) > 1 and all(len(r) == len(rows[0]) for r in rows), path
    if path.suffix == '.png':
        data = path.read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n'
        width, height = struct.unpack('>II', data[16:24])
        assert width >= 1000 and height >= 700, path
    if path.suffix == '.docx':
        with zipfile.ZipFile(path) as z:
            xml = z.read('word/document.xml').decode()
            assert '/Users/' not in xml, path
            assert 'Florien Siakoua Toukam' in xml, path

# Every entry point and report dependency must resolve inside the project.
entry = (ROOT / 'final_project.R').read_text()
for source in re.findall(r'source\("([^\"]+)"\)', entry):
    assert (ROOT / source).is_file(), source
for path in public:
    if path.suffix in {'.R', '.py'}:
        assert not re.search(r'(?:[A-Z]:\\\\Users\\\\|/Users/)[A-Za-z0-9_.-]+[/\\\\]', path.read_text()), path

class ReportLinks(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.targets = []

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if 'id' in values:
            self.ids.add(values['id'])
        for name in ('href', 'src'):
            if name in values:
                self.targets.append(values[name])

assert (ROOT / 'Final_Project_Report_Florien_Siakoua_Toukam.pdf').stat().st_size > 10000
assert (ROOT / 'reports/Bankruptcy_Risk_Executive_Summary.pdf').stat().st_size > 10000
html = (ROOT / 'reports/analysis-report.html').read_text()
assert html.count('src="data:image/png;base64,') == 3
assert not re.search(r'<script|src="https?://', html)
links = ReportLinks()
links.feed(html)
for target in links.targets:
    if target.startswith('#'):
        assert target[1:] in links.ids, target
    elif not target.startswith(('https://', 'http://', 'data:')):
        assert (ROOT / 'reports' / target).exists(), target
assert len(list((ROOT / 'outputs/tables').glob('*.csv'))) == 25
assert len(list((ROOT / 'outputs/figures').glob('*.png'))) == 11

print(f'Passed: exact input hashes, public naming, {len(public)} files, CSV structure, PNG headers, document content and relative links.')
