#!/data/data/com.termux/files/usr/bin/bash
# Bogs-prompt · pub
# 把剪贴板内容 → 微信中继站 → 生成标题/摘要 → 推送到微信公众号草稿箱。
# 职责单一：只发微信草稿。二次分发（GitHub/WordPress）交给 pub2gg。
#
# 密钥从 ~/.bog_secrets 读取：
#   export BOGS_PUB_TOKEN="中继站 bearer token"

SERVER="http://47.85.62.133:8787"
TOKEN="${BOGS_PUB_TOKEN}"

if [ -z "$TOKEN" ]; then
    echo "❌ 未设置 BOGS_PUB_TOKEN。请在 ~/.bog_secrets 中添加："
    echo "   echo 'export BOGS_PUB_TOKEN=\"你的中继token\"' >> ~/.bog_secrets && source ~/.bog_secrets"
    exit 1
fi

# 读内容：参数 > 剪贴板 > 手动粘贴
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
echo "👉 去公众号后台微调、配图后发布；发布后复制文章链接，运行 pub2gg 二次分发。"
