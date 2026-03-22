import pathlib
import re

ROOT = pathlib.Path(r"D:\Bep_Tro_Ly\fridge_assistant\lib")
OUTPUT = pathlib.Path(r"D:\Bep_Tro_Ly\tools\extracted_strings.txt")

string_pattern = re.compile(
    r"""(?P<quote>['"])(?P<content>(?:\\.|(?!\1).)*)\1""",
    re.DOTALL,
)


def looks_user_facing(text: str) -> bool:
    if not text:
        return False
    if len(text) == 1 and text.isalpha():
        return False
    stripped = text.strip()
    lower = stripped.lower()
    if lower.startswith('package:') or lower.startswith('../') or lower.startswith('./'):
        return False
    if lower.startswith('/api/') or lower.startswith('http') or lower.startswith('assets/'):
        return False
    if '.dart' in lower or '.png' in lower or '.jpg' in lower or '.jpeg' in lower or '.svg' in lower:
        return False
    if '/' in stripped and ' ' not in stripped:
        return False
    if re.fullmatch(r'[a-z0-9_.$:-]+', stripped):
        return False
    if re.fullmatch(r'[A-Z0-9_.$:-]+', stripped):
        return False
    if stripped.startswith(r'\s'):
        return False
    if any(token in text for token in ['{', '}', '=>', 'Widget', 'Color(', 'Icons.', 'Route', 'fridgeId']):
        return False
    return any(ch.isalpha() for ch in stripped)


rows = []

for path in ROOT.rglob("*.dart"):
    text = path.read_text(encoding="utf-8", errors="ignore")
    for match in string_pattern.finditer(text):
        content = match.group("content")
        if looks_user_facing(content):
            rows.append((str(path), content.replace("\\n", " ").strip()))

seen = set()
unique_rows = []
for row in rows:
    if row[1] in seen:
        continue
    seen.add(row[1])
    unique_rows.append(row)

with OUTPUT.open("w", encoding="utf-8") as handle:
    for path, content in unique_rows:
        handle.write(f"{path} :: {content}\n")
