# Planet Far Away – Godot 4

A small 2D platformer prototype made in Godot 4, playable on itch.io.

---

## 🚀 Features

- Three small rooms  
- One enemy type with projectiles and basic chase / shoot / idle states (you can ride on its head!)  
- Menu and in-game music

---

## 🛠️ Technology

- Built with the Godot 4 engine using GDScript  
- Deployed on itch.io

---

## ⚠️ Known Issues

- The player can fall indefinitely if there are no tiles below

---

## 📌 Roadmap

- Add ability to control other playable characters  
- Add moving platforms  
- Add a “You finished the game” end state

---

## 💻 Running Locally

Not really possible. The repository intentionally does **not** include graphics or audio files.

---

## 🧪 Tests

Headless, no editor needed (run from the project folder):

```bash
godot --headless --path . -s res://tests/compile_all.gd
godot --headless --path . -s res://tests/playthrough.gd -- --testmode
godot --headless --path . -s res://tests/vault_export.gd
godot --headless --path . -s res://tests/standalone_level.gd -- --testmode
```

## ▶️ Playing any level

- In the editor: open a room and press **F6**.
- From the main menu: **Levels** (development builds only).
- From a terminal: `godot --path . -- --level=room4 --door=portal_2` (`--door` is optional).

Both exit with 0 when everything passes. The playthrough only uses the test save slot.

---

## 📖 Dialogues and encyclopedia

Written in the Obsidian vault (notes tagged `#in_game`), exported into `data/`:

```bash
godot --headless --path . -s res://tools/export_vault.gd
```

Format guide: the vault note `_how to write for the game`.
