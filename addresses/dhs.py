import re
import time
from urllib.parse import urlencode, urljoin

import requests
from bs4 import BeautifulSoup
import pandas as pd


BASE_URL = "https://www.dhs.de/service/suchthilfeverzeichnis/"

PARAMS = {
    "tx_wwdhseinrichtung2_fe1[action]": "list",
    "tx_wwdhseinrichtung2_fe1[angebot]": "0",
    "tx_wwdhseinrichtung2_fe1[bland]": "0",
    "tx_wwdhseinrichtung2_fe1[controller]": "Entry",
    "tx_wwdhseinrichtung2_fe1[do]": "search",
    "tx_wwdhseinrichtung2_fe1[plzort]": "",
    "tx_wwdhseinrichtung2_fe1[spezi]": "0",
    "tx_wwdhseinrichtung2_fe1[sprache]": "0",
    "tx_wwdhseinrichtung2_fe1[umkreis]": "0",
    "tx_wwdhseinrichtung2_fe1[zielgruppe]": "1",
}

HEADERS = {
    "User-Agent": "Mozilla/5.0"
}


def clean_text(value):
    if not value:
        return ""
    return re.sub(r"\s+", " ", value).strip()


def normalize_email(value):
    """
    DHS zeigt E-Mail-Adressen oft als name(at)domain.de an.
    """
    value = clean_text(value)
    value = value.replace("(at)", "@").replace("[at]", "@")
    value = value.replace(" at ", "@")
    return value


def split_postcode_city(line):
    """
    Erwartetes Format: '16227 Eberswalde'
    Gibt Postleitzahl und Stadt getrennt zurück.
    """
    line = clean_text(line)
    match = re.match(r"^(\d{5})\s+(.+)$", line)
    if match:
        return match.group(1), match.group(2)
    return "", line


def looks_like_email(line):
    return bool(
        re.search(r"\S+@\S+\.\S+", line)
        or re.search(r"\S+\(at\)\S+\.\S+", line, flags=re.IGNORECASE)
        or re.search(r"\S+\[at\]\S+\.\S+", line, flags=re.IGNORECASE)
    )


def parse_entries_from_page(html):
    soup = BeautifulSoup(html, "html.parser")

    rows = []

    # Ergebnis-Links erkennen: Detail-Links im Suchthilfeverzeichnis.
    # Wir filtern Navigation, Footer, externe Websites usw. später über die Textstruktur.
    links = soup.select("main a")

    for link in links:
        name = clean_text(link.get_text(" ", strip=True))
        href = link.get("href", "")

        if not name:
            continue

        # Nur potenzielle Treffer-Links behalten.
        # Die echten Einrichtungslinks liegen im DHS-Suchthilfeverzeichnis.
        absolute_href = urljoin(BASE_URL, href)
        if "suchthilfeverzeichnis" not in absolute_href:
            continue

        # Offensichtliche Nicht-Treffer überspringen.
        if name.lower() in {
            "zurück zur erweiterten suche",
            "nächste",
            "vorherige",
            "1", "2", "3", "4", "5",
        }:
            continue

        # Das umgebende Element enthält meistens Name, Straße, PLZ/Ort, Tel., E-Mail.
        container = link.find_parent(["li", "div", "article", "section"])
        if not container:
            continue

        lines = [
            clean_text(x)
            for x in container.get_text("\n", strip=True).split("\n")
            if clean_text(x)
        ]

        # Name sollte die Link-Beschriftung sein.
        # Danach suchen wir Straße, PLZ/Stadt und E-Mail.
        street = ""
        postcode = ""
        city = ""
        email = ""

        for i, line in enumerate(lines):
            # Straße ist meist die Zeile direkt vor der PLZ-Ort-Zeile.
            if re.match(r"^\d{5}\s+.+$", line):
                postcode, city = split_postcode_city(line)
                if i > 0:
                    street = lines[i - 1]
                break

        for line in lines:
            if looks_like_email(line):
                email = normalize_email(line)
                break

        # Nur echte Treffer übernehmen: Name + mindestens Adresse oder E-Mail.
        if name and (street or postcode or city or email):
            rows.append({
                "Name der Einrichtung": name,
                "Strasse mit Hausnummer": street,
                "Postleitzahl": postcode,
                "Stadt": city,
                "E-Mail-Adresse": email,
                "Detail-Link": absolute_href,
            })

    return rows


def get_total_pages(first_page_html):
    """
    Optional: Seitenzahl aus Trefferzahl berechnen.
    Fallback: 11 Seiten für die aktuelle Suche.
    """
    soup = BeautifulSoup(first_page_html, "html.parser")
    text = soup.get_text(" ", strip=True)

    match = re.search(
        r"(\d+)\s+Einträge\s+sind\s+gefunden\s+worden.*?Maximal\s+(\d+)\s+Einträge",
        text,
        flags=re.IGNORECASE
    )

    if match:
        total_entries = int(match.group(1))
        per_page = int(match.group(2))
        return (total_entries + per_page - 1) // per_page

    return 11


session = requests.Session()
session.headers.update(HEADERS)

all_rows = []

# Erste Seite abrufen, um die Seitenzahl zu bestimmen
first_url = BASE_URL + "?" + urlencode(PARAMS)
first_html = session.get(first_url, timeout=30).text
total_pages = get_total_pages(first_html)

print(f"Gefundene Seiten: {total_pages}")

for page in range(1, total_pages + 1):
    params = PARAMS.copy()
    params["tx_wwdhseinrichtung2_fe1[entrys][currentPage]"] = page

    url = BASE_URL + "?" + urlencode(params)
    print(f"Lese Seite {page}: {url}")

    html = first_html if page == 1 else session.get(url, timeout=30).text
    rows = parse_entries_from_page(html)
    all_rows.extend(rows)

    time.sleep(0.5)  # freundlich gegenüber dem Server


df = pd.DataFrame(all_rows)

# Dubletten entfernen, falls Link-/Container-Struktur mehrfach greift
df = df.drop_duplicates(
    subset=[
        "Name der Einrichtung",
        "Strasse mit Hausnummer",
        "Postleitzahl",
        "Stadt",
        "E-Mail-Adresse",
    ]
)

df.to_csv(
    "dhs_suchthilfeverzeichnis_export.csv",
    index=False,
    encoding="utf-8-sig",
    sep=";"
)

print(f"Exportiert: {len(df)} Einträge")
print("Datei: dhs_suchthilfeverzeichnis_export.csv")
