+++
date = "2014-03-07T01:20:00+08:00"
title = "Atom初探"
category = "geek"
tags = ["atom", "editor"]
+++

传说上古之时，上帝为了防止人们齐心协力制造能够通向天堂的通天塔，给了不同人群不同的编辑器，其中最大的两群人分别拿到了叫做VI和Emacs的编辑器，其余的nano，ed，UltraEdit之类不一一详叙。自此以后，人类为了使用什么编辑器来编写通天塔的文档吵个不停，再也没有心思去修通天塔了……

后来，有不同的英雄察觉了上帝的企图，决定以个人之力重新统一人们的编辑器，并赋予其更强大的弑神之力。这些英雄的名字不仅仅限于Text Mate，Sublime……

最近，一个新的英雄自带光环的出现在了大家眼前，[Atom](https://atom.io)……

*本文使用Atom编写*

<!--more-->

决定还是好好说话。Atom是github最近的一个桌面编辑器项目。刚一发布，立刻引起了众人围观，不仅仅在hack news上有着诸多报道，其github repo也被迅速关注，而为其编写的package更是一夜之间遍布各个领域。

为什么Atom能如此受到关注？除了github本身的光环，以及开箱即用的功能，对其目标人群——程序员——来说，基于web技术理念设计的桌面软件，大概是最吸引人的特点。

什么是web技术理念的桌面软件？
--------------------------

简单来讲，Atom其实是一个跑在本地的网页。Atom编辑器本身是个Chromium项目，运行时会在NaCl（Native Client）环境里启动一个node.js的进程处理编辑器的核心功能，在界面上利用Chromium显示由node.js支持的网页，并在页面上为使用者提供功能。目前在Atom的界面上，还可以随时用Chromium的快捷键cmd+alt+i来打开控制台，查看整个Atom程序的页面布局：

![在Atom里打开Chromium的Inspector](/images/atom-inspector.png)

由于Atom的界面本身就是网页，那么主题这种表现层的东西就交由css完成。实际上，Atom的主题确实就是一段css代码，比如默认主题[atom-dark-ui](https://github.com/atom/atom-dark-ui/blob/master/stylesheets/text.less)。使用node.js来提供后台服务，也让Atom的功能插件可以从前到后都使用javascript一种语言搞定。

以css和javascript作为基础，大大简化了为Atom开发的门槛，只要有web的编程基础，再加上好的创意，就能为Atom编写插件。这也能解释从Atom发布到现在不长的时间里，Atom的package数量就快速增长，覆盖了各个领域（参见[package页面](https://atom.io/packages/list)）。

实际使用
-------------

由于Atom还在邀请使用的阶段，如果还没有的同学，请发挥自己的人脉，或者善用Google，找到安装包。目前的安装包似乎只有Mac上的版本……

打开Atom，第一感觉是……咋和Sublime这么像？除了默认字体是Monaco，而Sublime默认使用Menlo外，界面布局几乎完全一样。顺手按下cmd+shift+p，不出所料的调出了命令面板（Command Palette）。在命令面板里键入`install packages`打开设置界面，嗯，终于有些不一样了。Atom的设置界面长的更像一个网页，内容信息完全超过Sublime以行为主的简单搜索。

设置界面的右侧列表里列出了Atom自带的所有package。简单浏览一下，各种语言支持全面，还有对git和markdown的支持，不愧是github的产品。比较有趣的模块是`Metrics`，点进去看一下，居然是用Google Analytics来统计Atom的使用情况！

程序员会更喜欢使用命令行调用编辑器。点击`Atom`菜单，选择`Install Shell Commands`，就会在系统里安装`atom`和`apm`两个命令。`atom`命令可以在命令行启动Atom程序，并打开文件，`apm`则类似node.js的`npm`，是Atom的package管理程序。

与Sublime不同，Atom会根据打开文件所在的目录，决定是否使用一个新的窗口打开文件。比如在目录A下打开文件a `A> atom a`，和目录B下打开文件b `B> atom b`，会打开两个Atom窗口，两个窗口的布局和右侧的目录视图都不同，方便在多个项目间切换。

Atom内建对git的支持。如果打开的文件所在的目录是个git项目，会在右下角的状态行显示repo的分支，该文件和git repo上最后一个版本的差异，左侧的目录树也会显示哪些文件有改动，哪些文件是新增的。

Atom默认支持github的markdown预览。编辑markdown文件时，可以在命令面板里输入`markdown preview`，或者按ctrl-shift-m，就可以打开markdown的预览。不过这个预览只能显示已经存盘的文件内容，如果能实时显示编辑的文件内容该多好。Atom还支持github定义的` \`\`\` `代码块，并根据代码内容做高亮：

![Atom的markdown对代码高亮的支持](/images/atom-markdown-highlight.png)

点击`Atom`菜单下的`Open Your Stylesheet`，就可以打开编辑用户自定义的主题。比如，在打开的Stylesheet最后添加如下内容：

```css
.editor .markup.underline.link.hyperlink {
  color: #AAA;
  text-decoration: underline;
}
```

就可以把程序注释里的url稍微高亮，并加上下划线。正好默认的Stylesheet第8行有个url，cmd-s存盘后就能看到效果。

Atom的配置文件倒是很有特色的选择了cson，而不是更通用的json。当然，cson完全兼容json，把所有的配置当作json来写没有任何问题，甚至还不用拿着放大镜找哪个数组的末尾多写了逗号这种恼人的情况。不过，总有人会讨厌这种混合着yaml和json的格式的。

感受
----

我多想最后就写一句话：Atom就是好啊就是好！就是好啊就是好！就是好！

可惜，这句话不是现实。

抛开实现还不稳定，经常遇到这样那样的小问题外，对Atom最大的不满，就是慢！这东西太慢了！Atom和Sublime打开的速度对比，让人想起当年Vi对比Emacs打开速度的优势。再有就是Atom编辑大文件实在力不从心，稍微上10k的文件就能感觉到明显的延迟，这还是在使用ssd的MacBook Pro上的情况。打开文件瞬间闪过没有任何高亮的代码，也是拜速度所赐。

相比Text Mate的沉沦和Sublime的拖沓，还是相信github会对Atom非常上心，会尽可能解决目前存在的问题。Atom社区也会非常活跃的产出各种package，解决不同使用场景下缺失的功能，扩展Atom的能力。

如果你是程序员，或者是喜欢折腾的Geek，试试Atom吧。不管最终是不是使用Atom，你都会发现其独特的一面。
