# Bogs-prompt · 全平台操作手册

> 致接手此仓库的任何 AI：执行任何写入操作前，先读完本文件，对照【AI 自检清单】确认当前缺口。

---

## 一、系统架构总览

```
GitHub (main 分支) ── Raw URL ──→ 移动端 Termux (curl 拉取 → 剪贴板)
                  └── Raw URL ──→ 桌面端 Espanso (PowerShell 拉取 → 光标展开)
```

所有 `.md` 指令文件存放在仓库根目录，统一从 `main` 分支的 Raw URL 拉取。
**新增任何指令后，必须同步更新以下三处，缺一不可。**

---

## 二、移动端（Android · Termux）

### 原理
输入命令名 → shell alias 触发 → `curl` 从 GitHub Raw 拉取 `.md` → `termux-clipboard-set` 写入剪贴板 → 手动粘贴给任意 AI 对话框。

### 首次安装（只需执行一次）
```bash
# 1. 安装依赖
pkg install curl termux-api

# 2. 拉取并执行注册脚本
curl -s https://raw.githubusercontent.com/bog5d/Bogs-prompt/main/termux-setup.sh | bash

# 3. 重启 Termux 或执行
source ~/.bashrc
```

### 新增指令后的操作
1. 在仓库根目录新建 `[缩写].md`
2. 打开 `termux-setup.sh`，在"指令注册表"区域追加一行：
   ```bash
   add_alias "缩写" "缩写.md"   # 指令说明
   ```
3. 重新执行脚本：`bash termux-setup.sh`

### 日常使用
```bash
ksrj    # 拉取口述日记指令 → 注入剪贴板
kych    # 拉取考研词汇指令 → 注入剪贴板
smqpft  # 拉取生命切片访谈指令 → 注入剪贴板
```

---

## 三、桌面端（Windows · Espanso）

### 原理
输入触发词（如 `:ksrj`）→ Espanso 拦截 → 调用 `powershell.exe` → `Invoke-RestMethod` 从 GitHub Raw 拉取 `.md` → 原地展开替换触发词。

### 首次安装（只需执行一次）
1. 安装 [Espanso](https://espanso.org)
2. 将本仓库克隆到 Espanso 的 match 目录：
   ```
   %CONFIG%\match\Bogs-prompt\
   ```
   或手动将 `bogs.yml` 复制到 `%CONFIG%\match\` 目录下。
3. Espanso 自动热重载，无需重启。

### 新增指令后的操作
1. 在仓库根目录新建 `[缩写].md`
2. 在 `bogs.yml` 追加一段：
   ```yaml
     - trigger: ":[缩写]"
       replace: "{{output}}"
       vars:
         - name: output
           type: shell
           params:
             cmd: "powershell.exe -NoProfile -Command \"(Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/bog5d/Bogs-prompt/main/[缩写].md')\""
   ```
3. 推送到 GitHub `main` 分支后立即生效。

### 日常使用
在任意输入框（Word、浏览器、记事本）直接输入触发词：
```
:ksrj   → 展开口述日记完整指令
:kych   → 展开考研词汇完整指令
```

---

## 四、当前指令资产表

| 命令 | 触发词 | 文件 | 版本 | 用途 |
|------|--------|------|------|------|
| `ksrj` | `:ksrj` | `ksrj.md` | V3.3 | 口述日记 · 思想副本编译器 |
| `kych` | `:kych` | `kych.md` | V8.0 | 考研词汇 · 实景教练 VAR |
| `smqpft` | `:smqpft` | `smqpft.md` | V1.0 | 生命切片 · 访谈主理人 |
| `tysk` | `:tysk` | `tysk.md` | V1.0 | 通用 AI 协作 · Skill/Memory 同步 |

---

## 五、AI 自检清单（接手时必做）

每次 AI 接手此仓库，执行写入前，对照以下清单逐项确认：

- [ ] `main` 分支与开发分支是否同步？
- [ ] 每个 `.md` 指令文件是否在 `bogs.yml` 中有对应的 Espanso 触发词？
- [ ] 每个 `.md` 指令文件是否在 `termux-setup.sh` 的注册表中有对应 alias？
- [ ] `SETUP.md` 的指令资产表是否已更新？
- [ ] `README.md` 的资产目录是否已更新？

**发现缺口 → 立即补齐 → commit 并推送到 main。**

---

## 六、命名铁律（再次强调）

所有指令文件：`[拼音/英文极简缩写].md`，全小写，无空格。
触发词格式：`:[文件名不含扩展名]`
