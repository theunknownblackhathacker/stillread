# tools/make_catalogs.py
# Builds the String Catalogs from tools/translations.py.
# Usage: python3 tools/make_catalogs.py

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from translations import APP, INFOPLIST, LANGS, PLURALS, SHARE  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def check_placeholders(key, value):
    want = sorted(re.findall(r"%(?:lld|@|lf|d)", key))
    got = sorted(re.findall(r"%(?:lld|@|lf|d)", value))
    if want != got:
        raise SystemExit(f"Placeholder mismatch in {key!r}: {value!r}")


def catalog(simple, plurals=None):
    strings = {}
    for key, values in sorted(simple.items()):
        if len(values) != len(LANGS):
            raise SystemExit(f"Wrong number of translations for {key!r}")
        localizations = {}
        for lang, value in zip(LANGS, values):
            check_placeholders(key, value)
            localizations[lang] = unit(value)
        strings[key] = {"localizations": localizations}

    for key, per_lang in sorted((plurals or {}).items()):
        localizations = {}
        for lang, forms in per_lang.items():
            for value in forms.values():
                check_placeholders(key, value)
            localizations[lang] = {
                "variations": {"plural": {category: unit(text) for category, text in forms.items()}}
            }
        strings[key] = {"localizations": localizations}

    return {"sourceLanguage": "en", "strings": strings, "version": "1.0"}


def write(path, data):
    full = os.path.join(ROOT, path)
    with open(full, "w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
    print(f"wrote {path}: {len(data['strings'])} keys")


write("Stillread/Localizable.xcstrings", catalog(APP, PLURALS))
write("Stillread/InfoPlist.xcstrings", catalog(INFOPLIST))
write("StillreadShare/Localizable.xcstrings", catalog(SHARE))
