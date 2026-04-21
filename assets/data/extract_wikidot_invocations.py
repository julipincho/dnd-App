import json
import re
import sys
import unicodedata
from pathlib import Path

from bs4 import BeautifulSoup


INPUT_HTML = "Eldritch Invocations - D&D 5th Edition.html"
OUTPUT_JSON = "eldritch_invocations_2014_clean.json"

INVOCATION_TITLES = [
    "Agonizing Blast",
    "Armor of Shadows",
    "Ascendant Step",
    "Aspect of the Moon",
    "Beast Speech",
    "Beguiling Influence",
    "Bewitching Whispers",
    "Book of Ancient Secrets",
    "Chains of Carceri",
    "Cloak of Flies",
    "Devil's Sight",
    "Dreadful Word",
    "Eldritch Sight",
    "Eldritch Smite",
    "Eldritch Spear",
    "Eyes of the Rune Keeper",
    "Fiendish Vigor",
    "Gaze of Two Minds",
    "Ghostly Gaze",
    "Gift of the Depths",
    "Gift of the Ever-Living Ones",
    "Grasp of Hadar",
    "Improved Pact Weapon",
    "Lance of Lethargy",
    "Lifedrinker",
    "Maddening Hex",
    "Mask of Many Faces",
    "Master of Myriad Forms",
    "Minions of Chaos",
    "Mire the Mind",
    "Misty Visions",
    "One with Shadows",
    "Otherworldly Leap",
    "Relentless Hex",
    "Repelling Blast",
    "Sculptor of Flesh",
    "Shroud of Shadow",
    "Sign of Ill Omen",
    "Superior Pact Weapon (UA)",
    "Thief of Five Fates",
    "Thirsting Blade",
    "Tomb of Levistus",
    "Trickster's Escape",
    "Ultimate Pact Weapon (UA)",
    "Visions of Distant Realms",
    "Voice of the Chain Master",
    "Whispers of the Grave",
    "Witch Sight",
]

TITLE_SET = set(INVOCATION_TITLES)


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

    # Fuerza saltos antes y después de títulos conocidos,
    # por si el HTML vino aplastado.
    for title in sorted(INVOCATION_TITLES, key=len, reverse=True):
        raw = raw.replace(title, f"\n{title}\n")

    # También ayudamos a separar los prerrequisitos.
    raw = raw.replace("Prerequisite:", "\nPrerequisite: ")

    raw = re.sub(r"\n{2,}", "\n", raw)

    lines = []
    for line in raw.split("\n"):
        line = clean_text(line)
        if line:
            lines.append(line)

    return lines


def find_real_content_start(lines: list[str]) -> int:
    first_title = INVOCATION_TITLES[0]  # Agonizing Blast

    exact_matches = []
    for i, line in enumerate(lines):
        if line.strip() == first_title:
            exact_matches.append(i)

    # Lo ideal: una aparición en TOC y otra en contenido real
    if len(exact_matches) >= 2:
        return exact_matches[1]

    fuzzy_matches = []
    for i, line in enumerate(lines):
        normalized = re.sub(r"\s+", " ", line).strip()
        if first_title in normalized:
            fuzzy_matches.append(i)

    if len(fuzzy_matches) >= 2:
        return fuzzy_matches[1]

    if len(exact_matches) == 1:
        return exact_matches[0]

    if len(fuzzy_matches) == 1:
        return fuzzy_matches[0]

    raise ValueError("No pude encontrar una aparición usable de 'Agonizing Blast'.")


def parse_prerequisite_and_description(body_lines: list[str]) -> tuple[str | None, str]:
    prereq_parts = []
    desc_parts = []

    skip_next_if_spell = False

    for i, line in enumerate(body_lines):
        normalized = clean_text(line)

        if normalized.startswith("Prerequisite:"):
            value = normalized[len("Prerequisite:") :].strip()
            if value:
                prereq_parts.append(value)
            continue

        # 🔥 limpiar fragmentación de spells
        if normalized.lower() == "cantrip":
            continue

        # evitar líneas sueltas tipo "Eldritch Blast"
        if i + 1 < len(body_lines):
            next_line = clean_text(body_lines[i + 1]).lower()
            if next_line == "cantrip":
                continue

        desc_parts.append(normalized)

    description = " ".join(desc_parts)

    # limpieza final
    description = re.sub(r"\s+", " ", description).strip()

    prerequisite = "; ".join(prereq_parts) if prereq_parts else None

    return prerequisite, description


def parse_invocations(lines: list[str]) -> list[dict]:
    start_idx = find_real_content_start(lines)
    lines = lines[start_idx:]

    entries = []
    current_title = None
    current_body = []

    for line in lines:
        normalized_line = re.sub(r"\s+", " ", line).strip()

        if normalized_line in TITLE_SET:
            if current_title is not None:
                prereq, desc = parse_prerequisite_and_description(current_body)
                entries.append(
                    {
                        "id": f"{slugify(current_title)}_invocation_2014",
                        "name": current_title,
                        "source": "PHB 2014",
                        "type": "eldritch_invocation",
                        "prerequisite": prereq,
                        "description": desc,
                    }
                )

            current_title = normalized_line
            current_body = []
        else:
            if current_title is not None:
                current_body.append(normalized_line)

    if current_title is not None:
        prereq, desc = parse_prerequisite_and_description(current_body)
        entries.append(
            {
                "id": f"{slugify(current_title)}_invocation_2014",
                "name": current_title,
                "source": "PHB 2014",
                "type": "eldritch_invocation",
                "prerequisite": prereq,
                "description": desc,
            }
        )

    by_name = {entry["name"]: entry for entry in entries}
    ordered = []

    for title in INVOCATION_TITLES:
        if title in by_name:
            ordered.append(by_name[title])
        else:
            ordered.append(
                {
                    "id": f"{slugify(title)}_invocation_2014",
                    "name": title,
                    "source": "PHB 2014",
                    "type": "eldritch_invocation",
                    "prerequisite": None,
                    "description": "",
                }
            )

    return ordered


def main():
    input_path = sys.argv[1] if len(sys.argv) > 1 else INPUT_HTML
    output_path = sys.argv[2] if len(sys.argv) > 2 else OUTPUT_JSON

    html = load_html(input_path)
    lines = extract_lines_from_html(html)

    # Debug opcional:
    # print("PRIMERAS 120 LÍNEAS:")
    # for i, line in enumerate(lines[:120]):
    #     print(f"{i:03}: {repr(line)}")

    entries = parse_invocations(lines)

    Path(output_path).write_text(
        json.dumps(entries, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    print(f"OK. Generé {len(entries)} invocaciones en {output_path}")


if __name__ == "__main__":
    main()
