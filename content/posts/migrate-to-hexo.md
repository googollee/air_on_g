+++
date = "2013-04-24T08:34:35+08:00"
title = "迁移到HEXO"
category = "development"
tags = ["hexo", "nodejs", "ruby"]
+++

前几天把这个blog的框架从[jekyll](https://github.com/mojombo/jekyll)迁移到了[HEXO](http://zespia.tw/hexo/)。因为会重新生成feed，uuid和原来的不一样，所以有刷屏，抱歉。

<!--more-->

总体上，HEXO的完成度要比jekyll高。不过这么比并不公平：对应HEXO的应该是[Octopress](http://octopress.org)。不过总体使用感受比jekyll好很多。

因为HEXO是node.js上模仿Octopress的作品，而Octopress又是基于jekyll的，所以整个迁移过程十分顺畅，而且迁移后所有文章的URL都不会变化，Disque和Google Analytics的数据都不需要更新就可以直接合并过来，很爽。迁移后，RVM终于没有了存在的理由，删之。

迁移的原因是，因为很久不写blog，也没更新ruby gem，jekyll已经落后主线版本很多。我在用的一个插件，在新版有bug无法正常执行，折腾了很久也没搞定，于是就决定换一个框架.

本来开始想用Go的一套框架[Gor](http://wendal.net/2013/0111.html)，down下来大概跑了一下，因为是编译后的bin，速度相当快。无奈功能还有欠缺，整个迁移目测要改的东西不少，于是放弃了。等养肥了再说。

后来[@ilrcat](https://twitter.com/ilrcat/status/325092691882954752) 推荐用HEXO，正巧这两天也在用node.js弄一些东西，于是就装了一下。速度比基于Ruby的jekyll快不少，虽然感觉还是比Gor慢一些，但是也够用了，而且迁移很快，于是就花了一晚上搞定。

说到js，这种能执行出 _3755933696 | 0xffff != 3755933696_ 的语言实在太可怕了！向所有写js的程序员致敬： *你们受* 苦了！
