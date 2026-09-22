# Veee 分流助手

这台 Mac 装有「Veee 分流助手」：mihomo 监听 127.0.0.1:7890 做国内外分流，上游是 Veee+ VPN 的本地 HTTP 代理 127.0.0.1:15236，系统代理指向 7890。机主不懂代码——替她执行命令，并用大白话解释结果。

## 安装位置

| 路径 | 内容 |
|---|---|
| `~/.veee-split/cn-domains.yaml` | 国内网站清单（两个分流模式共用的 rule-provider） |
| `~/.veee-split/profile-foreign-node.yaml` | 海外节点模式：清单内直连、其余走 Veee |
| `~/.veee-split/profile-cn-node.yaml` | 国内节点模式：清单内走 Veee（拿国内 IP）、其余直连 |
| `~/.veee-split/config.yaml` | 符号链接，指向当前生效的 profile，由守护脚本按 Veee 出口国家自动切换 |
| `~/.veee-split/scripts/proxy-guard.sh` | 守护脚本：Veee 每次连接/切节点/断开都会触发它（launchd WatchPaths 监听系统网络配置 + 45 秒定时兜底） |
| `~/.veee-split/logs/` | `mihomo.log` 与 `guard.log` |
| `~/Library/LaunchAgents/local.veee-split.{mihomo,guard}.plist` | 两个后台服务 |
| `~/.local/bin/veee-split` | 命令行工具 |

## 常用操作

- 看状态与连通性：`~/.local/bin/veee-split status`
- 加国内网站：`~/.local/bin/veee-split add-direct 域名`（自动剥掉 `http://`、路径与 `www.` 前缀，加进清单并重载）
- 手工改过 yaml 后生效：`~/.local/bin/veee-split reload`（先 `mihomo -t` 校验，失败不会重启服务）
- 暂停 / 恢复接管系统代理：`veee-split pause` / `veee-split resume`
- 完整体检：`veee-split doctor`

## 改配置的规则

- 加国内网站只改 `cn-domains.yaml`（`payload:` 下加一行 `- '+.域名'`），两个 profile 同时生效。
- `.cn` 结尾的域名已被 `'+.cn'` 覆盖；清单没列到的国内域名由 `GEOIP,CN` 规则按 IP 兜底。
- 端口 7890 / 15236、`allow-lan: false`、LaunchAgent 的 Label 保持现值；Veee.app 本体保持原样。
- 改完任何 yaml 都跑 `veee-split reload`。

## 排障路径

1. `veee-split doctor`：两个服务的状态、端口、系统代理、最近日志一次看全。
2. 国外网站打不开：先确认 Veee 在线、看当前是不是国内节点模式（国内节点下国外网站走直连，能否访问取决于她所在的网络环境）。
3. 切了节点分流没跟上：等 45 秒（定时兜底会纠正），或手动跑 `bash ~/.veee-split/scripts/proxy-guard.sh` 后再看 `veee-split status`。
4. 系统代理不是 127.0.0.1:7890：`veee-split resume`（清掉暂停标记并立即纠正）。
