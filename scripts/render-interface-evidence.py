#!/usr/bin/env python3
"""Render final production-build routes to PNG evidence without browser mocks."""

from pathlib import Path
import subprocess
import urllib.request

from weasyprint import CSS, HTML

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "outputs" / "screenshots"
OUT.mkdir(parents=True, exist_ok=True)
BASE = "http://127.0.0.1:3100"
POPPLER = "/Users/hishamessam/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/override/pdftoppm"

SCREENS = {
    "dashboard": "/dashboard",
    "users": "/admin/users",
    "roles": "/admin/roles",
    "projects": "/projects",
    "tasks": "/tasks",
    "leads": "/crm/leads",
    "customers": "/crm/customers",
    "sales": "/sales",
    "invoices": "/sales/invoices",
    "finance": "/finance/payments",
    "subscriptions": "/subscriptions",
    "subscriber-operations": "/operations/subscribers",
    "complaints": "/complaints",
    "doctors": "/doctors",
    "doctor-calendar": "/doctors/calendar",
    "doctor-sessions": "/doctors/sessions",
    "doctor-accounting": "/doctors/accounting",
    "notifications": "/notifications",
    "settings": "/settings",
}

SIZES = {
    "desktop": (1440, 1000),
    "mobile": (390, 844),
}

for slug, route in SCREENS.items():
    url = BASE + route
    with urllib.request.urlopen(url, timeout=20) as response:
        html = response.read().decode("utf-8")
    if response.status != 200 or "Eco Healthy" not in html:
        raise RuntimeError(f"Unexpected response for {route}: HTTP {response.status}")
    for form_factor, (width, height) in SIZES.items():
        pdf = OUT / f".{slug}-{form_factor}.pdf"
        target = OUT / f"{slug}-{form_factor}"
        css = CSS(string=f"@page {{ size: {width}px {height}px; margin: 0; }} html, body {{ width: {width}px; min-height: {height}px; margin: 0; }}")
        HTML(string=html, base_url=url).write_pdf(pdf, stylesheets=[css])
        subprocess.run(
            [POPPLER, "-f", "1", "-singlefile", "-png", "-r", "96", str(pdf), str(target)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        pdf.unlink()

print(f"Rendered {len(SCREENS) * len(SIZES)} final-build interface images to {OUT}")
