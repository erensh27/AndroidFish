# BUILD.md — Lichess Bot (Moto G32 / Termux / BotLi)

## Project Overview

Build a public GitHub repository that wraps [BotLi](https://github.com/Torom/BotLi) with:
- An interactive startup script (`start.sh`) that prompts for Threads, Hash, and Lichess token every run
- A pre-configured `config.yml` baked for 1-game-at-a-time, all time controls, all variants, all modes, matchmaking every 5 minutes, online EGTB disabled, local opening books enabled
- A clean terminal UI that shows login confirmation, game logs, book move hits, and matchmaking pings
- Fairy-Stockfish for variants alongside standard Stockfish
- Termux-optimized setup (no systemd, no Docker, no root)

---

## Repository Structure

```
repo-root/
├── BUILD.md                  ← this file
├── README.md                 ← user-facing setup guide
├── start.sh                  ← interactive launcher (prompts token, threads, hash)
├── config.yml.template       ← config template with __TOKEN__ __THREADS__ __HASH__ placeholders
├── engines/
│   └── .gitkeep              ← engines go here (not committed), documented in README
├── books/
│   └── .gitkeep              ← user drops .bin polyglot books here
└── scripts/
    ├── setup_termux.sh       ← one-time Termux dependency installer
    └── download_engines.sh   ← downloads SF + Fairy-SF Android ARM64 binaries
```

---

## File Specifications

### `start.sh`

This is the ONLY entry point. User runs `bash start.sh` every time.

**Behavior (in order):**

1. Print ASCII banner: `=== Lichess Bot — Moto G32 ===`
2. Prompt: `Lichess Bot Token:` (read silently with `read -s`, no echo)
3. Prompt: `Stockfish Threads [recommended: 6]:` — default 6 if empty
4. Prompt: `Hash size in MB [recommended: 512]:` — default 512 if empty
5. Validate:
   - Token must be non-empty
   - Threads must be integer 1–8
   - Hash must be integer 64–2048
   - If any fail, print error and re-prompt (loop, don't exit)
6. Copy `config.yml.template` → `config.yml`, substitute `__TOKEN__`, `__THREADS__`, `__HASH__` using `sed`
7. Check `engines/stockfish` exists and is executable — if not, print error and suggest running `bash scripts/download_engines.sh`, then exit
8. Check `engines/fairy-stockfish` exists — same check
9. Check `books/` directory has at least one `.bin` file — if empty, warn (not fatal): `WARNING: No .bin books found in books/ — book moves will be skipped`
10. Detect username by calling Lichess API: `curl -s -H "Authorization: Bearer __TOKEN__" https://lichess.org/api/account` — parse `.username` with `python3 -c "import sys,json; print(json.load(sys.stdin)['username'])"`
11. Print: `✓ Logged in as: <USERNAME>`
12. Print: `✓ Threads: <N>  Hash: <N>MB  Games: 1 at a time`
13. Print: `✓ Accepting: ALL time controls · ALL variants · rated + casual`
14. Print: `✓ Matchmaking: every 5 minutes`
15. Print: `✓ Online EGTB: DISABLED  |  Local books: ENABLED`
16. Print: `Starting BotLi... (Ctrl+C to stop)`
17. `cd` into the BotLi directory and run: `uv run user_interface.py matchmaking`
    - BotLi must be cloned at `./BotLi/` relative to repo root
    - Pass the generated `config.yml` via BotLi's expected location (`BotLi/config.yml`)

**Notes:**
- Copy the generated `config.yml` into `BotLi/config.yml` before launching
- All output after step 16 is raw BotLi stdout/stderr — do not suppress it
- Add a trap on EXIT to print `Bot stopped.`

---

### `config.yml.template`

Base: upstream `config.yml.default` from `https://github.com/Torom/BotLi/blob/main/config.yml.default`

**Substitution placeholders (replaced by start.sh at runtime):**
- `__TOKEN__` → Lichess OAuth token
- `__THREADS__` → integer from prompt
- `__HASH__` → integer from prompt

**Required config values (hardcode these, not placeholders):**

```yaml
token: "__TOKEN__"

engines:
  standard:
    dir: "../engines"
    name: "stockfish"
    ponder: true
    silence_stderr: false
    move_overhead_multiplier: 1.0
    uci_options:
      Threads: __THREADS__
      Hash: __HASH__
      Move Overhead: 100

  variants:
    dir: "../engines"
    name: "fairy-stockfish"
    ponder: true
    silence_stderr: false
    move_overhead_multiplier: 1.0
    uci_options:
      Threads: __THREADS__
      Hash: __HASH__
      Move Overhead: 100
      EvalFile: "3check-cb5f517c228b.nnue:antichess-dd3cbe53cd4e.nnue:atomic-2cf13ff256cc.nnue:crazyhouse-8ebf84784ad2.nnue:horde-28173ddccabe.nnue:kingofthehill-978b86d0e6a4.nnue:racingkings-636b95f085e3.nnue"
```

**Online moves — ALL disabled:**
```yaml
online_moves:
  opening_explorer:
    enabled: false
  lichess_cloud:
    enabled: false
  chessdb:
    enabled: false

online_egtb:
  enabled: false
```

**Opening books — ENABLED:**
```yaml
opening_books:
  enabled: true
  priority: 400
  books:
    standard:
      selection: weighted_random
      names:
        - Book1
        # start.sh will not dynamically add books here;
        # user must manually list their book names here in the template
        # and drop the .bin files in books/

# At the bottom of the file:
books:
  Book1: "../books/YOUR_BOOK.bin"
  # Add more entries here matching whatever .bin files user provides
```

**NOTE for coding agent:** The `books:` section at the bottom and `opening_books: books:` section must be kept in sync. Document this clearly. Do not auto-detect books at runtime — user edits the template directly.

**Challenge settings — accept everything:**
```yaml
challenge:
  concurrency: 1
  max_takebacks: 3

  H:
    bullet_with_increment_only: false
    variants:
      - standard
      - chess960
      - fromPosition
      - antichess
      - atomic
      - crazyhouse
      - horde
      - kingOfTheHill
      - racingKings
      - threeCheck
    time_controls:
      - bullet
      - blitz
      - rapid
      - classical
    modes:
      - casual
      - rated

  bot:
    bullet_with_increment_only: false
    variants:
      - standard
      - chess960
      - fromPosition
      - antichess
      - atomic
      - crazyhouse
      - horde
      - kingOfTheHill
      - racingKings
      - threeCheck
    time_controls:
      - bullet
      - blitz
      - rapid
      - classical
    modes:
      - casual
      - rated
```

**Matchmaking — every 5 minutes:**

Calculate delay using BotLi's recommended formula: `delay = 864 - 1.34 * initial_time - 91.76 * increment`

For 3+2 blitz: `864 - 1.34*180 - 91.76*2 = 864 - 241.2 - 183.52 ≈ 439`

Use 300 seconds (5 minutes) as the explicit delay to match the user's requirement:

```yaml
matchmaking:
  delay: 300
  timeout: 10
  selection: weighted_random
  types:
    blitz_3_2:
      tc: 3+2
    rapid_10_0:
      tc: 10+0
    blitz_5_3:
      tc: 5+3
    bullet_1_1:
      tc: 1+1
```

**Resign and draw:**
```yaml
offer_draw:
  enabled: true
  score: 10
  consecutive_moves: 5
  min_game_length: 30
  against_humans: true

resign:
  enabled: true
  score: -700
  consecutive_moves: 5
  against_humans: true
```

**Syzygy — disabled (no local tablebases assumed):**
```yaml
syzygy:
  standard:
    enabled: false
```

**Messages:**
```yaml
messages:
  greeting: "Hi! I'm a bot running {engine} on a Moto G32. Good luck! Type !help for commands."
  goodbye: "Good game!"
  greeting_spectators: "Watching {engine} on a Moto G32. Type !help for commands."
  goodbye_spectators: "Thanks for watching."
```

---

### `scripts/setup_termux.sh`

One-time setup. Must be run once before anything else.

```bash
#!/data/data/com.termux/files/usr/bin/bash
# Run once: bash scripts/setup_termux.sh
```

Steps (in order):
1. `pkg update && pkg upgrade -y`
2. `pkg install -y python git curl python-pip`
3. Install `uv`: `curl -LsSf https://astral.sh/uv/install.sh | sh`
4. Add uv to PATH: append `export PATH="$HOME/.local/bin:$PATH"` to `~/.bashrc` if not already present, then `source ~/.bashrc`
5. Clone BotLi into repo root: `git clone https://github.com/Torom/BotLi.git`
6. `cd BotLi && uv sync && cd ..`
7. Print: `Setup complete. Now run: bash scripts/download_engines.sh`

---

### `scripts/download_engines.sh`

Downloads prebuilt ARM64 Android binaries for Stockfish and Fairy-Stockfish.

**Stockfish:**
- Source: `https://github.com/official-stockfish/Stockfish/releases/latest`
- Look for asset matching `*android*aarch64*` or `*arm64*`
- If not found at latest, fall back to a known good release (hardcode a working URL as fallback)
- Extract binary, chmod +x, move to `engines/stockfish`

**Fairy-Stockfish:**
- Source: `https://github.com/fairy-stockfish/Fairy-Stockfish/releases/latest`
- Look for asset matching `*android*aarch64*` or `*arm64*`
- Same fallback pattern
- Move to `engines/fairy-stockfish`

**Fairy-Stockfish NNUEs:**
- Download all 7 variant NNUE files referenced in the EvalFile string above
- Base URL: `https://github.com/fairy-stockfish/Fairy-Stockfish/releases/download/fairy_sf_14/`
- Save into `engines/` directory (Fairy-SF will look there)
- Files: `3check-cb5f517c228b.nnue`, `antichess-dd3cbe53cd4e.nnue`, `atomic-2cf13ff256cc.nnue`, `crazyhouse-8ebf84784ad2.nnue`, `horde-28173ddccabe.nnue`, `kingofthehill-978b86d0e6a4.nnue`, `racingkings-636b95f085e3.nnue`

**After downloads:**
- Run `./engines/stockfish bench` and capture first line to verify it works
- Run `./engines/fairy-stockfish` with a quick UCI handshake test: echo `uci\nquit` and check response contains `uciok`
- Print pass/fail for each

**Error handling:**
- If curl fails, print the exact URL that failed and exit 1
- If binary doesn't respond to UCI, print `Engine test FAILED — binary may be wrong arch` and exit 1

---

### `README.md`

User-facing. Written for someone using Termux on Android with zero Linux background.

**Sections:**

#### Prerequisites
- Android phone (tested on Moto G32 8GB)
- Termux installed from F-Droid (NOT Play Store)
- A dedicated Lichess bot account (cannot have played any games before upgrading to bot)
- Lichess OAuth token with `bot:play` scope
- Opening book `.bin` files (polyglot format) — user provides their own

#### How to get a Lichess bot token
Step-by-step: go to lichess.org → account → API tokens → create → tick `bot:play` → save token

#### First-time setup (run once)
```bash
# In Termux:
pkg install git -y
git clone https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
cd YOUR_REPO_NAME
bash scripts/setup_termux.sh
bash scripts/download_engines.sh
```

#### Add your opening books
- Copy your `.bin` polyglot book files into the `books/` folder
- Edit `config.yml.template`: add book names under `opening_books: books: standard: names:` and register paths under the `books:` section at the bottom
- Example shown

#### Every time you want to run the bot
```bash
cd YOUR_REPO_NAME
bash start.sh
```

#### What you'll see in the terminal
- Login confirmation with your bot username
- Every incoming challenge (accepted or declined, with reason)
- Every move played (with whether it came from book or engine)
- Book move hits shown as: `[BOOK] e2e4 (weighted_random)`
- Engine moves shown as: `[ENGINE] d2d4 depth=22 score=+0.31`
- Matchmaking pings: `[MATCHMAKING] Challenging bot XYZ — 3+2 rated`
- Game results: `[RESULT] 1-0 vs PlayerName (blitz)`

#### Threads and Hash guidance
- G32 has 8 cores. Recommended: **6 threads**, leave 2 for OS
- Hash: **512MB** is safe, try **1024MB** if no crashes after a week

#### Upgrading your account to bot
- BotLi will prompt you on first run if your account hasn't been upgraded yet
- The upgrade is **irreversible** — the account can only play as a bot afterward

#### Keeping the bot running with screen
```bash
pkg install screen -y
screen -S bot
bash start.sh
# Ctrl+A then D to detach
# screen -r bot to reattach
```

#### Updating BotLi
```bash
cd BotLi
git pull
uv sync
cd ..
```

---

## Key Constraints for Coding Agent

1. **No hardcoded token anywhere** — token only ever lives in memory during the session via shell variable, written into `config.yml` (which is `.gitignore`d), then BotLi reads it. Never committed.

2. **`config.yml` is gitignored** — only `config.yml.template` is committed. Add `config.yml` and `BotLi/config.yml` to `.gitignore`.

3. **`engines/` binaries are gitignored** — only `engines/.gitkeep` committed.

4. **`books/` bins are gitignored** — only `books/.gitkeep` committed.

5. **BotLi is not a submodule** — `setup_termux.sh` clones it fresh. Do not fork or vendor BotLi source. Do not modify any BotLi Python files.

6. **`start.sh` must work in Termux's bash** — no `bash` features beyond 4.x, no `zsh`-isms. Use `read -s -p` carefully (Termux sometimes requires `-p` workaround: `printf "prompt: "; read -s VAR`).

7. **`concurrency: 1`** is non-negotiable — hardcoded, not a prompt option.

8. **Matchmaking delay is 300** — user said every 5 minutes. Do not change this.

9. **All online moves disabled** — `opening_explorer`, `lichess_cloud`, `chessdb`, `online_egtb` all `enabled: false`. Do not add any fallback online lookups.

10. **Fairy-SF EvalFile path** — the NNUE files are in `../engines/` relative to BotLi working directory. The EvalFile string only contains filenames, not paths — Fairy-SF resolves them relative to its working directory or the dir option. Verify this works; adjust path prefix in EvalFile if needed based on actual Fairy-SF behavior.

11. **No Python wrapper scripts** — `start.sh` is pure bash. Do not write a Python launcher.

12. **`screen` is documented but not auto-invoked** — `start.sh` does not wrap itself in screen. User runs screen manually if they want detach.

13. **The `books:` section and `opening_books:` section must stay in sync** — document this prominently in README and in comments inside `config.yml.template`.

---

## .gitignore Contents

```
config.yml
BotLi/config.yml
engines/stockfish
engines/fairy-stockfish
engines/*.nnue
books/*.bin
books/*.abk
books/*.ctg
BotLi/
__pycache__/
*.pyc
.env
```

Wait — BotLi dir should NOT be gitignored since `setup_termux.sh` clones it locally and it is not committed. Correct `.gitignore`:

```
config.yml
engines/stockfish
engines/fairy-stockfish
engines/*.nnue
books/*.bin
books/*.abk
books/*.ctg
BotLi/
__pycache__/
*.pyc
```

---

## Testing Checklist (for coding agent to verify before marking done)

- [ ] `bash scripts/setup_termux.sh` completes without error on a fresh Termux install
- [ ] `bash scripts/download_engines.sh` downloads both engines, both pass UCI test
- [ ] `bash start.sh` with empty token input re-prompts correctly
- [ ] `bash start.sh` with invalid thread count (e.g. `99`) re-prompts correctly
- [ ] `bash start.sh` with valid inputs prints correct login line
- [ ] `config.yml` is generated with correct substitutions (grep for `__TOKEN__` — should return nothing)
- [ ] BotLi starts and accepts an incoming challenge in all variants
- [ ] Book move hit is visible in terminal output when a book position is reached
- [ ] Matchmaking sends a challenge after 5 minutes idle
- [ ] `config.yml` does not appear in `git status` (gitignored correctly)
- [ ] `engines/stockfish` does not appear in `git status`
