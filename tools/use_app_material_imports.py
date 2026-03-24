import pathlib

ROOT = pathlib.Path(r"D:\Bep_Tro_Ly\fridge_assistant\lib")
OLD = "import 'package:flutter/material.dart';"
NEW = "import 'package:fridge_assistant/core/localization/app_material.dart';"

for path in ROOT.rglob("*.dart"):
    if path.name == "app_material.dart":
        continue
    text = path.read_text(encoding="utf-8", errors="ignore")
    if OLD not in text:
        continue
    path.write_text(text.replace(OLD, NEW), encoding="utf-8")
