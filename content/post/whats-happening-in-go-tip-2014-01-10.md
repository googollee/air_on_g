+++
date = "2014-01-12T10:13:39+08:00"
title = "Go tip在做什么 2014-01-10"
category = "development"
tags = ["golang", "go tip"]
+++

Go tip是Go语言的实验分支，包含了很多尚在讨论，但很有可能会加入stable分支的特性。“Go tip在做什么”（原文地址：[What's happening in Go tip](http://dominik.honnef.co/go-tip/)）分析总结了Go语言尚在开发中的一些重要特性。

<!--more-->

本文译自：[What's happening in Go tip (2014-01-10)](http://dominik.honnef.co/go-tip/2014-01-10/)

现在是2014年了，刚刚经历了圣诞和新年前夜，Go团队就已经开始为下一个发布版本而工作了。也因此，“Go tip在做什么”系列也重开了。

作为这个系列的最新一篇，这篇文章将会有些小调整。最重要的调整是，不会再遵循每周一篇文章的发布周期。一周里可能有几篇文章，也可能一篇都没有。这个调整，一部分由于个人原因，一部分也因为这样可以更灵活的追踪Go的改变。这样做的结果是，每篇文章可能会比以前更短，以便能紧跟最新的开发变化。

另一个调整是，将会覆盖一些关于没有变化的代码的形成原因和讨论。这是因为Go 1.3将会有重大改变（主要是计划用Go重写整个编译器），有些代码需要及早被大家了解。

这篇文章我们将会关注类型`sync.Pool`。这个类型是Go 1.3标准库新添加的第一个重要功能。

# 做了什么

- 添加了`sync.Pool`类型
- 开发流程的小改变

## 添加了`sync.Pool`类型

相关CL：[CL 41860043](http://codereview.appspot.com/41860043), [CL 43990043](http://codereview.appspot.com/43990043), [CL 37720047](http://codereview.appspot.com/37720047), [CL 44080043](http://codereview.appspot.com/44080043), [CL 44150043](http://codereview.appspot.com/44150043), [CL 44060044](http://codereview.appspot.com/44060044), [CL 44050044](http://codereview.appspot.com/44050044), [CL 44680043](http://codereview.appspot.com/44680043), [CL 46010043](http://codereview.appspot.com/46010043)

像JVM这种项目，花了很多的精力来改进垃圾收集系统，来保证其所要处理回收的众多垃圾。另一方面Go，大致上采用了在第一时间避免垃圾的设计方法，需要一个不那么时髦的垃圾收集系统，来保证将内存的控制权交还给程序员。

由于这点，标准库里一些包分别实现了重用对象的池，来避免产生过多的垃圾。`regexp`包为了保证并发时使用同一个正则，而维护了一组状态机，`fmt`包有众多的打印实例，其他包也有各自的池，或者可以采用这种技术。

不过，这种方法有两个问题。最明显的问题是代码重复：即便重要的代码大都相同，所有的包也需要实现一份自己的池。比较细微的问题是，没有办法回收池持有的空间。这种简单的实现从来不会释放内存，违反了使用垃圾回收的语言的原则，导致过高但不必要的内存使用。

因为这些问题，Brad Fizpatrick[曾建议](https://code.google.com/p/go/issues/detail?id=4720)在`sync`包里加入一个公开的`Cache`类型。这个建议引发了一长串的讨论。Go语言应该在标准库里提供一个这个样子的类型，还是应当将这个类型作为私下的实现？这个实现应该真的释放内存么？如果释放，什么时候释放？这个类型应当叫做`Cache`，或者更应该叫做`Pool`？

我先解释一下缓存（cache）和池（pool）的区别，以及为什么这个区别对讨论很重要。Brad Fizpatrick建议的类型实际上是一种池：一组可以互换的值，取出时并不关心具体的值是什么，因为每个值都是刚被初始化的状态，值是相同的。你甚至分不出来刚刚拿到的值是从池里取出来的，还是新创建的。另一方面，缓存是一些相呼映射的键和值。一个明显的例子是磁盘缓存。磁盘缓存将慢速存储中的文件缓存在系统主内存里，以便提高访问速度。如果缓存里有对应键A和B的值（磁盘缓存的例子里，就是文件名），而你请求了与A对应的值，你显然不想得到B所对应的值。实际上，缓存里的值是互不相同的，增加了缓存清除机制的复杂性，就是说到底哪个值应该被清除出缓存。[维基百科上关于缓存算法的页面](http://en.wikipedia.org/wiki/Cache_algorithms)，列举了13种不同的清除缓存的算法，从著名的LRU缓存到更复杂的比如[LIRS缓存算法](http://en.wikipedia.org/wiki/LIRS_caching_algorithm)。

按照这种方式，我们的池真正要关心的问题，只是什么时候回收池占有的空间。而且大家提到了几乎各种可能性：一些在GC前回收，一些在GC后，基于时钟或者采用弱引用指针。所有的建议都有其弊病。

在经历了漫长的讨论后，Russ Cox最终[提议的API和回收策略](https://groups.google.com/forum/#!searchin/golang-dev/gc-aware/golang-dev/kJ_R6vYVYHU/LjoGriFTYxMJ)非常简单：在垃圾收集时回收池空间。这个建议提醒我们，类型`Pool`的目的是在垃圾收集之间重用内存。它不应该避免垃圾回收，而是让垃圾回收变得更有效。

实现了这个提议，并在几次讨论后，提交到Go的代码库。当然，这个CL不是最终结果。首先，所有的池都要改写为`sync.Pool`。这些改写由[CL 43990043](http://codereview.appspot.com/43990043)，[CL 37720047](http://codereview.appspot.com/37720047)，[CL 44080043](http://codereview.appspot.com/44080043)，[CL 44150043](http://codereview.appspot.com/44150043)，[CL 44060044](http://codereview.appspot.com/44060044)追踪，但**不**包括[CL 44050044](http://codereview.appspot.com/44050044)。[CL 44050044](http://codereview.appspot.com/44050044)关注在尝试将`encoding/gob`包里使用的本地释放链表替换为`sync.Pool`。本地是个关键词。一个释放链表会和一个解码器（decoder）的生存时期一样长，直到这个解码器被销毁，才会释放这个链表。Russ Cox[回复了这个CL](https://codereview.appspot.com/44050044/#msg10)，明确了`sync.Pool`的目的，以及它不能用来做什么。直到这时，Rob Pike提交并回复了[CL 44680043](http://codereview.appspot.com/44680043)，扩展了`sync.Pool`类型的文档，将其目的描述得更清楚。

> `Pool`设计用意是在全局变量里维护的释放链表，尤其是被多个goroutine同时访问的全局变量。使用`Pool`代替自己写的释放链表，可以让程序运行的时候，在恰当的场景下从池里重用某项值。`sync.Pool`一种合适的方法是，为临时缓冲区创建一个池，多个客户端使用这个缓冲区来共享全局资源。另一方面，如果释放链表是某个对象的一部分，并由这个对象维护，而这个对象只由一个客户端使用，在这个客户端工作完成后释放链表，那么用`Pool`实现这个释放链表是不合适的。

从回复（和更早的讨论）来看，加入`sync.Pool`还是一种试验，如果`Pool`没有实现它的功能，有可能发布Go 1.3之前将其完全移除。这件事情由[Issue 6984](https://code.google.com/p/go/issues/detail?id=6984)跟踪。

虽然本文对`sync.Pool`的探索结束了，但是关于池的讨论还没有结束。还有[CL 46010043](http://codereview.appspot.com/46010043)，为了更适合并发时使用，改进了非常简单的初始化实现。但这个CL在目前还没有通过审核。

## 开发流程的小改变

从Go 1.3的周期开始，开发的流程有一些小的变化。这些变化只会影响到直接参与开发流程的人，以及像我一样，紧跟最新变动的人。

启用了一个新的邮件列表，[golang-coderreviews](https://groups.google.com/forum/#!forum/golang-codereviews)，并作为新CL的默认抄送对象，替代了原有的[golang-dev](https://groups.google.com/forum/#!forum/golang-dev)。这个想法是为了降低golang-dev里的噪音，以便让其关注真正的讨论。

同时也启用了一个新的信息板，允许提交者更容易的跟踪还在开放的Issue和CL。任何对Go团队的工作方式感兴趣的人，都可以在这个新的信息板上找到有用的说明。
