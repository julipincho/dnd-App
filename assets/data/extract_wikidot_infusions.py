import json
import re
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests
from bs4 import BeautifulSoup


URL = "https://dnd5e.wikidot.com/artificer:infusions"
OUTPUT_FILE = "artificer_infusions_2014_clean.json"


EXCLUDED_NAMES = {
    "Armor of Tools (UA)",
}

SOURCE = "TCE"
SOURCE_CLASS = "Artificer"
DEFAULT_LEVEL_REQUIREMENT = 2


def slugify(value: str) -> str:
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9\s_-]", "", value)
    value = re.sub(r"[\s-]+", "_", value)
    return value


def fetch_html(url: str) -> str:
    response = requests.get(
        url,
        headers={
            "User-Agent": "Mozilla/5.0",
        },
        timeout=30,
    )
    response.raise_for_status()
    return response.text


def clean_text(text: str) -> str:
    text = text.replace("\u2060", "")
    text = text.replace("\xa0", " ")
    text = re.sub(r"\s+", " ", text).strip()
    return text


def parse_level_requirement(text: str) -> Optional[int]:
    match = re.search(r"(\d+)(?:st|nd|rd|th)-level artificer", text, re.IGNORECASE)
    if match:
        return int(match.group(1))
    return None


def normalize_name(name: str) -> str:
    return clean_text(name).replace("### ", "").strip()


def infusion_modifiers(name: str) -> Dict[str, Any]:
    mapping: Dict[str, Dict[str, Any]] = {
        "Enhanced Arcane Focus": {"enhancedArcaneFocus": True},
        "Enhanced Defense": {"enhancedDefense": True},
        "Enhanced Weapon": {"enhancedWeapon": True},
        "Helm of Awareness": {
            "initiativeAdvantage": True,
            "cannotBeSurprisedWhileConscious": True,
        },
        "Mind Sharpener": {"mindSharpener": True},
        "Radiant Weapon": {"radiantWeapon": True},
        "Repeating Shot": {"repeatingShot": True},
        "Repulsion Shield": {"repulsionShield": True},
        "Resistant Armor": {"resistantArmor": True},
        "Returning Weapon": {"returningWeapon": True},
        "Spell-Refueling Ring": {"spellRefuelingRing": True},
        "Homunculus Servant": {"grantsHomunculusServant": True},
        "Arcane Propulsion Armor": {"arcanePropulsionArmor": True},
        "Armor of Magical Strength": {"armorOfMagicalStrength": True},
        "Boots of the Winding Path": {"bootsOfTheWindingPath": True},
        "Replicate Magic Item": {"replicateMagicItem": True},
    }
    return mapping.get(name, {"infusionType": slugify(name)})


def finalize_description(parts: List[str]) -> str:
    text = clean_text(" ".join(parts))
    return text


def parse_replicate_magic_item(lines: List[str]) -> Dict[str, Any]:
    replicate_tables: Dict[str, List[Dict[str, Any]]] = {}
    current_level: Optional[str] = None

    level_header_pattern = re.compile(
        r"Replicable Magic Items \((\d+)(?:st|nd|rd|th)-Level Artificer\)",
        re.IGNORECASE,
    )

    for raw_line in lines:
        line = clean_text(raw_line)
        if not line:
            continue

        level_match = level_header_pattern.match(line)
        if level_match:
            current_level = level_match.group(1)
            replicate_tables[current_level] = []
            continue

        if line == "Magic Item Attunement":
            continue

        if current_level is None:
            continue

        item_match = re.match(r"(.+?)\s+(Yes|No)$", line)
        if item_match:
            item_name = clean_text(item_match.group(1))
            attunement = item_match.group(2) == "Yes"
            replicate_tables[current_level].append(
                {
                    "name": item_name,
                    "requiresAttunement": attunement,
                }
            )

    return {"replicableItemsByLevel": replicate_tables}


def parse_infusions_from_lines(lines: List[str]) -> List[Dict[str, Any]]:
    infusions_map: Dict[str, Dict[str, Any]] = {}
    current_name: Optional[str] = None
    current_lines: List[str] = []

    known_names = {
        "Arcane Propulsion Armor",
        "Armor of Magical Strength",
        "Armor of Tools (UA)",
        "Boots of the Winding Path",
        "Enhanced Arcane Focus",
        "Enhanced Defense",
        "Enhanced Weapon",
        "Helm of Awareness",
        "Homunculus Servant",
        "Mind Sharpener",
        "Radiant Weapon",
        "Repeating Shot",
        "Replicate Magic Item",
        "Repulsion Shield",
        "Resistant Armor",
        "Returning Weapon",
        "Spell-Refueling Ring",
    }

    def flush_current() -> None:
        nonlocal current_name, current_lines

        if not current_name:
            return

        if not any(line.strip() for line in current_lines):
            current_name = None
            current_lines = []
            return

        name = normalize_name(current_name)

        if name in EXCLUDED_NAMES:
            current_name = None
            current_lines = []
            return

        level_requirement = DEFAULT_LEVEL_REQUIREMENT
        item_line: Optional[str] = None
        requires_attunement = False
        description_parts: List[str] = []
        extra_fields: Dict[str, Any] = {}

        for line in current_lines:
            if line.lower().startswith("prerequisite:"):
                parsed_level = parse_level_requirement(line)
                if parsed_level is not None:
                    level_requirement = parsed_level
                description_parts.append(line)
                continue

            if line.lower().startswith("item:"):
                item_line = line.removeprefix("Item:").strip()
                requires_attunement = "requires attunement" in item_line.lower()
                continue

            description_parts.append(line)

        if name == "Replicate Magic Item":
            extra_fields = {"replicableItemsRaw": " ".join(current_lines)}

        infusion = {
            "id": f"{slugify(name)}_{slugify(SOURCE)}",
            "name": name,
            "source": SOURCE,
            "sourceClass": SOURCE_CLASS,
            "levelRequirement": level_requirement,
            "prerequisites": [],
            "description": finalize_description(description_parts),
            "itemType": item_line,
            "requiresAttunement": requires_attunement,
            "modifiers": infusion_modifiers(name),
            "is2014Ruleset": True,
        }

        infusion.update(extra_fields)
        existing = infusions_map.get(name)

        # Nos quedamos con el que tenga descripción (el bueno)
        if not existing or (not existing["description"] and infusion["description"]):
            infusions_map[name] = infusion

        current_name = None
        current_lines = []

    heading_pattern = re.compile(r"^(?:###\s+)?(.+)$")

    for raw_line in lines:
        line = raw_line.rstrip()

        match = heading_pattern.match(line)
        if match:
            candidate = clean_text(match.group(1))

            if candidate in known_names:
                flush_current()
                current_name = candidate
                current_lines = []
                continue

        if current_name is not None:
            current_lines.append(line)

    flush_current()
    return list(infusions_map.values())


def extract_main_text_lines(html: str) -> List[str]:
    soup = BeautifulSoup(html, "html.parser")

    content = soup.select_one("#page-content")
    if content is None:
        raise ValueError("No pude encontrar #page-content en la página.")

    text = content.get_text("\n")
    lines = [line.strip() for line in text.splitlines() if line.strip()]

    # Intento 1: buscar el primer heading con ###
    for i, line in enumerate(lines):
        if line.startswith("### "):
            return lines[i:]

    # Intento 2: buscar el primer nombre de infusión conocido
    known_starts = {
        "Arcane Propulsion Armor",
        "Armor of Magical Strength",
        "Boots of the Winding Path",
        "Enhanced Arcane Focus",
        "Enhanced Defense",
        "Enhanced Weapon",
        "Helm of Awareness",
        "Homunculus Servant",
        "Mind Sharpener",
        "Radiant Weapon",
        "Repeating Shot",
        "Replicate Magic Item",
        "Repulsion Shield",
        "Resistant Armor",
        "Returning Weapon",
        "Spell-Refueling Ring",
    }

    for i, line in enumerate(lines):
        if line in known_starts:
            # si el heading vino sin ###, seguimos igual
            return lines[i:]

    # Debug útil si vuelve a fallar
    sample = "\n".join(lines[:80])
    raise ValueError(
        "No pude encontrar el inicio real de las infusiones.\n"
        f"Primeras líneas detectadas:\n{sample}"
    )


def main() -> None:
    html = fetch_html(URL)
    lines = extract_main_text_lines(html)
    infusions = parse_infusions_from_lines(lines)

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(infusions, f, ensure_ascii=False, indent=2)

    print(f"Archivo generado: {OUTPUT_FILE}")
    print(f"Infusions: {len(infusions)}")


if __name__ == "__main__":
    main()
