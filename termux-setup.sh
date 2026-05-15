#!/data/data/com.termux/files/usr/bin/bash
# Bogs-prompt · Termux 一键指令注册脚本
# 用法：bash termux-setup.sh
# 每次新增 .md 指令后，在此脚本追加一行 add_alias，重新执行即可。

BASHRC="$HOME/.bashrc"
RAW="https://raw.githubusercontent.com/bog5d/Bogs-prompt/main"

add_alias() {
  local cmd=$1
  local file=$2
  local line="alias ${cmd}='curl -s ${RAW}/${file} | termux-clipboard-set && echo \"✅ ${cmd} 已注入剪贴板\"'"
  if grep -qF "alias ${cmd}=" "$BASHRC" 2>/dev/null; then
    sed -i "/alias ${cmd}=/c\\${line}" "$BASHRC"
  else
    echo "$line" >> "$BASHRC"
  fi
}

# ── 指令注册表（新增指令在此追加）──────────────────────────
add_alias "ksrj"   "ksrj.md"    # 口述日记 · 思想副本
add_alias "kych"   "kych.md"    # 考研词汇 · 实景教练
add_alias "smqpft" "smqpft.md"  # 生命切片 · 访谈主理人
add_alias "tysk"   "tysk.md"    # 通用 AI 协作 Skill 同步
# ────────────────────────────────────────────────────────────

# shellcheck disable=SC1090
source "$BASHRC"
echo ""
echo "✅ Bogs-prompt 指令注册完毕"
echo "   当前可用命令：ksrj, kych, smqpft, tysk"
echo "   用法：直接在 Termux 输入命令名，内容自动注入剪贴板，粘贴给任意 AI 即可。"
