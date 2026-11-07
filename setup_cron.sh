#!/usr/bin/env bash
# ==============================================================================
# Automated Systemd Service & Cron Job Installer: Discord Music Bot
# ==============================================================================
# Edit and run for your own requirements.
# It automatically:
#   1. Detects your non-root user and directory.
#   2. Creates and enables the systemd service (so it runs 24/7 without login).
#   3. Sets up a daily cron restart (so the bot doesn't stall or mute itself).
#
# Usage:
#   chmod +x setup_cron.sh
#   sudo ./setup_cron.sh
# ==============================================================================

# --- USER CONFIGURATION: SCHEDULE SETTINGS ---
# Edit the variables below to customize your restart time:
#
# CRON COLUMN GUIDE:
# 1. MINUTE (0 - 59)
# 2. HOUR   (0 - 23, 24-hour clock: 4 = 4:00 AM, 16 = 4:00 PM)
# 3. DOM    (Day of Month: 1 - 31, or * for every day)
# 4. MONTH  (Month: 1 - 12, or * for every month)
# 5. DOW    (Day of Week: 0 - 6 where 0=Sun, 1=Mon, ..., or * for every day)

RESTART_MINUTE="0"
RESTART_HOUR="4"
DAY_OF_MONTH="*"
MONTH="*"
DAY_OF_WEEK="*"

SERVICE_NAME="amg-bot.service"
# ==============================================================================

# Ensure script is run with root / sudo permissions
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: This script requires root permissions to configure systemd and cron."
    echo "👉 Please run with sudo: sudo ./setup_cron.sh"
    exit 1
fi

# Detect real calling user (never run bot process as root)
ACTUAL_USER="${SUDO_USER:-$USER}"

# Determine actual script location (so running from anywhere resolves the right bot folder)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOT_DIR="${SCRIPT_DIR}"

# Safety check: Verify required bot files exist in directory
if [ ! -f "${BOT_DIR}/bot.py" ] || [ ! -f "${BOT_DIR}/music.py" ]; then
    echo "❌ Error: Could not find bot.py or music.py in ${BOT_DIR}."
    echo "👉 Please change directory (cd) into the bot folder first:"
    echo "   cd /path/to/your/bot/directory"
    echo "   sudo ./setup_cron.sh"
    exit 1
fi

# Detect Python interpreter (prefer virtual environment)
if [ -f "${BOT_DIR}/venv/bin/python3" ]; then
    PYTHON_BIN="${BOT_DIR}/venv/bin/python3"
elif [ -f "${BOT_DIR}/venv/bin/python" ]; then
    PYTHON_BIN="${BOT_DIR}/venv/bin/python"
else
    PYTHON_BIN="$(which python3)"
fi

echo "=================================================="
echo "  Discord Music Bot Setup: Service & Cron"
echo "=================================================="
echo "Detected Environment:"
echo "  Running User : ${ACTUAL_USER}"
echo "  Bot Directory: ${BOT_DIR}"
echo "  Python Path  : ${PYTHON_BIN}"
echo "  Service Name : ${SERVICE_NAME}"
echo "--------------------------------------------------"

SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"

# Step 1: Create or update systemd service
echo "⚙️ Setting up systemd service: ${SERVICE_FILE}..."
cat <<EOF > "${SERVICE_FILE}"
[Unit]
Description=Discord Music Bot
After=network.target

[Service]
Type=simple
User=${ACTUAL_USER}
WorkingDirectory=${BOT_DIR}
ExecStart=${PYTHON_BIN} bot.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"
echo "✅ Service successfully written to ${SERVICE_FILE} and enabled on boot!"

# Step 2: Configure Cron Restart Job
CRON_COMMAND="/usr/bin/systemctl restart ${SERVICE_NAME}"
CRON_SCHEDULE="${RESTART_MINUTE} ${RESTART_HOUR} ${DAY_OF_MONTH} ${MONTH} ${DAY_OF_WEEK} ${CRON_COMMAND}"
START_TAG="# BEGIN-DISCORD-MUSIC-BOT-AUTORESTART"
END_TAG="# END-DISCORD-MUSIC-BOT-AUTORESTART"

echo "⚙️ Configuring cron restart schedule..."
echo "  Schedule: ${RESTART_MINUTE} ${RESTART_HOUR} ${DAY_OF_MONTH} ${MONTH} ${DAY_OF_WEEK} (${RESTART_HOUR}:${RESTART_MINUTE} daily)"

# Read existing crontab
EXISTING_CRON=$(crontab -l 2>/dev/null || true)

# Remove any existing restart block safely
CLEANED_CRON=$(echo "$EXISTING_CRON" | awk -v s="$START_TAG" -v e="$END_TAG" '
    $0 == s { skip=1; next }
    $0 == e { skip=0; next }
    !skip { print }
' | grep -F -v -x "${CRON_COMMAND}" | grep -F -v -x "${CRON_SCHEDULE}" || true)

# Build and install new crontab
NEW_CRON=$(cat <<EOF
${CLEANED_CRON}
${START_TAG}
${CRON_SCHEDULE}
${END_TAG}
EOF
)

echo "$NEW_CRON" | awk 'NF {p=1} p' | crontab -

echo "✅ Cron job successfully installed!"
echo ""
echo "Current active root crontab:"
echo "--------------------------------------------------"
crontab -l
echo "--------------------------------------------------"
echo "🎉 Setup complete! Start the bot now with: sudo systemctl restart ${SERVICE_NAME}"
echo "👉 Follow live logs with: journalctl -u ${SERVICE_NAME} -f"
