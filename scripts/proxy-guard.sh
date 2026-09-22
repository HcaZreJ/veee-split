#!/bin/bash
# 让系统代理始终指向 mihomo(:7890)。
# launchd 在系统网络配置变化时调用（Veee 连接/切节点/断开都会改写系统代理），
# 另有 45 秒定时兜底。
#   Veee 在线 → 系统代理 = 127.0.0.1:7890（mihomo 分流：国内直连，其余走 Veee）
#   Veee 离线 → 关闭系统代理（全部直连）
# ~/.veee-split/paused 存在时不做任何事（由 veee-split pause / resume 控制）。

ROOT="$HOME/.veee-split"
LOG="$ROOT/logs/guard.log"
MIHOMO_PORT=7890
VEEE_PORT=15236
MIHOMO_LABEL="local.veee-split.mihomo"

[ -f "$ROOT/paused" ] && exit 0
mkdir -p "$ROOT/logs"

# 单实例锁：launchd 定时触发与事件触发可能撞车，并发跑会互相覆盖 networksetup 写入。
# 已有存活实例在跑就让它做完，45 秒定时兜底保证最终一致。
LOCK="$ROOT/guard.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  otherpid="$(cat "$LOCK/pid" 2>/dev/null)"
  if [ -n "$otherpid" ] && kill -0 "$otherpid" 2>/dev/null; then
    exit 0
  fi
  rm -rf "$LOCK"
  mkdir "$LOCK" 2>/dev/null || exit 0
fi
echo $$ > "$LOCK/pid"
trap 'rm -rf "$LOCK"' EXIT
if [ -f "$LOG" ] && [ "$(stat -f%z "$LOG" 2>/dev/null || echo 0)" -gt 524288 ]; then
  tail -c 262144 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }
listening() { lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }

# Veee 开着但端口未就绪（正在连接或切换节点）→ 最多等 10 秒再判定
if ! listening "$VEEE_PORT" && pgrep -x Veee >/dev/null 2>&1; then
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    sleep 1
    listening "$VEEE_PORT" && break
  done
fi

if listening "$VEEE_PORT"; then
  if ! listening "$MIHOMO_PORT"; then
    launchctl kickstart -k "gui/$(id -u)/$MIHOMO_LABEL" 2>>"$LOG"
  fi
  for _ in 1 2 3 4 5; do
    listening "$MIHOMO_PORT" && break
    sleep 1
  done
  if listening "$MIHOMO_PORT"; then
    want=on
  else
    want=off
    log "mihomo 未能监听 :$MIHOMO_PORT，暂时关闭系统代理"
  fi
else
  want=off
fi

networksetup -listallnetworkservices 2>/dev/null | tail -n +2 | while IFS= read -r svc; do
  case "$svc" in \**) continue ;; esac   # 带 * 前缀的是已停用的网络服务
  web="$(networksetup -getwebproxy "$svc" 2>/dev/null)"
  socks="$(networksetup -getsocksfirewallproxy "$svc" 2>/dev/null)"
  if [ "$want" = on ]; then
    if echo "$web" | grep -q "Enabled: Yes" && echo "$web" | grep -q "^Port: $MIHOMO_PORT$" \
       && echo "$socks" | grep -q "Enabled: Yes" && echo "$socks" | grep -q "^Port: $MIHOMO_PORT$"; then
      continue
    fi
    networksetup -setwebproxy "$svc" 127.0.0.1 "$MIHOMO_PORT"
    networksetup -setsecurewebproxy "$svc" 127.0.0.1 "$MIHOMO_PORT"
    networksetup -setsocksfirewallproxy "$svc" 127.0.0.1 "$MIHOMO_PORT"
    networksetup -setwebproxystate "$svc" on
    networksetup -setsecurewebproxystate "$svc" on
    networksetup -setsocksfirewallproxystate "$svc" on
    log "[$svc] 系统代理 → 127.0.0.1:$MIHOMO_PORT"
  else
    if echo "$web" | grep -q "Enabled: No" && echo "$socks" | grep -q "Enabled: No"; then
      continue
    fi
    networksetup -setwebproxystate "$svc" off
    networksetup -setsecurewebproxystate "$svc" off
    networksetup -setsocksfirewallproxystate "$svc" off
    log "[$svc] Veee 离线，系统代理已关闭（全部直连）"
  fi
done
