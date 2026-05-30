#!/data/data/com.termux/files/usr/bin/python3
# -*- coding: utf-8 -*-
# Bogs-prompt · pub2gg
# ───────────────────────────────────────────────────────────────
# 把【已发表的微信公众号文章】二次分发：
#   1. 抓取正文 + 配图
#   2. 配图下载后重新上传到自己的 WordPress 媒体库（方案 B，永不挂图）
#   3. 用重托管后的图片链接，发布到 WordPress（hellobog.com，直接发布）
#   4. 同一套内容转 Markdown，归档到 GitHub
#   5. 文末统一追加「本文首发于公众号」声明，反向引流
#
# 用法：
#   复制微信文章链接到剪贴板 → 在 Termux 输入：pub2gg
#   或直接：pub2gg https://mp.weixin.qq.com/s/xxxxxxxx
#
# 所有密钥从 ~/.bog_secrets 环境变量读取，脚本内不存任何明文。
# ───────────────────────────────────────────────────────────────

import os
import sys
import re
import time
import base64
import subprocess
from datetime import date
from urllib.parse import urlparse, parse_qs


# ---------- 依赖自检（缺啥装啥）----------
def ensure(pip_name, import_name=None):
    try:
        __import__(import_name or pip_name)
    except ImportError:
        print(f"📦 首次运行，安装依赖 {pip_name} ...")
        subprocess.run([sys.executable, "-m", "pip", "install", pip_name], check=True)


ensure("requests")
ensure("beautifulsoup4", "bs4")
ensure("markdownify")

import requests
from bs4 import BeautifulSoup
from markdownify import markdownify as html_to_md


# ---------- 配置（来自 ~/.bog_secrets）----------
WP_URL     = os.environ.get("BOGS_WP_URL", "https://hellobog.com").rstrip("/")
WP_USER    = os.environ.get("BOGS_WP_USER", "")
WP_PASS    = os.environ.get("BOGS_WP_APPPASS", "")   # WordPress 应用程序密码
GH_TOKEN   = os.environ.get("BOGS_GH_TOKEN", "")
GH_REPO    = os.environ.get("BOGS_GH_REPO", "bog5d/Agentic-Capital-Workflow")
MP_NAME    = os.environ.get("BOGS_MP_NAME", "")       # 公众号名称，用于首发声明
TG_TOKEN   = os.environ.get("BOGS_TG_TOKEN", "")      # Telegram Bot Token
TG_CHANNEL = os.environ.get("BOGS_TG_CHANNEL", "")    # Telegram Channel，如 @AgentToWest

UA = ("Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36")

EXT_MAP   = {"jpeg": "jpg", "jpg": "jpg", "png": "png", "gif": "gif", "webp": "webp"}
CTYPE_MAP = {"jpg": "image/jpeg", "png": "image/png",
             "gif": "image/gif", "webp": "image/webp"}


def _load_secrets():
    p = os.path.expanduser("~/.bog_secrets")
    if not os.path.exists(p):
        return
    with open(p) as fp:
        for line in fp:
            line = line.strip()
            if line.startswith("export "):
                line = line[7:]
            if "=" in line and not line.startswith("#"):
                k, _, v = line.partition("=")
                v = v.strip().strip('"').strip("'")
                if k.strip() not in os.environ:
                    os.environ[k.strip()] = v

_load_secrets()


def die(msg):
    print(f"❌ {msg}")
    sys.exit(1)


# ---------- 取链接 ----------
def get_url():
    if len(sys.argv) > 1:
        return sys.argv[1].strip()
    try:
        out = subprocess.run(["termux-clipboard-get"],
                             capture_output=True, text=True, timeout=10)
        return out.stdout.strip()
    except Exception:
        return ""


# ---------- 抓取并解析文章 ----------
def fetch_article(url):
    print("🌐 抓取微信文章 ...")
    r = requests.get(url, headers={"User-Agent": UA}, timeout=30)
    r.raise_for_status()
    soup = BeautifulSoup(r.text, "html.parser")

    node = soup.select_one("#activity-name") or soup.select_one("h1.rich_media_title")
    title = node.get_text(strip=True) if node else ""
    if not title:
        meta = soup.select_one('meta[property="og:title"]')
        title = meta["content"].strip() if meta and meta.get("content") else "未命名文章"

    name = MP_NAME
    nnode = soup.select_one("#js_name")
    if nnode and nnode.get_text(strip=True):
        name = nnode.get_text(strip=True)

    digest = ""
    for sel in ('meta[name="description"]', 'meta[property="og:description"]'):
        m = soup.select_one(sel)
        if m and m.get("content", "").strip():
            digest = m["content"].strip()
            break

    content = soup.select_one("#js_content")
    if content is None:
        die("找不到正文 #js_content —— 可能不是公众号文章页，或文章需要验证。")
    return title, name, content, digest


def wx_ext(u):
    fmt = (parse_qs(urlparse(u).query).get("wx_fmt") or ["jpeg"])[0].lower()
    return EXT_MAP.get(fmt, "jpg")


# ---------- 下载微信图 + 上传 WordPress ----------
def rehost_image(img_url, idx, retries=3):
    last_err = None
    for attempt in range(retries):
        try:
            resp = requests.get(img_url, headers={"User-Agent": UA}, timeout=60)
            resp.raise_for_status()
            ext = wx_ext(img_url)
            fn = f"pub2gg-{date.today().isoformat()}-{idx}.{ext}"
            up = requests.post(
                f"{WP_URL}/wp-json/wp/v2/media",
                auth=(WP_USER, WP_PASS),
                headers={"Content-Disposition": f'attachment; filename="{fn}"',
                         "Content-Type": CTYPE_MAP.get(ext, "image/jpeg")},
                data=resp.content, timeout=120)
            up.raise_for_status()
            return up.json()["source_url"]
        except Exception as e:
            last_err = e
            if attempt < retries - 1:
                print(f"   ↩️ 重试 {attempt+2}/{retries} ...")
                time.sleep(4 * (attempt + 1))
    raise last_err


def process_images(content):
    """返回 {原始url: 新url} 映射；无 WP 凭证时返回空映射并保留微信链接。"""
    raw_imgs = []
    for im in content.find_all("img"):
        src = im.get("data-src") or im.get("src")
        if src and src.startswith("http"):
            raw_imgs.append(src)
    uniq = list(dict.fromkeys(raw_imgs))
    mapping = {}

    if WP_USER and WP_PASS and uniq:
        print(f"🖼  重托管 {len(uniq)} 张配图到 WordPress 媒体库 ...")
        for i, src in enumerate(uniq, 1):
            try:
                mapping[src] = rehost_image(src, i)
                print(f"   ✅ 图 {i}/{len(uniq)}")
            except Exception as e:
                print(f"   ⚠️ 图 {i} 重托管失败，保留微信原链：{e}")
                mapping[src] = src
    elif uniq:
        print("⚠️ 未配置 WordPress 凭证，配图保留微信原链（可能在站外裂图）。")

    # 重写 img 标签：data-src → src，套用新链接，清理懒加载属性
    for im in content.find_all("img"):
        src = im.get("data-src") or im.get("src")
        if not src:
            continue
        im["src"] = mapping.get(src, src)
        for attr in ("data-src", "data-w", "data-ratio", "data-type", "data-s", "data-backh"):
            if im.has_attr(attr):
                del im[attr]
        im["style"] = "max-width:100%;height:auto;"
    return mapping


# ---------- 推送到 Telegram（经阿里云中继，物理隔离）----------
def tg_push(title, wp_link, wx_url, src_label, md_text):
    relay_token = os.environ.get("BOGS_PUB_TOKEN", "")
    if not relay_token:
        print("⏭  跳过 Telegram（未设置 BOGS_PUB_TOKEN）。")
        return
    print("📣 推送到 Telegram（经阿里云中继）...")
    preview = re.sub(r'[#*`>\[\]!]', '', md_text)[:200].strip()
    if len(md_text) > 200:
        preview += "..."
    resp = requests.post(
        "http://47.85.62.133:8787/push_telegram",
        headers={"Authorization": f"Bearer {relay_token}",
                 "Content-Type": "application/json"},
        json={"title": title, "excerpt": preview,
              "wp_link": wp_link, "wx_url": wx_url, "mp_name": src_label},
        timeout=30)
    if resp.ok and resp.json().get("ok"):
        print("✅ Telegram 已推送（经阿里云中继）")
    else:
        print(f"⚠️ Telegram 推送失败：{resp.text}")


# ---------- 发布到 WordPress ----------
def wp_publish(title, html, excerpt=""):
    print("📤 发布到 WordPress（hellobog.com）...")
    payload = {"title": title, "content": html, "status": "publish"}
    if excerpt:
        payload["excerpt"] = excerpt
    resp = requests.post(
        f"{WP_URL}/wp-json/wp/v2/posts",
        auth=(WP_USER, WP_PASS),
        json=payload,
        timeout=60)
    resp.raise_for_status()
    return resp.json().get("link", WP_URL)


# ---------- 归档到 GitHub ----------
def gh_archive(title, md_text):
    print("📦 归档到 GitHub ...")
    slug = re.sub(r'[\s/|:*?<>"\\]+', "-", title).strip("-")[:50]
    fn = f"notes/{date.today().isoformat()}-{slug}.md"
    front = (f"---\ntitle: \"{title}\"\ndate: {date.today().isoformat()}\n"
             f"source: wechat-pub2gg\n---\n\n")
    b64 = base64.b64encode((front + md_text).encode("utf-8")).decode("ascii")
    resp = requests.put(
        f"https://api.github.com/repos/{GH_REPO}/contents/{fn}",
        headers={"Authorization": f"token {GH_TOKEN}"},
        json={"message": f"pub2gg: {title}", "content": b64},
        timeout=60)
    if resp.status_code in (200, 201):
        return fn
    raise RuntimeError(resp.json().get("message", "未知错误"))


# ---------- 主流程 ----------
def main():
    url = get_url()
    if "mp.weixin.qq.com" not in url:
        die("剪贴板里不是微信公众号文章链接。请先复制 https://mp.weixin.qq.com/s/... 再运行。")

    title, name, content, digest = fetch_article(url)
    print(f"📄 标题：{title}")
    print(f"📰 来源：{name or '（未识别公众号名）'}")
    if digest:
        print(f"📝 摘要：{digest[:60]}{'...' if len(digest)>60 else ''}")

    process_images(content)

    src_label = name or "我的公众号"
    html_footer = (f'<hr/><p>本文首发于微信公众号【{src_label}】，'
                   f'<a href="{url}">点击查看原文</a>。</p>')
    md_footer = (f"\n\n---\n\n> 本文首发于微信公众号【{src_label}】，"
                 f"[点击查看原文]({url})。\n")

    inner_html = content.decode_contents()
    wp_html = inner_html + html_footer
    md_text = html_to_md(inner_html, heading_style="ATX").strip() + md_footer

    # WordPress 发布
    wp_link = ""
    if WP_USER and WP_PASS:
        try:
            wp_link = wp_publish(title, wp_html, digest)
            print(f"✅ WordPress 已发布：{wp_link}")
        except Exception as e:
            print(f"⚠️ WordPress 发布失败：{e}")
    else:
        print("⏭  跳过 WordPress（未设置 BOGS_WP_USER / BOGS_WP_APPPASS）。")

    # GitHub 归档
    if GH_TOKEN:
        try:
            fn = gh_archive(title, md_text)
            print(f"✅ GitHub 已归档：{fn}")
            print(f"🔗 github.com/{GH_REPO}/blob/main/{fn}")
        except Exception as e:
            print(f"⚠️ GitHub 归档失败：{e}")
    else:
        print("⏭  跳过 GitHub（未设置 BOGS_GH_TOKEN）。")

    # Telegram 推送
    tg_push(title, wp_link, url, src_label, md_text)

    print("\n🎉 pub2gg 完成。")


if __name__ == "__main__":
    try:
        main()
    except requests.HTTPError as e:
        die(f"网络请求失败：{e}")
    except KeyboardInterrupt:
        die("已取消。")
