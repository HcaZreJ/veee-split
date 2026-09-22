# Veee 分流助手

给 Veee+ 加上自动分流：挂着 Veee 全局的同时，国内网站自动不走代理——直连、快、用的是国内 IP。装完之后不需要碰终端。

## 它解决什么

- Veee 全局模式下，国内网站很慢甚至打不开；关掉 Veee 又上不了外网 → 装完后两边同时正常
- 每次在 Veee 里切节点，代理设置会被 Veee 抢走 → 后台守护自动抢回来，全程无感
- 哪些网站算「国内网站」由一份清单决定，你的 Claude 可以直接帮你加

## 安装（一次性，不用碰终端）

1. 打开 Veee，登录，连接任意一个节点
2. 打开 Claude 桌面版，点「Code」，随便选一个文件夹（比如「下载」）
3. 把 [prompt-for-claude.md](prompt-for-claude.md) 里那一整段话复制粘贴发给它，它请求运行命令时点「允许」

接下来按你的 Claude 说的做——它会自己跑安装命令，然后问你常用哪些国内网站并全部配好。以后想加网站，随时新开一个 Code 会话说「帮我把 xxx 网站加到国内直连」就行。

<details>
<summary>会用终端的人的备用方式</summary>

打开 Veee 连上节点后，在终端里运行：

```
/bin/bash -c "$(curl -fsSL -x http://127.0.0.1:15236 https://raw.githubusercontent.com/HcaZreJ/veee-split/main/install.command)"
```

拿到的是 zip 压缩包的话：解压后双击 `install.command` 也一样；被系统拦下就右键点它 → 打开 → 打开。
</details>

## 日常使用

| 你做什么 | 发生什么 |
|---|---|
| 正常上网 | 国内网站直连（快），其余走 Veee |
| 用只限美国 / 新加坡 / 台湾的网站 | 照旧在 Veee 里切到对应节点，别的不用动 |
| 用必须国内访问的网站 | 什么都不用做，它本来就直连；没生效就把域名加进清单（见下） |
| 关掉 Veee | 全部自动恢复直连 |

## 加「直连的国内网站」

对你的 Claude 说：**「帮我把 xxx 网站加到国内直连」**。

你的 Claude 会读 `~/.veee-split/CLAUDE.md`，按里面的流程做——不只加主域名，还会把这个网站放视频、图片用的一整族域名都找齐加全（只加主域名的话内容还是卡）。

也可以自己打开终端输入：`veee-split add-direct 网站域名`

## 出问题了

打开「终端」（启动台里搜 terminal），输入 `veee-split` 回车，把输出发给你的 Claude 或发给我。

## 卸载

双击 `uninstall.command`，然后在 Veee 里重连一次节点。
