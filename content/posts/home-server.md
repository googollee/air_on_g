---
title: "我是如何配置Home Server的"
date: 2024-06-10T14:51:00+02:00
categories:
 - 开发
tags:
 - ops
 - security
 - home-server
cover:
  image: /images/home-server-cover.jpg
author: "Googol Lee"
---

起因是要在公司分享我自建home server的经验。反正都要写,就直接写一篇blog来记录这十多年使用nas/home server的经历。

<!--more-->

### 早期的NAS经验

我已经不记得最早是什么时候开始使用nas的.印象里2012年在上海时就有过一个arm cpu的nas.当时主要使用samba提供网络文件服务,用来下载并保存一些高清电影和动画.当时使用的是QNAP的某个入门型号,双盘位,8T x2组成raid1.软件都是从QNAP自己内置的软件市场下载,所以只能选QNAP自己打包过的程序.机器性能也就够跑个文件存储和下载.NAS本身不负责播放,而是通过网络传输文件到电脑进行播放.下载使用Transmission,媒体库使用Plex.

![QNAP TS-251](/images/qnap-ts251.png)

后来随着intel atom cpu普及,应该是在2015年前后,我把nas更新到了QNAP TS-251,使用Intel Celeron J1400 CPU.后来在某个时期,QNAP的系统更新了对Docker的支持,我就把下载软件和媒体库软件,从QNAP市场改成了自己配置的Docker Compose进行下载和部署.这样部署的软件以及版本都会灵活很多,不用等QNAP打包,可以自由选择。不过我也比较懒,依旧沿用了Transmission和Plex,只是升级到了最新版.这台机器用了非常久,还被我带到德国用了几年.直到在2022年,机器出现了Intel C2000的问题,无法正常开机.由于维修C2000非常麻烦,好像需要短接CPU针脚,我干脆放弃了这台机器,换成了QNAP TS-251D.

![QNAP TS-251D](/images/qnap-ts251d.png)

QNAP TS-251D的CPU是J4025,相对来说性能强了不少.随着使用习惯的变化,上面部署的软件也变成了qBittorrent+Jellyfin的组合.这个硬件一直使用到现在.只不过QNAP自己的系统在使用中的局限性越来越多,我现在通过外接引导硬盘安装了更加通用的Linux发行版.所有的软件也都是在新的Linux环境里运行.后面会主要介绍我是怎么搭建这个Linux环境的.

### 当前的NAS aka Home Server

![Home Server](/images/my-home-server.jpg)

照片上边的小黑盒就是外接的启动硬盘.操作系统使用的是[Fedora IoT](https://fedoraproject.org/iot/).选用这个系统的原因是,这是一个[不可变Linux发行版](https://kairos.io/blog/2023/03/22/understanding-immutable-linux-os-benefits-architecture-and-challenges/#what-is-an-immutable-linux-os).我为了偷懒启用了升级.如果升级导致系统无法启动,可以直接用旧分区启动并进行修复.这个操作系统上只装了尽可能少的服务:k3s,samba，cockpit,vm.具体细节可以看[初始化文件](https://github.com/googollee/my_sys/blob/main/home-cluster/00-init.sh).

其余的服务都会通过[k3s](https://k3s.io/)这个[k8s](https://kubernetes.io/)发行版来维护.k3s是一个致力于最小化资源占用的k8s发行版.因为我自己的环境只有性能不强的单机,完全不考虑高可用以及其他运相关的服务,使用k3s非常合适.按照k3s官网描述,最小资源只需要1 core + 512MiB.

### 网络

![Home Network](/images/home-network-config.png)

上图是家里网络的配置方案.NAS会暴露两个端口`443`和`8443`,其中`443`用于本地网络的访问,`8443`用于外网的访问.两者在HTTP Gateway Proxy上有区别,`8443`会对所有`*-p.zhaohai.li`的url多一次`HTTP Basic Auth`.最终效果是,访问`*-p.zhaohai.li`的网站,内网访问不需要认证,而外网访问,需要通过设置的HTTP Auth认证.

### 服务

除了cockpit/vm需要访问宿主机的状态,samba为了提高效率,以及一些常用的工具外,其余服务全部跑在k3s里.使用k3s默认的traefik作为ingress controller,增加新的8443端口,以及8443->443的转发路由和Basic Auth.其余服务分为证书管理,监控和一般服务.
#### 证书管理

使用[`cert-manager`](https://cert-manager.io/),通过[Let's Encrypt](https://letsencrypt.org/)获取HTTPS证书.cert-manager会根据ingress的配置,自动把对应的证书插入到traefik里.

#### 监控

使用Grafana全家桶做监控,分别是:

- [Grafana Agent](https://grafana.com/oss/agent/),管理监控数据
  - 抓取exporter,k3s集群本身,k3s执行的服务以及其他相关指标,并存入Prometheus
  - 抓取路由器的snmp指标,并存入Prometheus
  - 抓取k3s服务的日志输出,并存入Loki
  - 官方已弃用,替换成[Alloy](https://grafana.com/oss/alloy-opentelemetry-collector/).有空再说吧
- [Prometheus](https://prometheus.io/),保存7天的指标数据
- [node exporter](https://github.com/prometheus/node_exporter),暴露宿主机的资源指标
- [smart exporter](https://github.com/cloudandheat/prometheus_smart_exporter),暴露宿主机的硬盘指标
- [Loki](https://grafana.com/oss/loki/),保存7天的日志
- [Grafana](https://grafana.com/oss/grafana/),数据看板

因为懒,没有做告警设置.反正机器崩了自己就知道了.`-_-`

#### 一般服务

一般服务都由[FluxCD](https://fluxcd.io/),自动从[GitHub](https://github.com/googollee/my_sys/tree/main/home-cluster/services)进行部署.实现了完整的GitOps流程.

目前跑的服务有:

- [qBittorrent](https://www.qbittorrent.org/),BT下载,可以通过RSS订阅种子并自动下载(用于追番)
- [Jellyfin](https://jellyfin.org/),完全开源的媒体数据库,可以自动刮削媒体信息,也支持硬件编解码
  - `J4025`可以支持一路视频的硬件编解码
- [GoToSocial](https://gotosocial.org/),轻量化的[Mastodon](https://joinmastodon.org/)服务,开源且分布式的类Twitter服务.
- [Home Assistant](https://www.home-assistant.io/),开源智能家居服务器
  - 通过[Sonoff Zigbee Dongle E](https://sonoff.tech/product/gateway-and-sensors/sonoff-zigbee-3-0-usb-dongle-plus-e/)支持Zigbee协议
- [inadyn](https://github.com/troglobit/inadyn),动态域名,更新`zhaohai.li`指向家庭ip
- [Node-RED](https://nodered.org/),低代码事件驱动服务,用于设置`if-this-then-that`
  - 但其实啥都没写
- [Nocodb](https://nocodb.com/),轻量化网络表格,用来代替Notion.
  - 但其实啥都没写
- [PhototView](https://photoview.github.io/),照片展示服务,可以根据目录自动创建相册
  - 方便和LightRoom Classic配合使用
  - 甚至帮他们修了[Bug](https://github.com/photoview/photoview/pull/954)

### 未来

目前的配置,其实已经不依赖任何NAS品牌提供的技术,完全可以使用成本更低更灵活的通用主机.设想的方案是主机和存储分离,使用USB4 M2硬盘盒+M2转SATA+硬盘笼的方式,自己搭建一个USB4多盘硬盘笼,并逐步替换成SSD(氦气硬盘实在太吵了!).主机直接购买目前流行的迷你主机并限制功耗.如果年底AI PC普及,可以更新为支持NPU的迷你主机,并逐步尝试本地执行LLM的功能.

网络方面可能会更换为[Unifi Cloud Gateway Ultra](https://ui.com/eu/en/cloud-gateways/compact),并配合Unifi AP提供无线热点.Unifi的设备我已经用了很长时间,稳定性和带机量都相当强.换Cloud Gateway Ultra目的是为了能更好的划分本地网络,并启动多热点来分配网络.
