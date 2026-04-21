import json
import re
import sys
import unicodedata
from pathlib import Path

from bs4 import BeautifulSoup


INPUT_HTML = "Battle Master Maneuvers - DND 5th Edition.html"
OUTPUT_JSON = "maneuvers_2014_clean.json"

MANEUVER_TITLES = [
    "Ambush",
    "Bait and Switch",
    "Brace",
    "Commander's Strike",
    "Commanding Presence",
    "Disarming Attack",
    "Distracting Strike",
    "Evasive Footwork",
    "Feinting Attack",
    "Goading Attack",
    "Grappling Strike",
    "Lunging Attack",
    "Maneuvering Attack",
    "Menacing Attack",
    "Parry",
    "Precision Attack",
    "Pushing Attack",
    "Quick Toss",
    "Rally",
    "Riposte",
    "Sweeping Attack",
    "Tactical Assessment",
    "Trip Attack",
]

TITLE_SET = set(MANEUVER_TITLES)


def load_html(path: str) -> str:
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"No encontré el archivo: {path}")
    return p.read_text(encoding="utf-8", errors="ignore")


def slugify(text: str) -> str:
    text = unicodedata.normalize("NFKD", text)
    text = text.encode("ascii", "ignore").decode("ascii")
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "_", text)
    text = re.sub(r"_+", "_", text).strip("_")
    return text


def clean_text(text: str) -> str:
    text = text.replace("\xa0", " ")
    text = text.replace("’", "'").replace("“", '"').replace("”", '"')
    text = re.sub(r"\r", "\n", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def extract_lines_from_html(html: str) -> list[str]:
    soup = BeautifulSoup(html, "html.parser")

    for tag in soup(["script", "style", "noscript"]):
        tag.decompose()

    for br in soup.find_all("br"):
        br.replace_with("\n")

    content = None
    for cid in ["page-content", "main-content", "content-wrap", "wikidot-content"]:
        content = soup.find(id=cid)
        if content:
            break

    if content is None:
        content = soup.body or soup

    raw = content.get_text("\n", strip=True)
    raw = clean_text(raw)

    # Forzar saltos antes de encabezados reales "## Title" que al exportar
    # suelen quedar como líneas normales tipo "Ambush".
    for title in sorted(MANEUVER_TITLES, key=len, reverse=True):
        raw = raw.replace(title, f"\n{title}\n")

    raw = re.sub(r"\n{2,}", "\n", raw)

    lines = []
    for line in raw.split("\n"):
        line = clean_text(line)
        if line:
            lines.append(line)

    return lines


def find_real_content_start(lines: list[str]) -> int:
    first_title = MANEUVER_TITLES[0]  # Ambush

    exact_matches = [i for i, line in enumerate(lines) if line == first_title]
    if len(exact_matches) >= 2:
        return exact_matches[1]

    fuzzy_matches = [i for i, line in enumerate(lines) if first_title in line]
    if len(fuzzy_matches) >= 2:
        return fuzzy_matches[1]

    if len(exact_matches) == 1:
        return exact_matches[0]

    if len(fuzzy_matches) == 1:
        return fuzzy_matches[0]

    raise ValueError("No pude encontrar una aparición usable de 'Ambush'.")


def is_noise_line(line: str) -> bool:
    low = line.lower().strip()

    if low in {
        "battle master maneuvers",
        "fold unfold",
        "table of contents",
        "home",
        "site manager",
        "page tags",
        "edit",
        "print",
        "source",
        "share",
        "rate",
        "discuss",
        "more options",
        "create account",
        "sign in",
        "login",
        "breadcrumbs",
    }:
        return True

    if low.startswith("help | terms of service"):
        return True
    if low.startswith("powered by"):
        return True
    if low.startswith("unless otherwise stated"):
        return True
    if low.startswith("click here to edit"):
        return True
    if low.startswith("append content without editing"):
        return True
    if low.startswith("check out how this page has evolved"):
        return True
    if low.startswith("view and manage file attachments"):
        return True
    if low.startswith("a few useful tools to manage this site"):
        return True
    if low.startswith("see pages that link to and include this page"):
        return True
    if low.startswith("change the name"):
        return True
    if low.startswith("view wiki source for this page"):
        return True
    if low.startswith("view/set parent page"):
        return True
    if low.startswith("notify administrators"):
        return True
    if low.startswith("something does not work as expected"):
        return True
    if low.startswith("general wikidot.com documentation"):
        return True
    if low.startswith("wikidot.com terms of service"):
        return True
    if low.startswith("wikidot.com privacy policy"):
        return True

    return False


def parse_maneuvers(lines: list[str]) -> list[dict]:
    start_idx = find_real_content_start(lines)
    lines = [line for line in lines[start_idx:] if not is_noise_line(line)]

    entries = []
    current_title = None
    current_body: list[str] = []

    for line in lines:
        normalized = re.sub(r"\s+", " ", line).strip()

        if normalized in TITLE_SET:
            if current_title is not None:
                description = "\n".join(x for x in current_body if x).strip()
                entries.append(
                    {
                        "id": f"{slugify(current_title)}_maneuver_2014",
                        "name": current_title,
                        "source": "PHB 2014",
                        "type": "maneuver",
                        "description": description,
                    }
                )

            current_title = normalized
            current_body = []
        else:
            if current_title is not None:
                current_body.append(normalized)

    if current_title is not None:
        description = "\n".join(x for x in current_body if x).strip()
        entries.append(
            {
                "id": f"{slugify(current_title)}_maneuver_2014",
                "name": current_title,
                "source": "PHB 2014",
                "type": "maneuver",
                "description": description,
            }
        )

    # Mantener orden canónico y asegurar presencia de todas
    by_name = {entry["name"]: entry for entry in entries}
    ordered = []

    for title in MANEUVER_TITLES:
        if title in by_name:
            ordered.append(by_name[title])
        else:
            ordered.append(
                {
                    "id": f"{slugify(title)}_maneuver_2014",
                    "name": title,
                    "source": "PHB 2014",
                    "type": "maneuver",
                    "description": "",
                }
            )

    return ordered


def post_clean_maneuver(entry: dict) -> dict:
    desc = clean_text(entry.get("description", ""))
    desc = re.sub(r"\n([a-z])", r" \1", desc)
    desc = desc.replace("\nPlayer's Handbook\n", " Player's Handbook ")
    # Compactar demasiado salto de línea, pero conservar párrafos.
    desc = re.sub(r"\n{3,}", "\n\n", desc).strip()

    entry["description"] = desc
    return entry


def main() -> None:
    input_path = sys.argv[1] if len(sys.argv) > 1 else INPUT_HTML
    output_path = sys.argv[2] if len(sys.argv) > 2 else OUTPUT_JSON

    html = load_html(input_path)
    lines = extract_lines_from_html(html)

    # Debug opcional
    # print("PRIMERAS 120 LÍNEAS:")
    # for i, line in enumerate(lines[:120]):
    #     print(f"{i:03}: {repr(line)}")

    maneuvers = parse_maneuvers(lines)
    maneuvers = [post_clean_maneuver(x) for x in maneuvers]

    Path(output_path).write_text(
        json.dumps(maneuvers, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    print(f"OK. Generé {len(maneuvers)} maniobras en {output_path}")


if __name__ == "__main__":
    main()
