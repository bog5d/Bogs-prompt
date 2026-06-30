#!/bin/bash
# Bogs-prompt · rec
# 剪贴板内容 → 本地 Obsidian Vault → git 同步
# 标题提取优先级：任意级别 Markdown 标题 > ksrj "日期·议题" > 首行内容 > 时间戳兜底

VAULT_PATH="/storage/emulated/0/同步git02"
CONTENT=$(termux-clipboard-get)

if [ -z "$CONTENT" ]; then
    echo "⚠️ 剪贴板是空的！"
    exit 1
fi

DATE=$(date +"%Y-%m-%d")

# ── 标题提取（四级优先级）──────────────────────────────────────
# 优先级1：任意级别 Markdown 标题（# ## ### ####）
TITLE=$(echo "$CONTENT" | grep -m 1 '^#\{1,6\} ' | sed 's/^#\{1,6\} //')

# 优先级2：ksrj 格式 "YYYY-MM-DD · 核心议题" → 只取 · 后面的议题部分
if echo "$TITLE" | grep -q ' · '; then
    TITLE=$(echo "$TITLE" | sed 's/^[0-9-]* · //')
fi

# 优先级3：无标题时，跳过空行取第一行有效内容（前20字）
if [ -z "$TITLE" ]; then
    TITLE=$(echo "$CONTENT" | grep -m 1 -v '^[[:space:]]*$' | cut -c1-20)
fi

# 优先级4：真的什么都没有，用时间戳（不再用"未命名日记"）
if [ -z "$TITLE" ]; then
    TITLE=$(date +"%H%M%S")
fi

# ── 文件名清理 ────────────────────────────────────────────────
# 白名单策略：只保留 ASCII 可打印字符 + 中文，其余一律剔除
SAFE_TITLE=$(echo "$TITLE" | python3 -c "
import sys, re
t = sys.stdin.read().strip()
t = re.sub(r'[^\x20-\x7E一-鿿㐀-䶿＀-￯　-〿]', '', t)
t = re.sub(r'[/\\\\:*?\"<>|]', '_', t)
t = re.sub(r'\s+', '_', t)
t = re.sub(r'_+', '_', t)
print(t.strip('_'))
")

FILE_NAME="${DATE}_${SAFE_TITLE}.md"
FILE_PATH="$VAULT_PATH/$FILE_NAME"

# ── 冲突处理：同名文件自动加序号，不覆盖 ────────────────────
if [ -f "$FILE_PATH" ]; then
    n=2
    while [ -f "${VAULT_PATH}/${DATE}_${SAFE_TITLE}_${n}.md" ]; do
        n=$((n + 1))
    done
    FILE_NAME="${DATE}_${SAFE_TITLE}_${n}.md"
    FILE_PATH="$VAULT_PATH/$FILE_NAME"
    echo "⚠️  同名文件已存在，另存为：$FILE_NAME"
fi

# ── 写入 ──────────────────────────────────────────────────────
if echo "$CONTENT" > "$FILE_PATH"; then
    echo "✅ 已存入：$FILE_NAME"
    echo "── 内容预览（前3行）──────────────────────"
    echo "$CONTENT" | head -n 3
    echo "──────────────────────────────────────────"

    # ── Flomo 同步 ────────────────────────────────────────────
    if [ -n "$BOGS_FLOMO_WEBHOOK" ]; then
        FLOMO_PAYLOAD=$(python3 -c "
import json, sys
content = sys.stdin.read()
payload = {'content': content, 'content_type': 'markdown'}
print(json.dumps(payload))
" <<< "$CONTENT")
        FLOMO_HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
            -X POST "$BOGS_FLOMO_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "$FLOMO_PAYLOAD")
        if [ "$FLOMO_HTTP" = "200" ]; then
            echo "📝 已同步到 Flomo"
        else
            echo "⚠️  Flomo 同步失败 (HTTP $FLOMO_HTTP)，本地已保存"
        fi
    fi

    cd "$VAULT_PATH"
    bash -ic 'obs'
else
    echo "❌ 写入失败！"
    echo "目标路径：$FILE_PATH"
    exit 1
fi
