---
title: "如何配置nas上的磁盘阵列"
date: 2024-10-27T09:16:50+01:00
categories:
 - 开发
 - 生活
tags:
 - nas
 - raid
 - operation
 - ops
cover:
  image: /images/nas-disk-array.jpg
author: "Googol Lee"
---

因为考虑要完全自己组装台NAS，需要练习一下如何创建并管理磁盘阵列。最近在虚拟机上学习了`mdadm`和`lvm`的使用方法。实践下来，`lvm`功能更多，更灵活，但基础raid的功能不完善，磁盘损坏时更新磁盘很繁琐。`mdadm`只能管理raid，但是更简单直观。考虑方便程度和使用场景，决定使用`mdadm`创建raid10阵列管理磁盘。

<!--more-->

## 写在前面

阵列的管理思路是，使用`mdadm`创建磁盘阵列，并将阵列格式化为`xfs`文件格式。如果有磁盘损坏，可以直接使用`mdadm`替换阵列的磁盘并进行恢复，不需要操作`xfs`。如果要进行扩容，需要先用`mdadm`将新磁盘加入阵列并扩展阵列容量，再将`xfs`扩容以便使用新磁盘。

在`mdadm`创建的阵列之上，还可以用`lvm`增加ssd加速功能，提高读写速度。由于`lvm`提供的raid10阵列功能，无法方便的在启用cache加速时更换失效磁盘，我能想到的方法是使用三层结构：

- `mdadm`：提供底层hdd的raid10阵列
- `lvm`：将raid10和ssd一起创建一个简单卷，并将ssd作为卷cache加速
- `xfs`：在lvm卷之上创建xfs

不过这种方式在扩容时非常麻烦，需要一层一层进行扩容，而且`lvm`需要先取消cache来扩容底层卷，再加回cache。这个过程稍有不慎就会破坏上层的`xfs`，导致数据丢失。所以我决定不使用这种方法。

## 创建阵列

### 创建raid10

创建raid可以通过`cockpit`存储界面提供的选项完成，选择`创建MDRAID设备`，并选择相应磁盘和raid等级即可。以下记录如何用命令行创建阵列。

假设存在磁盘`/dev/vd{b..e}`，4个容量为1GiB的hdd。

```sh
% lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
...
vdb    252:16   0    1G  0 disk
vdc    252:32   0    1G  0 disk
vdd    252:48   0    1G  0 disk
vde    252:64   0    1G  0 disk
# 创建raid10阵列
$ mdadm --create --verbose /dev/md/raid10 --level=10 --raid-devices=4 /dev/vd{b..e}
mdadm: layout defaults to n2
mdadm: layout defaults to n2
mdadm: chunk size defaults to 512K
mdadm: size set to 1046528K
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md/raid10 started.
$ cat /proc/mdstat 
Personalities : [raid10] 
md127 : active raid10 vde[3] vdd[2] vdc[1] vdb[0]
      2093056 blocks super 1.2 512K chunks 2 near-copies [4/4] [UUUU]

unused devices: <none>
```

### 创建xfs

将刚刚创建的raid10格式化为xfs。

```sh
# 格式化
% mkfs.xfs /dev/md/raid10
# 挂载并使用/dev/md/raid10
```

## 一块磁盘损坏，重建阵列 {#fix-disk}

重建raid可以通过`cockpit`存储界面提供的选项完成。选择`添加磁盘`，将新磁盘加入阵列即可。界面会提示阵列的重建进度。以下记录如何用命令行修复阵列。

假设`/dev/vdb`损坏，并插入一块新的1.0GiB硬盘`/dev/vdf`。修复操作如下：

```sh
% lsblk
lsblk
NAME    MAJ:MIN RM  SIZE RO TYPE   MOUNTPOINTS
...
vdc     252:32   0    1G  0 disk
└─md127   9:127  0    2G  0 raid10 /var/mnt/data
vdd     252:48   0    1G  0 disk
└─md127   9:127  0    2G  0 raid10 /var/mnt/data
vde     252:64   0    1G  0 disk
└─md127   9:127  0    2G  0 raid10 /var/mnt/data
vdf     252:16   0    1G  0 disk
# 检查阵列
% cat /proc/mdstat 
Personalities : [raid10] 
md127 : active raid10 vde[3] vdd[2] vdc[1]
      2093056 blocks super 1.2 512K chunks 2 near-copies [4/3] [_UUU]

unused devices: <none>
# 修复阵列
% mdadm /dev/md/raid10 -a /dev/vdf
mdadm: added /dev/vdf
# 检查同步进度
% cat /proc/mdstat 
Personalities : [raid10] 
md127 : active raid10 vdf[4] vde[3] vdd[2] vdc[1]
      2093056 blocks super 1.2 512K chunks 2 near-copies [4/3] [_UUU]
      [===================>.]  recovery = 99.9% (1046528/1046528) finish=0.0min speed=209305K/sec

unused devices: <none>
# 等待同步结束
% cat /proc/mdstat 
Personalities : [raid10] 
md127 : active raid10 vdf[4] vde[3] vdd[2] vdc[1]
      2093056 blocks super 1.2 512K chunks 2 near-copies [4/4] [UUUU]

unused devices: <none>
# 不再提示损坏信息，修复完成
```

以上过程不会损坏磁盘`xfs`的内容。

## 扩容阵列：新增磁盘

### 扩容raid10 {#expand-raid10}

扩容raid部分操作可以通过`cockpit`存储界面提供的选项完成。选择`添加磁盘`，将新磁盘加入阵列即可。但此时raid10并无法启用新磁盘，还需要命令行更新设备才行。以下记录如何用命令行修复阵列。

假设新磁盘为`/dev/vd{f,g}`，要将其增加到raid10阵列：

```sh
% lsblk
NAME    MAJ:MIN RM  SIZE RO TYPE   MOUNTPOINTS
...
vdb     252:16   0    1G  0 disk
└─md127   9:127  0    2G  0 raid10 /var/mnt/data
vdc     252:32   0    1G  0 disk
└─md127   9:127  0    2G  0 raid10 /var/mnt/data
vdd     252:48   0    1G  0 disk
└─md127   9:127  0    2G  0 raid10 /var/mnt/data
vde     252:64   0    1G  0 disk
└─md127   9:127  0    2G  0 raid10 /var/mnt/data
vdf     252:80   0    1G  0 disk
vdg     252:96   0    1G  0 disk
# 检查阵列
% cat /proc/mdstat 
Personalities : [raid10] 
md127 : active raid10 vdb[4] vde[3] vdd[2] vdc[1]
      2093056 blocks super 1.2 512K chunks 2 near-copies [4/4] [UUUU]

unused devices: <none>
# 扩容阵列
% mdadm /dev/md/raid10 -a /dev/vdf -a /dev/vdg
mdadm: added /dev/vdf
mdadm: added /dev/vdg
% cat /proc/mdstat 
Personalities : [raid10] 
md127 : active raid10 vdg[6](S) vdf[5](S) vdb[4] vde[3] vdd[2] vdc[1]
      2093056 blocks super 1.2 512K chunks 2 near-copies [4/4] [UUUU]

unused devices: <none>
# 更新阵列配置
% mdadm /dev/md/raid10 --grow --raid-devices=6
% cat /proc/mdstat 
Personalities : [raid10] 
md127 : active raid10 vdg[6] vdf[5] vdb[4] vde[3] vdd[2] vdc[1]
      2093056 blocks super 1.2 512K chunks 2 near-copies [6/6] [UUUUUU]
      [==========>..........]  reshape = 52.0% (1089024/2093056) finish=0.1min speed=155574K/sec

unused devices: <none>
# 等待同步结束
% cat /proc/mdstat 
Personalities : [raid10] 
md127 : active raid10 vdg[6] vdf[5] vdb[4] vde[3] vdd[2] vdc[1]
      3139584 blocks super 1.2 512K chunks 2 near-copies [6/6] [UUUUUU]

unused devices: <none>
```

以上过程不会损坏磁盘`xfs`的内容。

### 扩容xfs {#expand-xfs}

将raid10扩容后，`xfs`还无法直接使用新空间。需要将`xfs`一并扩容。该步骤无法通过`cockpit`完成。

```sh
# 检查磁盘容量
% df -h /mnt/data
Filesystem      Size  Used Avail Use% Mounted on
/dev/md127      2.0G  171M  1.8G   9% /var/mnt/data
# 扩容
% xfs_growfs -d /mnt/data/
meta-data=/dev/md127             isize=512    agcount=8, agsize=65408 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=1
         =                       reflink=1    bigtime=1 inobtcount=1 nrext64=1
data     =                       bsize=4096   blocks=523264, imaxpct=25
         =                       sunit=128    swidth=256 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=16384, version=2
         =                       sectsz=512   sunit=8 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
data blocks changed from 523264 to 784896
# 检查磁盘容量
% df -h /mnt/data
Filesystem      Size  Used Avail Use% Mounted on
/dev/md127      3.0G  191M  2.8G   7% /var/mnt/data
```

以上过程不会损坏磁盘`xfs`的内容。

## 扩容阵列：更新更大容量磁盘

### 扩容raid10

首先参考[一块磁盘损坏，重建阵列](#fix-disk)，逐一更换阵列中每块磁盘为更大容量的磁盘。**注意：一定要等到一块磁盘完全同步完成后，再更新下一块磁盘！**

磁盘更新后，对raid10进行扩容：

```sh
# 检查状态
% cat /proc/mdstat 
Personalities : [raid10] 
md127 : active raid10 vde[5] vdd[4] vdc[1] vdb[0]
      2091008 blocks super 1.2 512K chunks 2 near-copies [4/4] [UUUU]

unused devices: <none>
# 扩展容量
% mdadm /dev/md/raid10 --grow --size=max
mdadm: component size of /dev/md/raid10 has been set to 2094080K
# 等待同步完成
% cat /proc/mdstat 
Personalities : [raid10] 
md127 : active raid10 vde[5] vdd[4] vdc[1] vdb[0]
      4188160 blocks super 1.2 512K chunks 2 near-copies [4/4] [UUUU]

unused devices: <none>
```

以上过程不会损坏磁盘`xfs`的内容。

### 扩容xfs

参考[扩容xfs](#expand-xfs)，将`xfs`容量扩展为新`raid10`的容量。


## 完全使用`lvm`创建带缓存的raid10阵列（废弃）

> 仅作记录：以下是之前演练`lvm`时的记录。不是我实际的操作方法。

> 本操作绝大部分参考Redhat关于如何[Configuring and managing logical volumes](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_and_managing_logical_volumes/index)的文档。这篇文档里没有提及如何修复带有cache的raid阵列，因此我也选择不使用带有cache的raid阵列。我自己试了各种办法，无法正常恢复一个带有cache的raid10阵列。如果有人知道该怎么做，希望不吝赐教。

假设存在磁盘`/dev/vd{b..g}`，其中`vdd`是一块ssd，500MiB，其余是1GiB的hdd。

```sh
# 创建pv
$ pvcreate /dev/vd{b..f}
$ pvs
  PV         VG Fmt  Attr PSize   PFree  
  /dev/vdb      lvm2 ---    1.00g   1.00g
  /dev/vdc      lvm2 ---    1.00g   1.00g
  /dev/vdd      lvm2 ---  512.00m 512.00m
  /dev/vde      lvm2 ---    1.00g   1.00g
  /dev/vdf      lvm2 ---    1.00g   1.00g
# 创建vg vg_data
$ vgcreate vg_data /dev/vd{b..f}
$ vgs
  VG      #PV #LV #SN Attr   VSize VFree
  vg_data   5   0   0 wz--n- 4.48g 4.48g
$ vgdisplay
  --- Volume group ---
  VG Name               vg_data
  System ID
  Format                lvm2
  Metadata Areas        5
  Metadata Sequence No  1
  VG Access             read/write
  VG Status             resizable
  MAX LV                0
  Cur LV                0
  Open LV               0
  Max PV                0
  Cur PV                5
  Act PV                5
  VG Size               4.48 GiB
  PE Size               4.00 MiB
  Total PE              1147
  Alloc PE / Size       0 / 0
  Free  PE / Size       1147 / 4.48 GiB
  VG UUID               25CafP-o9Ny-Qi4O-iRrl-Vk6t-GvId-s0BiEY
# 创建raid10
$ lvcreate --type raid10 --mirrors 1 -l 100%FREE --name lv_data vg_data
$ lvs
  LV      VG      Attr       LSize Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  lv_data vg_data rwi-a-r--- 1.98g                                    100.00
$ lvdisplay
  --- Logical volume ---
  LV Path                /dev/vg_data/lv_data
  LV Name                lv_data
  VG Name                vg_data
  LV UUID                sU6ZaR-9LVs-cplq-CseT-66cY-J3Hv-mm3WgP
  LV Write Access        read/write
  LV Creation host, time coreos, 2024-10-27 09:32:13 +0100
  LV Status              available
  # open                 0
  LV Size                1.98 GiB
  Current LE             508
  Mirrored volumes       4
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     1024
  Block device           253:8
# 创建cache
$ lvcreate --type cache-pool -l 100%FREE --name lv_cache vg_data /dev/vdd
$ lvs
  LV       VG      Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  lv_cache vg_data Cwi---C--- 492.00m
  lv_data  vg_data rwi-a-r---   1.98g                                    100.00
$ lvdisplay
  --- Logical volume ---
  LV Path                /dev/vg_data/lv_data
  LV Name                lv_data
  VG Name                vg_data
  LV UUID                sU6ZaR-9LVs-cplq-CseT-66cY-J3Hv-mm3WgP
  LV Write Access        read/write
  LV Creation host, time coreos, 2024-10-27 09:32:13 +0100
  LV Status              available
  # open                 0
  LV Size                1.98 GiB
  Current LE             508
  Mirrored volumes       4
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     1024
  Block device           253:8
   
  --- Logical volume ---
  LV Path                /dev/vg_data/lv_cache
  LV Name                lv_cache
  VG Name                vg_data
  LV UUID                cka8mv-Z3cv-VevD-S0Xa-SuVX-orSC-5Zh7cX
  LV Write Access        read/write
  LV Creation host, time coreos, 2024-10-27 09:33:26 +0100
  LV Pool metadata       lv_cache_cmeta
  LV Pool data           lv_cache_cdata
  LV Status              NOT available
  LV Size                492.00 MiB
  Current LE             123
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
# 启用cache
% lvconvert --type cache --cachepool lv_cache vg_data/lv_data
% lvs
  LV      VG      Attr       LSize Pool             Origin          Data%  Meta%  Move Log Cpy%Sync Convert
  lv_data vg_data Cwi-a-C--- 1.98g [lv_cache_cpool] [lv_data_corig] 0.00   1.32            0.00
% lvdisplay
  --- Logical volume ---
  LV Path                /dev/vg_data/lv_data
  LV Name                lv_data
  VG Name                vg_data
  LV UUID                sU6ZaR-9LVs-cplq-CseT-66cY-J3Hv-mm3WgP
  LV Write Access        read/write
  LV Creation host, time coreos, 2024-10-27 09:32:13 +0100
  LV Cache pool name     lv_cache_cpool
  LV Cache origin name   lv_data_corig
  LV Status              available
  # open                 0
  LV Size                1.98 GiB
  Cache used blocks      0.00%
  Cache metadata blocks  1.32%
  Cache dirty blocks     0.00%
  Cache read hits/misses 0 / 22
  Cache wrt hits/misses  0 / 0
  Cache demotions        0
  Cache promotions       0
  Current LE             508
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     1024
  Block device           253:8
# 格式化
% mkfs.xfs /dev/vg_data/lv_data
# 挂载并使用/dev/vg_data/lv_data
```
