+++
date = "2010-03-13T20:00:00+08:00"
title = "ssh退出失败，报错EPIPE"
category = "development"
tags = ["ssh", "os", "pthread"]
+++

这两天帮同事看一个sshd退出时报错的问题。

<!--more-->

问题的产生比较复杂。sshd出于安全的目的，当有ssh连入的时候，会先fork出一个root sshd来接收请求，并通过nss来鉴别用户权限。之后会再fork出一个sshd并把uid改为用户的uid，之后这个uid的sshd会fork出csh或者其他的sh等待用户输入。用户的每次动作都会到nss上请求权限。退出的时候，这几个进程其实是互相独立着退出的。问题出现在退出时，root sshd试图访问nss，但是收到EPIPE信号，且retry也失败。

原因是，申请对nss的链接的是root sshd，申请到nss链接后，会用atexit注册一个destory_fn的函数，并在这个函数里释放并销毁nss链接。而root sshd在fork uid sshd之后，两个进程同时持有同一个对nss的链接。这样在两个进程退出时，会对同一个链接释放两次。由于uid sshd动作比root sshd快一些，所以uid sshd对nss的释放是成功的，而root sshd由于还需要写一些和用户相关的logout信息，还需要查nss，导致了错误。

仔细研究发现，通过fork创建的进程，会复制一份父进程的fd数组。不同进程的fd在内核里会指向同一个socket链接（内核对链接应该维护了一个类似引用技术的东西）。如果其中某个进程退出了，内核会再创建一个新的fd供未退出的进程使用。再细节的就要去看kernel源码了。

但是由于uid sshd在退出时调用的destory_fn会通知nss服务器close链接，导致root sshd在对nss发送消息时会收到RST信号。这时虽然在root sshd里，nss的fd还存在，但已经处于关闭状态，自然再试图写的时候，就会得到EPIPE，而且由于retry只是对发送内容做retry，并没有重建链路的动作，因此也总是失败的。

目前的解决方法是使用pthread_atfork，在fork后对子进程做操作，把注册到atexit的destory_fn函数替换成只释放本地fd，不要求对端close的版本。话说pthread_atfork都能勾系统的fork函数了，这应该不仅仅是个线程库了吧？

后来发现，pthread_atfork在bsd的服务器上不起作用（不知道是bsd的原因还是api本身的原因）。解决的办法是，在申请链接的时候保存申请进程的pid，释放的时候检查本进程的pid与保存的pid是否一致。如果不一致就仅仅释放fd而不释放链接。只有pid一致的情况下才会释放链接，保证“谁申请谁释放”的原则。
