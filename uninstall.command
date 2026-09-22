#!/bin/bash
# Veee 分流助手 · 卸载器：移除后台服务与全部文件，把系统代理交还给 Veee。
set -u
UID_N="$(id -u)"

for name in mihomo guard; do
  launchctl bootout "gui/$UID_N/local.veee-split.$name" 2>/dev/null
  rm -f "$HOME/Library/LaunchAgents/local.veee-split.$name.plist"
done

networksetup -listallnetworkservices 2>/dev/null | tail -n +2 | while IFS= read -r svc; do
  case "$svc" in \**) continue ;; esac
  networksetup -setwebproxystate "$svc" off
  networksetup -setsecurewebproxystate "$svc" off
  networksetup -setsocksfirewallproxystate "$svc" off
done

rm -rf "$HOME/.veee-split"
rm -f "$HOME/.local/bin/veee-split"

echo "✓ 已卸载。在 Veee 里重新连接一次节点，即回到 Veee 自带的全局模式。"
if [ -t 0 ]; then printf '按回车键关闭窗口…'; read -r; fi
