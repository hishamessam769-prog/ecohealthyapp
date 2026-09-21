#!/usr/bin/env python3
"""Parse every delivery SQL file and enforce basic packaging safety checks."""

from pathlib import Path
import re
try:
    from pglast import parse_sql
except ImportError as error:
    raise SystemExit("Install test dependency first: python -m pip install -r requirements-test.txt") from error

ROOT = Path(__file__).resolve().parents[1]
FILES = sorted((ROOT / "supabase" / "migrations").glob("*.sql")) + [
    ROOT / "outputs" / "01_install_complete_database.sql",
    ROOT / "outputs" / "00_RESET_AND_INSTALL_COMPLETE_DATABASE.sql",
    ROOT / "outputs" / "02_install_demo_data.sql",
    ROOT / "outputs" / "03_remove_demo_data.sql",
]

for path in FILES:
    content = path.read_text(encoding="utf-8")
    parse_sql(content)
    lowered = content.lower()
    if re.search(r"(service_role_key|supabase_service_role_key)\s*=", lowered):
        raise SystemExit(f"Secret-like assignment found in {path}")

demo = (ROOT / "outputs" / "02_install_demo_data.sql").read_text(encoding="utf-8")
cleanup = (ROOT / "outputs" / "03_remove_demo_data.sql").read_text(encoding="utf-8")
if "is_demo" not in demo or "is_demo" not in cleanup:
    raise SystemExit("Demo installer and cleanup must both be guarded by is_demo.")

print(f"Parsed and safety-checked {len(FILES)} SQL files.")
