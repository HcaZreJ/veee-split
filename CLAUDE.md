# Veee 分流助手

这台 Mac 装有「Veee 分流助手」：mihomo 监听 127.0.0.1:7890 做国内外分流——国内清单里的域名直连（国内 IP、速度快），其余流量走 Veee+ VPN 的本地 HTTP 代理 127.0.0.1:15236；系统代理指向 7890。机主不懂代码——替她执行命令，并用大白话解释结果。

## 安装位置

| 路径 | 内容 |
|---|---|
| `~/.veee-split/cn-domains.yaml` | 国内网站清单（rule-provider，机主最常改的文件） |
| `~/.veee-split/config.yaml` | mihomo 主配置（引用上面的清单，兜底规则 GEOIP,CN 直连） |
| `~/.veee-split/scripts/proxy-guard.sh` | 守护脚本：Veee 每次连接/切节点/断开都会触发它（launchd WatchPaths 监听系统网络配置 + 45 秒定时兜底），把系统代理纠正回 7890；Veee 离线时关闭系统代理 |
| `~/.veee-split/logs/` | `mihomo.log` 与 `guard.log` |
| `~/Library/LaunchAgents/local.veee-split.{mihomo,guard}.plist` | 两个后台服务 |
| `~/.local/bin/veee-split` | 命令行工具 |

## 常用操作

- 看状态与连通性：`~/.local/bin/veee-split status`
- 加国内网站：`~/.local/bin/veee-split add-direct 域名`（自动剥掉 `http://`、路径与 `www.` 前缀，加进清单并重载）
- 手工改过 yaml 后生效：`~/.local/bin/veee-split reload`（先用 ruby 校验 YAML、再 `mihomo -t`，任一失败都不会动正在运行的服务）
- 暂停 / 恢复接管系统代理：`veee-split pause` / `veee-split resume`
- 完整体检：`veee-split doctor`

## 改配置的规则

- 加国内网站只改 `cn-domains.yaml`：`payload:` 下加一行 `- '+.域名'`。
- `.cn` 结尾的域名已被 `'+.cn'` 覆盖；清单没列到的国内域名由 `GEOIP,CN` 规则按 IP 兜底，多数国内网站不加清单也能直连——机主说某网站慢时才需要把它的域名（含 CDN 域名）加进来。
- 端口 7890 / 15236、`allow-lan: false`、LaunchAgent 的 Label 保持现值；Veee.app 本体保持原样。
- 改完任何 yaml 都跑 `veee-split reload`。

## 排障路径

1. `veee-split doctor`：两个服务的状态、端口、系统代理、最近日志一次看全。
2. 外网打不开：先确认 Veee 在线并已连接节点（`veee-split status` 第一行）。
3. 国内某网站慢：它的流量走了 Veee——用 `grep 该域名 ~/.veee-split/logs/mihomo.log` 看路由决策，把相关域名 `add-direct` 进清单。
4. 系统代理不是 127.0.0.1:7890：`veee-split resume`（清掉暂停标记并立即纠正）；守护的定时兜底最迟 45 秒也会自动纠正。
