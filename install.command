#!/bin/bash
# Veee 分流助手 · 安装器
# 双击运行；如被系统拦下：右键点它 → 打开 → 打开。
# 也可以在终端运行: bash install.command
set -u

BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; CYAN=$'\033[36m'; NC=$'\033[0m'
step() { printf '\n%s▸ %s%s\n' "$CYAN" "$1" "$NC"; }
ok()   { printf '%s✓%s %s\n' "$GREEN" "$NC" "$1"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$NC" "$1"; }
finish_prompt() { if [ -t 0 ]; then printf '\n按回车键关闭窗口…'; read -r; fi; }
die()  { printf '\n%s✗ %s%s\n' "$RED" "$1" "$NC"; [ -n "${2:-}" ] && printf '%s\n' "$2"; finish_prompt; exit 1; }

listening() { lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }

ROOT="$HOME/.veee-split"
SRC="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
ARCH="$(uname -m)"
MIHOMO_VERSION="v1.19.25"
VEEE_PROXY="http://127.0.0.1:15236"
REPO_RAW="https://raw.githubusercontent.com/HcaZreJ/veee-split/main"
UID_N="$(id -u)"
LA="$HOME/Library/LaunchAgents"

# 取一个包文件：本地包里有就用本地的（zip 双击场景），
# 没有就从 GitHub 经 Veee 下载（curl 一行安装场景）。
fetch() {
  if [ -n "$SRC" ] && [ -f "$SRC/$1" ]; then
    cp "$SRC/$1" "$2"
  else
    curl -fsSL --retry 3 -m 120 -x "$VEEE_PROXY" -o "$2" "$REPO_RAW/$1"
  fi
}

printf '%s══════════ Veee 分流助手 · 安装 ══════════%s\n' "$BOLD" "$NC"

[ "$(uname)" = "Darwin" ] || die "本工具只支持 macOS"

step "检查 Veee"
if ! listening 15236; then
  open -a Veee 2>/dev/null
  warn "Veee 还没连接。请在 Veee 里连接任意一个节点，我等你 60 秒…"
  i=0
  while [ "$i" -lt 60 ]; do
    sleep 2; i=$((i+2))
    listening 15236 && break
  done
fi
listening 15236 || die "Veee 还没有连接" "请打开 Veee、登录并连接任意一个节点，然后重新运行本安装器。"
ok "Veee 在线"

step "检查端口 7890"
if listening 7890; then
  if launchctl print "gui/$UID_N/local.veee-split.mihomo" >/dev/null 2>&1; then
    warn "检测到已安装的 Veee 分流助手，覆盖安装"
    launchctl bootout "gui/$UID_N/local.veee-split.mihomo" 2>/dev/null
    launchctl bootout "gui/$UID_N/local.veee-split.guard" 2>/dev/null
    sleep 1
  else
    owner="$(lsof -nP -iTCP:7890 -sTCP:LISTEN 2>/dev/null | awk 'NR==2{print $1}')"
    die "端口 7890 已被程序「${owner:-未知}」占用" "如果之前用 Homebrew 装过 mihomo：先运行 brew services stop mihomo，再重新运行本安装器。"
  fi
fi
ok "端口可用"

step "安装文件到 ~/.veee-split"
mkdir -p "$ROOT/bin" "$ROOT/scripts" "$ROOT/logs" "$HOME/.local/bin" "$LA"

if fetch "assets/mihomo-darwin-$ARCH.gz" "$ROOT/bin/mihomo.gz" 2>/dev/null; then
  gunzip -f "$ROOT/bin/mihomo.gz" || die "解压 mihomo 失败"
else
  warn "仓库里没有 $ARCH 架构的 mihomo，从 MetaCubeX 官方下载…"
  url="https://github.com/MetaCubeX/mihomo/releases/download/$MIHOMO_VERSION/mihomo-darwin-$ARCH-$MIHOMO_VERSION.gz"
  curl -fL --retry 3 -m 300 -x "$VEEE_PROXY" -o "$ROOT/bin/mihomo.gz" "$url" \
    || die "下载 mihomo 失败" "确认 Veee 联网正常后重试。"
  gunzip -f "$ROOT/bin/mihomo.gz" || die "解压 mihomo 失败"
fi
chmod +x "$ROOT/bin/mihomo"
xattr -d com.apple.quarantine "$ROOT/bin/mihomo" 2>/dev/null
"$ROOT/bin/mihomo" -v >/dev/null 2>&1 || die "mihomo 无法在本机运行（架构: $ARCH）"
ok "mihomo 已就位（$("$ROOT/bin/mihomo" -v 2>/dev/null | head -1 | awk '{print $1, $2, $3}')）"

fetch "assets/geoip.metadb" "$ROOT/geoip.metadb" \
  || die "下载 geoip 数据库失败" "确认 Veee 联网正常后重试。"
ok "geoip 数据库已就位"

fetch "config.yaml" "$ROOT/config.yaml" || die "获取 config.yaml 失败"
if [ -f "$ROOT/cn-domains.yaml" ]; then
  warn "保留你已有的国内网站清单（cn-domains.yaml）"
else
  fetch "cn-domains.yaml" "$ROOT/cn-domains.yaml" || die "获取 cn-domains.yaml 失败"
fi
fetch "scripts/proxy-guard.sh" "$ROOT/scripts/proxy-guard.sh" || die "获取 proxy-guard.sh 失败"
chmod +x "$ROOT/scripts/proxy-guard.sh"
fetch "CLAUDE.md" "$ROOT/CLAUDE.md" || die "获取 CLAUDE.md 失败"
fetch "bin/veee-split" "$HOME/.local/bin/veee-split" || die "获取 veee-split 失败"
chmod +x "$HOME/.local/bin/veee-split"

# 挂进 Claude Code 的全局记忆：以后任何新会话天然认识本工具，
# 用户直接说「帮我把 xxx 加到国内直连」即可。
GCM="$HOME/.claude/CLAUDE.md"
mkdir -p "$HOME/.claude"
if ! grep -qs 'veee-split/CLAUDE.md' "$GCM"; then
  printf '\n# veee-split（安装器自动添加，卸载器会移除）\n@~/.veee-split/CLAUDE.md\n' >> "$GCM"
fi
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) grep -qs 'local/bin' "$HOME/.zprofile" 2>/dev/null \
       || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zprofile" ;;
esac
ok "配置与 veee-split 命令已安装"

step "校验分流配置"
if ! "$ROOT/bin/mihomo" -d "$ROOT" -t >/dev/null 2>&1; then
  "$ROOT/bin/mihomo" -d "$ROOT" -t 2>&1 | tail -5
  die "分流配置未通过校验"
fi
ok "配置校验通过"

step "登记后台服务（开机自动运行）"
for name in mihomo guard; do
  tpl="$ROOT/launchd-$name.plist.tpl"
  plist="$LA/local.veee-split.$name.plist"
  fetch "launchd/local.veee-split.$name.plist" "$tpl" || die "获取 launchd/$name 模板失败"
  sed "s|__HOME__|$HOME|g" "$tpl" > "$plist"
  rm -f "$tpl"
  plutil -lint "$plist" >/dev/null || die "生成的 $name 服务描述无效"
  launchctl bootout "gui/$UID_N/local.veee-split.$name" 2>/dev/null
  launchctl bootstrap "gui/$UID_N" "$plist" || die "加载 $name 后台服务失败"
done
ok "两个后台服务已启动"

step "等待 mihomo 就绪"
i=0
until listening 7890; do
  i=$((i+1))
  [ "$i" -gt 10 ] && die "mihomo 未监听 7890" "查看日志: cat ~/.veee-split/logs/mihomo.log"
  sleep 1
done
ok "mihomo :7890 就绪"

step "接管系统代理"
/bin/bash "$ROOT/scripts/proxy-guard.sh"
ok "系统代理 → 127.0.0.1:7890（国内直连，其余走 Veee）"

step "连通性测试"
code=$(curl -sm 8 -o /dev/null -w '%{http_code}' -x http://127.0.0.1:7890 https://www.google.com/robots.txt 2>/dev/null)
if [ "$code" = "200" ]; then
  ok "google 可访问"
else
  warn "google 测试失败（$code）— 检查 Veee 是否联网正常"
fi
code=$(curl -sm 8 -o /dev/null -w '%{http_code}' -x http://127.0.0.1:7890 https://www.baidu.com 2>/dev/null)
case "$code" in
  200|301|302) ok "baidu 可访问" ;;
  *)           warn "baidu 测试失败（$code）" ;;
esac

printf '\n%s══════════ 安装完成 ══════════%s\n' "$GREEN$BOLD" "$NC"
cat <<'EOF'

以后什么都不用做：
  · 国内网站自动直连（快、用国内 IP），其余走 Veee
  · 在 Veee 里随便切节点（美国 / 新加坡 / 台湾），代理被 Veee 抢走会自动抢回
  · 关掉 Veee：自动恢复全部直连

┌────────────────────────────────────────────────────────┐
│  下一步                                                │
│  · 这次安装是 Claude 替用户执行的 → Claude 现在就读    │
│    ~/.veee-split/CLAUDE.md，开始「首次配置访谈」。     │
│  · 是人自己运行的 → 把这句话发给你的 Claude：          │
│    「请阅读 ~/.veee-split/CLAUDE.md，按里面的首次      │
│    配置访谈帮我把常用的国内网站配置成直连。」          │
│                                                        │
│  以后想加网站，直接对 Claude 说：                      │
│  「帮我把 xxx 网站加到国内直连」                       │
└────────────────────────────────────────────────────────┘

遇到问题：打开「终端」，输入 veee-split 回车，把输出发给你的 Claude。
EOF
finish_prompt
