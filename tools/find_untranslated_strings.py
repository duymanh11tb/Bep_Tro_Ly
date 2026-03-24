import pathlib
import re

ROOT = pathlib.Path(r"D:\Bep_Tro_Ly")
EXTRACTED = ROOT / "tools" / "extracted_strings.txt"
LOCALIZATIONS = ROOT / "fridge_assistant" / "lib" / "core" / "localization" / "app_localizations.dart"


def load_translated_literals() -> set[str]:
    text = LOCALIZATIONS.read_text(encoding="utf-8")
    matches = re.findall(r"^\s*'((?:\\'|[^'])+)'\s*:\s*'((?:\\'|[^'])*)',?\s*$", text, re.MULTILINE)
    return {source.replace("\\'", "'") for source, _ in matches}


def should_flag(value: str) -> bool:
    stripped = value.strip()
    if not stripped:
        return False
    if any(char.isdigit() for char in stripped) and "$" in stripped:
        return False
    if stripped.startswith("http") or stripped.startswith("package:"):
        return False
    if stripped.lower() == stripped and all(ord(ch) < 128 for ch in stripped):
        return False
    return any("A" <= ch <= "Z" or "a" <= ch <= "z" or ord(ch) > 127 for ch in stripped)


def main() -> None:
    translated = load_translated_literals()
    seen: set[str] = set()
    missing: list[str] = []

    for line in EXTRACTED.read_text(encoding="utf-8").splitlines():
        try:
            _, value = line.split(" :: ", 1)
        except ValueError:
            continue
        if value in seen or value in translated or not should_flag(value):
            continue
        seen.add(value)
        missing.append(value)

    for value in missing:
        print(value)

    print(f"\nMissing literal count: {len(missing)}")


if __name__ == "__main__":
    main()
