"""Validate authored content without requiring the Flutter SDK.

This checks data contracts only. It does not execute Dart gameplay or widgets.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets" / "data"
cards = json.loads((DATA / "cards.json").read_text())
enemies = json.loads((DATA / "enemies.json").read_text())
balance = json.loads((DATA / "balance.json").read_text())
statuses = {"strength", "weak", "vulnerable", "burn", "poison", "chill", "shock", "regeneration"}


def check_effect(effect):
    assert effect["kind"] in {"damage", "block", "heal", "draw", "discard", "status"}
    assert isinstance(effect["amount"], int) and effect["amount"] >= 0
    assert effect["target"] in {"self", "enemy"}
    if effect["kind"] == "status":
        assert effect["status"] in statuses


ids = [card["id"] for card in cards]
assert len(ids) >= 20 and len(ids) == len(set(ids))
assert len(balance["startingDeck"]) == 12
assert set(balance["startingDeck"]) <= set(ids)
assert balance["maxHealth"] > 0 and balance["handLimit"] > 0
assert balance["energy"] >= 0 and balance["draw"] >= 0
for card in cards:
    assert isinstance(card["cost"], int) and card["cost"] >= 0
    assert card["type"] in {"attack", "defense", "skill", "spell", "utility", "curse"}
    assert card.get("rarity", "common") in {"common", "uncommon", "rare", "legendary"}
    assert set(card.get("keywords", [])) <= {"retain", "exhaust", "temporary"}
    assert card["name"] and card["description"] and card["art"]
    for effect in card["effects"]:
        check_effect(effect)
assert len({enemy["id"] for enemy in enemies}) == len(enemies)
assert sum(not enemy.get("boss", False) for enemy in enemies) >= 3
assert any(enemy.get("boss", False) for enemy in enemies)
for enemy in enemies:
    assert enemy["health"] > 0 and enemy["pattern"]
    for action in enemy["pattern"]:
        assert action["name"]
        for effect in action["effects"]:
            check_effect(effect)
manifest = (ROOT / "docs/art/ASSET_MANIFEST.md").read_text()
for card in cards:
    assert f'`{card["art"]}`' in manifest
for enemy in enemies:
    assert f'`enemies/{enemy["id"]}`' in manifest
for document in ("GAME_DESIGN.md", "ARCHITECTURE.md", "ROADMAP.md", "VALIDATION.md"):
    assert (ROOT / "docs" / document).is_file()
# The opening deck and entire enemy catalog must have real bundled art.
registry = dict(re.findall(r"'([^']+)': '([^']+)'", (ROOT / "lib/assets/asset_registry.dart").read_text()))
for card_id in set(balance["startingDeck"]):
    card = next(card for card in cards if card["id"] == card_id)
    assert card["art"] in registry, f"Missing starter art: {card_id}"
for enemy in enemies:
    assert f'enemies/{enemy["id"]}' in registry, f'Missing enemy art: {enemy["id"]}'
for logical_id, path in registry.items():
    asset = ROOT / path
    assert asset.is_file(), f"Missing bundled illustration: {logical_id}"
    assert asset.read_bytes().startswith(b"\x89PNG\r\n\x1a\n"), f"Invalid PNG: {logical_id}"
print(f"Content checks passed: {len(cards)} cards, {len(enemies)} enemies, 12-card deck, art references, documentation files.")
