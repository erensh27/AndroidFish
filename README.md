# AndroidFish — Lichess Bot on Android (Termux / Moto G32)

A lightweight, robust setup to run a high-performance [Lichess Bot](https://lichess.org) powered by [BotLi](https://github.com/Torom/BotLi), **Stockfish**, and **Fairy-Stockfish** directly on an Android smartphone using **Termux** (no root, no Docker, no systemd required).

---

## 📋 Table of Contents

- [Prerequisites](#-prerequisites)
- [How to Get a Lichess Bot Token](#-how-to-get-a-lichess-bot-token)
- [First-Time Setup](#-first-time-setup-run-once)
- [Adding Your Opening Books](#-adding-your-opening-books)
- [Running the Bot](#-running-the-bot)
- [Terminal Output & UI](#-what-youll-see-in-the-terminal)
- [Threads & Hash Guidance](#-threads-and-hash-guidance)
- [Upgrading Account to Bot](#-upgrading-your-account-to-bot)
- [Keeping the Bot Running 24/7 (Screen)](#-keeping-the-bot-running-with-screen)
- [Updating BotLi](#-updating-botli)
- [Repository Structure](#-repository-structure)

---

## 📱 Prerequisites

1. **Android Device**: Tested and optimized for Moto G32 (Snapdragon 680, 8-core ARM64, 8GB RAM) or any ARM64 Android device.
2. **Termux (F-Droid)**: Install Termux strictly from [F-Droid](https://f-droid.org/en/packages/com.termux/) (do **NOT** use the deprecated Google Play Store version).
3. **Dedicated Lichess Account**: A brand new account that has **never played any games** (required by Lichess before bot upgrade).
4. **Lichess OAuth Token**: An API token generated with the `bot:play` permission.
5. **Polyglot Opening Books**: `.bin` polyglot opening book files placed into the `books/` folder.

---

## 🔑 How to Get a Lichess Bot Token

1. Log into your dedicated bot account on [lichess.org](https://lichess.org).
2. Go to **Settings** → **API access tokens** (or visit [https://lichess.org/account/oauth/token](https://lichess.org/account/oauth/token)).
3. Click **Generate a personal token**.
4. Give it a name (e.g., `AndroidFish-Bot`).
5. Check the box for **"Play games with the bot API"** (`bot:play`).
6. Click **Generate** and copy your token. Keep this token secret!

---

## 🚀 First-Time Setup (Run Once)

Open Termux on your Android phone and execute the following commands:

```bash
# 1. Install git
pkg install git -y

# 2. Clone the repository
git clone https://github.com/erensh27/AndroidFish.git
cd AndroidFish

# 3. Run the automated Termux environment setup
bash scripts/setup_termux.sh

# 4. Download Stockfish, Fairy-Stockfish, and variant NNUEs
bash scripts/download_engines.sh
```

---

## 📚 Adding Your Opening Books

1. Copy your `.bin` polyglot format book files into the `books/` folder:
   ```bash
   cp /sdcard/Download/*.bin books/
   ```
2. Open `config.yml.template` in a text editor (e.g., `nano config.yml.template`):
3. Ensure each book alias under `opening_books.books.standard.names` matches an entry in the `books:` section at the bottom:

```yaml
opening_books:
  enabled: true
  priority: 400
  books:
    standard:
      selection: weighted_random
      names:
        - Book1
        - Book2

# At the bottom of config.yml.template:
books:
  Book1: "../books/book1.bin"
  Book2: "../books/book2.bin"
```

> **Note:** The `opening_books: books:` list and the bottom `books:` dictionary must stay in sync. If no `.bin` books exist in `books/`, the launcher will warn you and gracefully disable local book moves so the engine continues without crashing.

---

## ⚡ Running the Bot

To start the bot, run the interactive launcher:

```bash
cd AndroidFish
bash start.sh
```

You will be prompted for:
1. **Lichess Bot Token**: (input is masked for security)
2. **Stockfish Threads**: Default is `6` (recommended for 8-core CPUs like Moto G32).
3. **Hash size in MB**: Default is `512` (recommended 512 MB).

```text
=== Lichess Bot — Moto G32 ===
Lichess Bot Token: 
Stockfish Threads [recommended: 6]: 6
Hash size in MB [recommended: 512]: 512
✓ Logged in as: YourBotUsername
✓ Threads: 6  Hash: 512MB  Games: 1 at a time
✓ Accepting: ALL time controls · ALL variants · rated + casual
✓ Matchmaking: every 5 minutes
✓ Online EGTB: DISABLED  |  Local books: ENABLED
Starting BotLi... (Ctrl+C to stop)
```

---

## 🖥️ What You'll See in the Terminal

- **Login Confirmation**: Displays your bot's Lichess username.
- **Challenge Management**: Incoming challenges logged with accept/decline decisions and reasons.
- **Move Logging**:
  - Book move hits: `[BOOK] e2e4 (weighted_random)`
  - Engine moves: `[ENGINE] d2d4 depth=22 score=+0.31`
- **Matchmaking Pings**: `[MATCHMAKING] Challenging bot XYZ — 3+2 rated`
- **Game Results**: `[RESULT] 1-0 vs PlayerName (blitz)`

---

## ⚙️ Threads and Hash Guidance

- **Moto G32 / Snapdragon 680 (8 cores)**:
  - **Threads**: Set to **6**. This leaves 2 CPU cores available for Termux, Python runtime, and Android OS background tasks.
  - **Hash**: **512 MB** is safe and reliable. You can test **1024 MB** if memory remains stable over extended sessions.

---

## 🤖 Upgrading Your Account to Bot

If you run `start.sh` on a new account that has not yet been registered as a bot, BotLi will display a confirmation prompt to upgrade the account.

> ⚠️ **IMPORTANT**: Upgrading an account to a Bot account on Lichess is **IRREVERSIBLE**. The account will only be able to play through the Bot API and cannot play manual games on the website.

---

## 🔄 Keeping the Bot Running with Screen

To keep your bot active in the background when closing Termux or locking the screen:

```bash
# Install screen
pkg install screen -y

# Start a detached screen session named 'bot'
screen -S bot
bash start.sh

# Detach from the session: Press Ctrl+A, then press D
# Reattach at any time:
screen -r bot
```

Make sure to disable Android battery optimization for Termux in Android Settings so Termux is not put to sleep.

---

## 🔄 Updating BotLi

To pull the latest upstream updates from BotLi:

```bash
cd BotLi
git pull
uv sync
cd ..
```

---

## 📁 Repository Structure

```
AndroidFish/
├── BUILD.md                  # Project build specifications and architecture notes
├── README.md                 # User guide and documentation
├── start.sh                  # Interactive startup script (prompts token, threads, hash)
├── config.yml.template       # Config template with __TOKEN__, __THREADS__, __HASH__ placeholders
├── engines/
│   ├── .gitkeep              # Engines directory (Stockfish & Fairy-Stockfish binaries)
│   └── stockfish / fairy-stockfish (installed via download_engines.sh)
├── books/
│   ├── .gitkeep              # Polyglot opening books directory
│   └── *.bin                 # User-provided .bin opening books
└── scripts/
    ├── setup_termux.sh       # One-time Termux package & dependency installer
    └── download_engines.sh   # Engine & variant NNUE downloader script
```
