# Discord Music Bot 🎧

A production-grade, self-healing Discord music bot designed for 24/7 server voice channels. Features automatic silent channel joining, listener presence-triggered True Random radio playback, zero-privileged-intents operation, and drift-locked jitter-free audio streaming.

---

## 🌟 Key Features

1. **Silent 24/7 Auto-Join & Idle**:
   - The bot automatically connects to your designated voice/radio channel (configured via `AUTO_JOIN_VOICE_CHANNEL_ID` in `.env` or auto-detected by channel name) silently on startup without spamming chat embeds.
   - If listeners are already in the channel when it comes online, it starts playing the server playlist automatically.
   - If the room is empty, it sits silently in the channel.

2. **Presence-Driven Playback**:
   - When a human joins the voice channel, the bot immediately starts streaming the server playlist in **True Random** (memoryless shuffle with replacement) mode.
   - When the last human leaves, the bot stops playback after a 2-second grace period to save CPU and network bandwidth. It waits silently for the next listener (or leaves if `LEAVE_ON_EMPTY=true`).

3. **Self-Healing Watchdog**:
   - A 30-second background watchdog monitors voice connectivity. If Discord's voice servers drop or a network blip occurs, the bot reconnects automatically.
   - If an administrator explicitly runs `/leave`, the bot honors it and will not force-rejoin until `/join`, `/play`, or a listener enters.

4. **WebRTC & RFC 3550 Compliant Audio Engine**:
   - **RTP Timestamp Gap Compensation**: Patched `discord.VoiceClient.send_audio_packet` dynamically advances RFC 3550 RTP timestamps across track changes and pauses, preventing Discord's WebRTC NetEq buffer from falling into slow-motion catch-up or high-speed jitter.
   - **Pre-Decoded 5-Second Memory Buffer**: Decodes up to 250 audio frames (5 seconds) into RAM via a background thread to prevent underruns during network packet spikes.
   - **Drift-Locked Pacing**: Hardware-timed 20ms frame delivery (`time.perf_counter()`) with initial silence priming.

---

## 🔐 Discord Application Setup & Permissions Guide

Follow these step-by-step instructions in the [Discord Developer Portal](https://discord.com/developers/applications) to register and configure the application:

### Step 1: Create the Discord Application
1. Go to the [Discord Developer Portal](https://discord.com/developers/applications).
2. Click the **"New Application"** button in the top right.
3. Give your application a name (e.g. `Discord Music Bot`) and agree to the Developer Terms of Service.
4. *(Optional)* Under **General Information**, upload an avatar/icon and a description for your bot.

---

### Step 2: Configure the Bot User & Secret Token
1. In the left navigation menu, click on the **"Bot"** tab.
2. Click **"Reset Token"** (and enter your 2FA code if prompted).
3. **Copy the token immediately** and paste it into your `.env` file as `DISCORD_TOKEN`. Keep this token completely private!
4. **Public Bot**: You can toggle this **OFF** if you want to ensure only you can invite the bot to servers.
5. **Privileged Gateway Intents**:
   Leave **all three switches toggled OFF**:
   - ❌ **Presence Intent**: OFF
   - ❌ **Server Members Intent**: OFF
   - ❌ **Message Content Intent**: OFF

> **Why Zero Privileged Intents?**
> - The bot uses Discord Slash Commands (`/play`, `/playlist`), which deliver arguments directly via interactions without needing message content inspection.
> - The bot uses Discord Gateway `channel.voice_states` to detect voice listeners in real-time, eliminating the need for privileged member cache intents.
> - Your bot will **never require Discord verification** or intent auditing!

---

### Step 3: Generate the Bot Invite Link (OAuth2)
1. In the left navigation menu, navigate to **OAuth2 > URL Generator**.
2. Under **Scopes**, select:
   - `bot`
   - `applications.commands`
3. Under **Bot Permissions**, select the following checkboxes:
   - **General Permissions**:
     - *View Channels*
   - **Text Permissions**:
     - *Send Messages*
     - *Embed Links*
     - *Read Message History*
     - *Use External Emojis*
   - **Voice Permissions**:
     - *Connect*
     - *Speak*
     - *Use Voice Activity*
     - *Priority Speaker* *(optional but recommended)*
4. The generated permissions integer will be: **`37047552`**.
5. Copy the generated URL at the bottom:
   ```
   https://discord.com/oauth2/authorize?client_id=YOUR_CLIENT_ID&permissions=37047552&scope=bot+applications.commands
   ```
6. Open the URL in your web browser, select your Discord server, and click **Authorize**.

---

### Step 4: Server Whitelist Safeguard
To guarantee that nobody else can run the bot or hijack its audio streams, the bot enforces optional server ID whitelisting in your `.env` file:
```env
GUILD_ID=your_server_id_here
```
If the bot is ever invited to an unauthorized server, it logs the attempt and auto-leaves immediately. (Leave blank to allow the bot in any server).

---

## 🛠️ Linux Installation & Deployment Guide

Follow these steps to set up the bot on any Linux machine (Ubuntu, Debian, Raspberry Pi OS, etc.):

### Step 1: Install System Dependencies
Update your system packages and install the audio and Python dependencies:
```bash
sudo apt update && sudo apt install -y ffmpeg libopus0 libopus-dev nodejs python3 python3-pip python3-venv git curl
```

### Step 2: Clone & Set Up the Python Environment
```bash
# Clone your repository (or copy the project folder)
git clone <your_repository_url>

# IMPORTANT: Always change directory (cd) into the bot's folder before continuing:
cd <your_repository_directory>

# Verify you are in the correct directory (should list bot.py, music.py, requirements.txt):
ls -la

# Create and activate a Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install required Python libraries
pip install --upgrade pip
pip install -r requirements.txt
```

### Step 3: Configure Environment Variables
Ensure you are inside the bot directory (`cd <your_repository_directory>`), then copy the template configuration file to `.env`:
```bash
cp .env.example .env
```
Open `.env` in your text editor (e.g. `nano .env`) and fill in your values:
```env
# Paste your Discord Bot Token from Step 2 of the Discord Portal guide
DISCORD_TOKEN=your_bot_token_here

# Restrict bot to your server ID (leave blank to allow any server)
GUILD_ID=your_server_id_here

# Voice channel ID to auto-join silently on startup (leave blank to auto-detect by name)
AUTO_JOIN_VOICE_CHANNEL_ID=your_voice_channel_id_here

# Leave voice channel when empty (defaults to false: sits silently 24/7)
LEAVE_ON_EMPTY=false
```

### Step 4: Automated 24/7 Service & Daily Restart Setup
To run the bot as a background service that:
- Automatically starts on system boot (even when no user is logged in),
- Automatically restarts if it ever crashes, and
- Runs a scheduled daily restart at 04:00 AM to keep memory and audio sockets fresh,

ensure your terminal is inside the bot folder, then run the installer:
```bash
# Make sure you are in the bot directory:
cd <your_repository_directory>

# Make executable and run:
chmod +x setup_cron.sh
sudo ./setup_cron.sh
```

The script automatically detects your non-root user, project folder, and Python path, sets up the systemd service, and schedules the daily cron restart.

### Step 5: Start & Manage the Service
```bash
# Start the bot service
sudo systemctl start amg-bot.service

# View live status and song playback logs
journalctl -u amg-bot.service -f

# Stop or restart manually
sudo systemctl stop amg-bot.service
sudo systemctl restart amg-bot.service
```

---

## 🎵 Commands Reference

### Server Master Playlist Commands
| Slash Command | Permissions | Description |
|---|---|---|
| `/play` *(no query)* | Everyone | Starts playing the **Server Master Playlist** on True Random loop. |
| `/play [track]` | Everyone | Starts playing the master playlist at a specific track number (e.g. `/play 5`). |
| `/playlist play` | Everyone | Starts playing the master playlist on continuous True Random loop. |
| `/playlist list` | Everyone | View all saved tracks with pagination buttons. |
| `/playlist add <url/query>` | **Admin Only** | Adds a song or full YouTube playlist to the master playlist. |
| `/playlist remove <#>` | **Admin Only** | Removes a track number from the master playlist. |
| `/playlist clear` | **Admin Only** | Clears all songs from the master playlist. |

### Playback & Audio Controls
| Slash Command | Permissions | Description |
|---|---|---|
| `/play <url/name>` | Everyone | Plays a specific one-off song (plays once and stops). |
| `/pause` / `/resume` | Everyone | Pause or resume playback. |
| `/skip` | Everyone | Skip to the next track. |
| `/stop` | Everyone | Stops playback and clears the active session. |
| `/nowplaying` | Everyone | View current track details, thumbnail, duration, and requester. |
| `/queue` | Everyone | Display upcoming songs and current loop mode. |
| `/volume <1-100>` | Everyone | Adjust bot output volume. |
| `/autovolume` | Everyone | Toggle automatic loudness equalization (boosts quiet tracks). |
| `/join` / `/leave` | Everyone | Connect or disconnect the bot from voice. |
