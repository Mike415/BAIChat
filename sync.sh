#!/bin/bash
# Sync BAI Area Boys v4.1 messages from app.db → static index.html → GitHub Pages
set -e

SPACE_DB="/home/hatch/workspace/spaces/bai-area-boys/app.db"
REPO_DIR="/home/hatch/workspace/BAIChat"

if [ ! -f "$SPACE_DB" ]; then
    echo "ERROR: app.db not found"
    exit 1
fi

cd "$REPO_DIR"

# Generate static HTML directly from DB (avoids shell JSON escaping issues)
python3 << 'PYEOF'
import sqlite3, html, re
from datetime import datetime

SENDER_COLORS = {
    "Steve Simon": "#53BDEB",
    "Eric Morgan": "#FFB347",
    "John Rushworth": "#77DD77",
    "John Foster": "#CB99C9",
}

db = sqlite3.connect("/home/hatch/workspace/spaces/bai-area-boys/app.db")
rows = db.execute("SELECT id, sender, content, timestamp FROM messages WHERE deleted = 0 ORDER BY id ASC").fetchall()
count = len(rows)

bubbles = []
prev_sender = None
for row in rows:
    msg_id, sender, content, ts = row
    is_me = sender == "Mike"
    show_sender = not is_me and sender != prev_sender
    color = SENDER_COLORS.get(sender, "#53BDEB")

    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        hour = dt.hour % 12 or 12
        ampm = "am" if dt.hour < 12 else "pm"
        time_str = f"{hour}:{dt.minute:02d} {ampm}"
    except:
        time_str = ""

    # Linkify BEFORE html-escaping
    parts = re.split(r'(https?://\S+)', content)
    content_escaped = ""
    for part in parts:
        if re.match(r'^https?://\S+$', part):
            url_esc = html.escape(part)
            content_escaped += f'<a href="{url_esc}" target="_blank" rel="noopener" style="color:#53BDEB;text-decoration:none;word-break:break-all">{url_esc}</a>'
        else:
            content_escaped += html.escape(part)

    direction = "out" if is_me else "in"
    sender_html = f'<div class="sender" style="color:{color}">{html.escape(sender)}</div>' if show_sender else ""
    status_html = '<span class="status">✓✓</span>' if is_me else ""
    margin = "6px 0 1px" if show_sender else "1px 0"

    bubbles.append(f'<div class="message {direction}" style="margin:{margin}"><div class="bubble">{sender_html}<div class="text">{content_escaped}</div><div class="meta"><span class="time">{time_str}</span>{status_html}</div><div style="clear:both"></div></div></div>')
    prev_sender = sender

db.close()

chat_html = "\n".join(bubbles)

page = f'''<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><title>BAI Area Boys</title>
<style>*{{margin:0;padding:0;box-sizing:border-box}}html,body{{height:100%}}body{{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;background:#0B141A;color:#E9EDEF;height:100vh;height:100dvh;display:flex;flex-direction:column}}.header{{position:sticky;top:0;z-index:10;background:#202C33;padding:max(16px,env(safe-area-inset-top)) 16px 12px;display:flex;align-items:center;gap:12px;border-bottom:1px solid #222D34;flex-shrink:0}}.header .avatar{{width:40px;height:40px;border-radius:50%;background:linear-gradient(135deg,#00A884,#008069);display:flex;align-items:center;justify-content:center;font-weight:600;font-size:15px;color:white;flex-shrink:0}}.header .info{{flex:1}}.header .title{{font-size:16px;font-weight:600;color:#E9EDEF;display:flex;align-items:center;gap:8px}}.header .dot{{width:8px;height:8px;border-radius:50%;background:#00A884;display:inline-block;animation:pulse 2s infinite}}.header .subtitle{{font-size:12.5px;color:#8696A0;margin-top:2px}}.chat{{flex:1;overflow-y:auto;padding:8px 6px 16px;display:flex;flex-direction:column;gap:1px;-webkit-overflow-scrolling:touch}}.message{{display:flex;margin:1px 0}}.message.in{{justify-content:flex-start}}.message.out{{justify-content:flex-end}}.bubble{{max-width:78%;padding:6px 8px 4px;border-radius:7.5px;word-wrap:break-word;box-shadow:0 1px 0.5px rgba(0,0,0,0.13)}}.message.in .bubble{{background:#202C33;border-top-left-radius:2px;margin-left:8px}}.message.out .bubble{{background:#005C4B;border-top-right-radius:2px;margin-right:8px}}.sender{{font-size:12.5px;font-weight:500;margin-bottom:2px;line-height:1}}.text{{font-size:14.5px;line-height:19px;color:#E9EDEF;white-space:pre-wrap;word-break:break-word}}.meta{{display:flex;justify-content:flex-end;align-items:center;gap:3px;margin-top:2px;margin-left:8px;float:right;height:15px}}.time{{font-size:11px;color:#8696A0;white-space:nowrap}}.status{{font-size:11px;color:#53BDEB;margin-left:2px}}@keyframes pulse{{0%,100%{{opacity:1}}50%{{opacity:0.4}}}}@media(max-width:640px){{.bubble{{max-width:85%}}.text{{font-size:14px}}}}</style>
</head><body>
<div class="header"><div class="avatar">BAI</div><div class="info"><div class="title">BAI Area Boys <span class="dot"></span></div><div class="subtitle">Mike, Steve, Eric, John R, John F &bull; {count} messages</div></div></div>
<div class="chat" id="chat">
{chat_html}
</div>
<script>var c=document.getElementById('chat');c.scrollTop=c.scrollHeight;</script>
</body></html>'''

with open("index.html", "w") as f:
    f.write(page)
print(f"Generated index.html with {count} messages")
PYEOF

# Commit and push
git add -A
if git diff --cached --quiet; then
    echo "No changes to push"
else
    git commit -m "Auto-sync v4.1: $(date -u +'%Y-%m-%d %H:%M') - $(sqlite3 "$SPACE_DB" 'SELECT COUNT(*) FROM messages WHERE deleted=0') messages"
    git push origin main
    echo "Pushed to GitHub"
fi
