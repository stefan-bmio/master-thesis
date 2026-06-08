import re, time, requests, pandas as pd
from bs4 import BeautifulSoup
from urllib.parse import urlencode, urljoin

BASE = "https://www.dhs.de/service/suchthilfeverzeichnis/"
PARAMS = {
    "x_wwdhseinrichtung2_fe1[action : list",
    "tx_wwdhseinrichtung2_fe1[angebot : 0",
    "tx_wwdhseinrichtung2_fe1[bland : 0",
    "tx_wwdhseinrichtung2_fe1[controller : Entry",
    "tx_wwdhseinrichtung2_fe1[do : search",
    "tx_wwdhseinrichtung2_fe1[plzort : ",
    "tx_wwdhseinrichtung2_fe1[spezi : 0",
    "tx_wwdhseinrichtung2_fe1[sprache : 0",
    "tx_wwdhseinrichtung2_fe1[umkreis : 0",
    "tx_wwdhseinrichtung2_fe1[zielgruppe : 1",
}

def text(x):
    return re.sub(r"\s+", " ", x).strip()

def parse(page):
    PARAMS["tx_wwdhseinrichtung2_fe1[entrys][currentPage]"] = page
    html = requests.get(BASE + "?" + urlencode(PARAMS), headers={"User-Agent": "Mozilla/5.0"}).text
    soup = BeautifulSoup(html, "html.parser")
    rows = []

    for a in soup.select("main a[href*='suchthilfeverzeichnis']"):
        box = a.find_parent(["li", "div", "article", "section"])
        if not box:
            continue

        lines = [text(x) for x in box.get_text("\n", strip=True).split("\n") if text(x)]
        plzort = next((x for x in lines if re.match(r"^\d{5}\s+", x)), "")
        mail = next((x for x in lines if re.search(r"@|\(at\)|\[at\]", x)), "")

        if plzort:
            i = lines.index(plzort)
            plz, stadt = plzort.split(" ", 1)
            rows.append({
                "Name der Einrichtung": text(a.get_text()),
                "Strasse mit Hausnummer": lines[i - 1] if i else "",
                "Postleitzahl": plz,
                "Stadt": stadt,
                "E-Mail-Adresse": mail.replace("(at)", "@").replace("[at]", "@"),
            })

    return rows

daten = []
for seite in range(1, 12):      # 158 Treffer, 15 pro Seite
    daten += parse(seite)
    time.sleep(0.5)

pd.DataFrame(daten).drop_duplicates().to_csv(
    "dhs_suchthilfeverzeichnis_export.csv",
    sep=";",
    index=False,
    encoding="utf-8-sig"
)
