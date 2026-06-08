import re, time, pandas as pd
from playwright.sync_api import sync_playwright

URL = "https://suchtindex.infodrog.ch/#/?offerings=50,34,41,48&specializations=9&view=list"

def clean(x): return re.sub(r"\s+", " ", x or "").strip()
def email(x): return next(iter(re.findall(r"[\w.+-]+@[\w.-]+\.\w+", x)), "")
def addr(x):
    m = re.search(r"(.+?),\s*(\d{4})\s+([^,\n]+)", x)
    return m.groups() if m else ("", "", "")

def read_cards(page):
    page.wait_for_selector("text=Details für", timeout=30000)
    return page.locator("a", has_text=re.compile("Details für")).evaluate_all("""
    links => links.map(a => {
        let e = a.closest('li, article, section, div');
        while (e && e.innerText.length < 80) e = e.parentElement;
        return e ? e.innerText : '';
    })
    """)

rows, seen_pages = [], set()

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    page.goto(URL, wait_until="networkidle")

    while True:
        time.sleep(1)

        for card in dict.fromkeys(map(clean, read_cards(page))):
            lines = [clean(x) for x in card.split("\n") if clean(x)]
            name = next(
                (
                    re.sub(r"^Details für «|» anzeigen$", "", x)
                    for x in lines
                    if x.startswith("Details für")
                ),
                lines[0] if lines else ""
            )
            street, plz, city = addr(card)

            rows.append({
                "Name der Einrichtung": name,
                "Strasse mit Hausnummer": street,
                "Postleitzahl": plz,
                "Stadt": city,
                "E-Mail-Adresse": email(card)
            })

        old_cards = clean("\n".join(read_cards(page)))
        controls = page.locator(
            "li.PaginationControl:has(path[d='M8.59 16.58L13.17 12 8.59 7.41 10 6l6 6-6 6-1.41-1.42z'])"
        )

        if controls.count() == 0:
            break

        next_button = controls.last
        next_button.click()

        try:
            page.wait_for_function(
                """old => {
                    const txt = [...document.querySelectorAll('a')]
                      .filter(a => a.innerText.includes('Details für'))
                      .map(a => a.closest('li, article, section, div')?.innerText || '')
                      .join('\\n');
                    return txt.trim() !== old.trim();
                }""",
                old_cards,
                timeout=30000
            )
        except:
            break

    browser.close()

pd.DataFrame(rows).drop_duplicates().to_csv(
    "infodrog_suchtindex_export.csv",
    sep=";",
    index=False,
    encoding="utf-8-sig"
)

print(f"Exportiert: {len(pd.DataFrame(rows).drop_duplicates())} Einträge")
