#!/data/data/com.termux/files/usr/bin/bash
SERVER="http://47.85.62.133:8787"
TOKEN="d1f551894905ad52b2a1885216ff31ad11b07c146708d664"
GH_TOKEN="${BOGS_GH_TOKEN}"
GH_REPO="bog5d/Agentic-Capital-Workflow"

# 读内容
if [ $# -gt 0 ]; then
    TEXT="$*"; echo "💡 直接输入模式..."
else
    TEXT=$(termux-clipboard-get 2>/dev/null)
    if [ -z "$TEXT" ]; then
        echo "⏳ 唤醒剪贴板..."
        termux-toast "唤醒" 2>/dev/null; sleep 1.5
        TEXT=$(termux-clipboard-get 2>/dev/null)
    fi
fi
if [ -z "$TEXT" ]; then
    echo "👇 粘贴内容后按回车，再按 CTRL+D："; TEXT=$(cat)
fi
if [ -z "$TEXT" ]; then echo "❌ 没有内容"; exit 1; fi

# 发微信
echo -e "\n🚀 发送至微信中继站（${#TEXT} 字）..."
RESP=$(curl -s --connect-timeout 30 --max-time 180 -X POST "$SERVER/publish" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: text/plain; charset=utf-8" \
  --data-binary "$TEXT")
if ! echo "$RESP" | grep -Eq '"ok"\s*:\s*true'; then
    echo "❌ 微信失败：$RESP"; exit 1
fi
TITLE=$(echo "$RESP" | grep -Eo '"title"\s*:\s*"[^"]*"' | sed -E 's/"title"\s*:\s*"//;s/"$//')
echo "✅ 微信草稿已创建：$TITLE"

# 同步 GitHub
if [ -z "$GH_TOKEN" ]; then
    echo "⚠️ 跳过 GitHub（未设置 BOGS_GH_TOKEN）"; exit 0
fi
echo "📦 同步到 GitHub..."
DATE=$(date +%Y-%m-%d)
SLUG=$(echo "$TITLE" | python3 -c "import sys,re; t=sys.stdin.read().strip(); print(re.sub(r'[\s/|:*?<>\\\"]+','-',t).strip('-')[:50])")
FILENAME="notes/${DATE}-${SLUG}.md"
MD=$(echo "---"; echo "title: \"$TITLE\""; echo "date: $DATE"; echo "source: wechat-pub"; echo "---"; echo ""; echo "$TEXT")
B64=$(echo "$MD" | base64 -w 0)
GH_RESP=$(curl -s -X PUT \
  -H "Authorization: token $GH_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"message\":\"pub: ${TITLE}\",\"content\":\"${B64}\"}" \
  "https://api.github.com/repos/${GH_REPO}/contents/${FILENAME}")
if echo "$GH_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('content') else 1)" 2>/dev/null; then
    echo "✅ GitHub 已归档：${FILENAME}"
    echo "🔗 github.com/${GH_REPO}/blob/main/${FILENAME}"
else
    ERR=$(echo "$GH_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message','未知错误'))" 2>/dev/null)
    echo "⚠️ GitHub 同步失败（微信草稿已成功）：$ERR"
fi
