#!/data/data/com.termux/files/usr/bin/bash
SERVER="http://47.85.62.133:8787"
TOKEN="d1f551894905ad52b2a1885216ff31ad11b07c146708d664"
GH_TOKEN="${BOGS_GH_TOKEN}"   # 从环境变量读取，见 ~/.bog_secrets
GH_REPO="bog5d/Agentic-Capital-Workflow"

# ── 1. 读取内容（三档兜底）─────────────────────────────────────
if [ $# -gt 0 ]; then
    TEXT="$*"
    echo "💡 检测到直接输入模式..."
else
    TEXT=$(termux-clipboard-get 2>/dev/null)
    if [ -z "$TEXT" ]; then
        echo "⏳ 系统底层剪贴板休眠，正在自动唤醒..."
        termux-toast "唤醒剪贴板" 2>/dev/null
        sleep 1.5
        TEXT=$(termux-clipboard-get 2>/dev/null)
    fi
fi

if [ -z "$TEXT" ]; then
    echo "=========================================="
    echo "⚠️ 剪贴板读取被系统拦截，或没有内容！"
    echo "👇 请在下方直接【长按粘贴】你的文章全文："
    echo "（粘贴完成后，按【回车】，再按【CTRL+D】发送）"
    echo "=========================================="
    TEXT=$(cat)
fi

if [ -z "$TEXT" ]; then
    echo "❌ 取消发送：没有检测到任何内容。"
    exit 1
fi

# ── 2. 发送至微信中继站 ───────────────────────────────────────
echo -e "\n🚀 正在发送至阿里云中继站（${#TEXT} 字）..."
echo "🎨 后台正在极客排版并进行智能正文配图，请稍候..."

RESP=$(curl -s --connect-timeout 30 --max-time 180 -X POST "$SERVER/publish" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: text/plain; charset=utf-8" \
  --data-binary "$TEXT")

if ! echo "$RESP" | grep -E -q '"ok"\s*:\s*true'; then
    echo "❌ 微信发布失败！服务器返回："
    echo "$RESP"
    exit 1
fi

TITLE=$(echo "$RESP" | grep -Eo '"title"\s*:\s*"[^"]*"' | sed -E 's/"title"\s*:\s*"//' | sed 's/"$//')
echo "✅ 微信草稿已创建！"
echo "📝 文章标题：$TITLE"
echo "💡 请去微信后台查收草稿，润色后发布。"

# ── 3. 同步到 GitHub ──────────────────────────────────────────
if [ -z "$GH_TOKEN" ]; then
    echo "⚠️  跳过 GitHub 同步：未设置 BOGS_GH_TOKEN（见 ~/.bog_secrets）"
    exit 0
fi

echo -e "\n📦 正在同步到 GitHub..."

DATE=$(date +%Y-%m-%d)
SLUG=$(echo "$TITLE" | sed 's/[^[:alnum:][:space:]]/-/g' | tr ' ' '-' | cut -c1-40)
FILENAME="notes/${DATE}-${SLUG}.md"

MD_CONTENT=$(printf "---\ntitle: \"%s\"\ndate: %s\nsource: wechat-pub\n---\n\n%s" "$TITLE" "$DATE" "$TEXT")
CONTENT_B64=$(echo "$MD_CONTENT" | base64 -w 0)

GH_RESP=$(curl -s -X PUT \
  -H "Authorization: token $GH_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"message\": \"pub: ${TITLE}\",
    \"content\": \"${CONTENT_B64}\"
  }" \
  "https://api.github.com/repos/${GH_REPO}/contents/${FILENAME}")

if echo "$GH_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('content') else 1)" 2>/dev/null; then
    echo "✅ 已归档到 GitHub: ${FILENAME}"
    echo "🔗 https://github.com/${GH_REPO}/blob/main/${FILENAME}"
else
    ERR=$(echo "$GH_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message',''))" 2>/dev/null)
    echo "⚠️  GitHub 同步失败（微信草稿已成功）: $ERR"
fi
