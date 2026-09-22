# Veee 分流助手

这台 Mac 装有「Veee 分流助手」：mihomo 监听 127.0.0.1:7890 做国内外分流——国内清单里的域名直连（国内 IP、速度快），其余流量走 Veee+ VPN 的本地 HTTP 代理 127.0.0.1:15236；系统代理指向 7890，由后台守护自动维持。机主不懂代码——所有命令都由你亲自执行（用你的终端工具），并用大白话解释结果；机主的操作只限于在 Veee 或 Claude 界面里点击。命令都用绝对路径 `~/.local/bin/veee-split` 执行，避免 PATH 问题。

## 首次配置访谈

机主让你按本文件做首次配置时：

1. 跑 `~/.local/bin/veee-split status`，用一句大白话告诉她现状（Veee 是否在线、分流是否工作、国内外网站是否都通）。
2. 问她：「你平时有哪些必须用国内网络访问的网站或 App？比如视频、购物、银行、12306 这类，把名字或网址发我就行。」
3. 预置清单已含约 100 条常见国内域名，`.cn` 结尾的域名和国内 IP 都有兜底——她说的站先逐个核对（`grep -i 关键词 ~/.veee-split/cn-domains.yaml`），已覆盖的直接告诉她本来就生效。
4. 未覆盖的网站按下面的「域名族扩展」加全。
5. 全部加完后再跑一次 status 收尾，并告诉她：以后想加，直接说「帮我把 xxx 网站加到国内直连」。

## 域名族扩展（加站纪律）

只加主域名通常没用：网站的实际内容（视频、图片、接口）走另外的 CDN 与接口域名，漏掉它们照样卡。例：只加 douyin.com 不够，抖音的视频在 douyinvod.com、图片在 douyinpic.com，还依赖 iesdouyin.com、amemv.com、snssdk.com、byteimg.com、ibytedtos.com、pstatp.com 等一整族域名。

每次加站走三步：

1. **先凭你对这家产品的知识把域名族列全**（主域名 + 它的 CDN 域名 + 接口/静态资源域名），一次加完：
   `~/.local/bin/veee-split add-direct 域名1 域名2 域名3 …`
2. **实测补漏**：跑 `~/.local/bin/veee-split trace 30`，让机主在这 30 秒里打开并使劲刷那个网站/App。输出会列出这段时间「走 Veee 的域名」及次数——其中属于这家网站或它专用 CDN 的（看域名归属和命名就能判断，拿不准就查一下这个域名是谁家的），补加进去。多轮 trace 直到该站相关域名不再出现在「走 Veee」一栏。
3. **只加在国内能直连的域名**：这家公司自己的域名、它的专用 CDN 子域可以加；第三方通用域名（google/facebook 的统计脚本、境外通用 CDN 等）在国内直连不通，就算出现在 trace 里也要留在 Veee 一侧。对拿不准的域名加完做个连通测试：
   `curl -sm 6 -o /dev/null -w '%{http_code}' -x http://127.0.0.1:7890 https://该域名/`
   返回 000 或超时 → 打开 `~/.veee-split/cn-domains.yaml` 删掉对应行，跑 `~/.local/bin/veee-split reload`。（403/404 也算通，说明链路没问题。）

## 安装位置

| 路径 | 内容 |
|---|---|
| `~/.veee-split/cn-domains.yaml` | 国内网站清单（rule-provider，最常改的文件） |
| `~/.veee-split/config.yaml` | mihomo 主配置（引用上面的清单，兜底规则 GEOIP,CN 直连） |
| `~/.veee-split/scripts/proxy-guard.sh` | 守护脚本：Veee 每次连接/切节点/断开都会触发（launchd WatchPaths + 45 秒定时兜底），把系统代理纠正回 7890；Veee 离线时关系统代理全直连 |
| `~/.veee-split/logs/` | `mihomo.log`（每条连接的路由决策）与 `guard.log` |
| `~/Library/LaunchAgents/local.veee-split.{mihomo,guard}.plist` | 两个后台服务 |
| `~/.local/bin/veee-split` | 命令行工具 |

## 常用操作

- 看状态与连通性：`~/.local/bin/veee-split status`
- 加国内网站（可多个）：`~/.local/bin/veee-split add-direct 域名…`（自动剥掉 `http://`、路径与 `www.` 前缀，加进清单并重载）
- 抓真实流量找漏网域名：`~/.local/bin/veee-split trace 30`
- 手工改过 yaml 后生效：`~/.local/bin/veee-split reload`（先用 ruby 校验 YAML、再 `mihomo -t`，任一失败都不会动正在运行的服务）
- 暂停 / 恢复接管系统代理：`veee-split pause` / `veee-split resume`
- 完整体检：`veee-split doctor`

## 改配置的规则

- 加国内网站只改 `cn-domains.yaml`：`payload:` 下加一行 `- '+.域名'`（`+.` 含所有子域名）。
- `.cn` 结尾的域名已被 `'+.cn'` 覆盖；清单没列到的国内域名由 `GEOIP,CN` 按解析 IP 兜底——机主说某网站慢时才需要按域名族补清单。
- 端口 7890 / 15236、`allow-lan: false`、LaunchAgent 的 Label 保持现值；Veee.app 本体保持原样。
- 改完任何 yaml 都跑 `veee-split reload`。

## 排障路径

1. `veee-split doctor`：两个服务的状态、端口、系统代理、最近日志一次看全。
2. 外网打不开：先确认 Veee 在线并已连接节点（status 第一行）。
3. 国内某网站慢：按「域名族扩展」的 trace 流程找出走了 Veee 的相关域名补进清单。
4. 系统代理不是 127.0.0.1:7890：`veee-split resume`（清掉暂停标记并立即纠正）；守护的定时兜底最迟 45 秒也会自动纠正。
