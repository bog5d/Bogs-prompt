#!/data/data/com.termux/files/usr/bin/bash
# Bogs-prompt · Termux 一键指令注册脚本
# 用法：bash termux-setup.sh
# 每次新增指令后，在此脚本追加，重新执行即可。

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

install_script() {
  local cmd=$1
  local file=$2
  local dest="/data/data/com.termux/files/usr/bin/${cmd}"
  curl -s "${RAW}/${file}" -o "$dest"
  chmod +x "$dest"
  echo "✅ 安装脚本命令：$cmd → $dest"
}

# ── 别名指令（注入剪贴板型）────────────────────────────────────
add_alias "ksrj"   "ksrj.md"    # 口述日记 · 思想副本
add_alias "kych"   "kych.md"    # 考研词汇 · 实景教练
add_alias "smqpft" "smqpft.md"  # 生命切片 · 访谈主理人
add_alias "tysk"   "tysk.md"    # 通用 AI 协作 Skill 同步

# ── 可执行脚本指令（直接运行型）────────────────────────────────
install_script "pub" "pub.sh"   # 发布：微信草稿 + GitHub 归档双写

# ── 本地密钥加载 ────────────────────────────────────────────────
if ! grep -q "bog_secrets" "$BASHRC" 2>/dev/null; then
  echo 'source ~/.bog_secrets 2>/dev/null' >> "$BASHRC"
fi

source "$BASHRC" 2>/dev/null
echo ""
echo "✅ Bogs-prompt 指令注册完毕"
echo "   剪贴板型：ksrj, kych, smqpft, tysk"
echo "   执行型：  pub（微信草稿 + GitHub 双写）"
echo ""
echo "⚠️  首次使用 pub 前，请确认已设置 GitHub Token："
echo "   echo 'export BOGS_GH_TOKEN=\"你的token\"' >> ~/.bog_secrets"
echo "   source ~/.bog_secrets"
