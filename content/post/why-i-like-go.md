+++
date = "2012-07-09T20:00:00+08:00"
title = "我为什么喜欢Go"
category = "development"
tags = ["golang"]
+++

这半年来工作上一直在用Go，总共统计下来也写了1w多行代码，算上删删改改的，大概能有1w5吧。而且还写了不少go的库，比如android push库[go_c2dm](https://github.com/googollee/go_c2dm)，一个简单的IMAP客户端[goimap](https://github.com/googollee/goimap)，想继续完善的编码库[go-encoding-ex](https://github.com/googollee/go-encoding-ex)。似乎赶着最近Google IO，国外很时兴写对Go的总结，于是我也赶热闹写一篇blog。

<!--more-->

## 我喜欢的Go特性

### interface

Go的interface实在是让人眼前一亮的特性，在静态编译语言里引入了动态语言常用的duck type特性，而且还没有任何运行时负担。举个栗子，如果我想给一个struct A实现io.Reader接口，在定义struct A的时，不需要和io.Reader扯上任何关系（不需要继承，不需要包含，什么都不需要），只要对struct A定义Read([]byte) (int, error)这个函数（与对象方法类似）就可以。至于如何把struct A的实例捏成一个io.Reader，全是Go编译器在背后的工作。我斗胆猜一下Go在使用io.Reader这个interface的时候，使用了类似下面的结构：

``` go
type InterfaceReader struct {
	instancePtr pointer_to_original_instance
	readFunc pointer_to_read_function
}
```

而将一个实现了Read成员函数的实例变成io.Reader的时候，执行了类似下面的代码：

``` go
// Pseudo code for:
//   var i io.Reader
//   i = New(A)
i = New(InterfaceReader)
i.instancePtr = New(A)
i.readFunc = i.instancePtr.Read
```

这个伪代码的操作，在编译期就可以完成，不需要在运行时依旧保留很多类型的相关信息。

### reflect

不过Go依旧在运行时保留了不少的类型信息，用来完成反射。不过Go的反射与Java和其他动态语言比起来，还是有限制：所有的反射操作都必须通过一个实例完成，而不能直接操作类型。比如，可以根据一个实例拿到一个类型并生成这个类型对应的新实例：

``` go
t := reflect.TypeOf(a)
v := reflect.New(t.Elem())
newA = v.Interface().(*A)
```

但是没法直接根据类型的名字拿到类型并生成实例，考虑到这门语言设计目的是效率优先的静态编译语言，这也似乎不是太大的问题，而且可以通过别的方法实现。

不过，目前Go的reflect库不能通过reflect.Type来创建一个Array或者Slice，似乎是个挺杯具且无解的事情，限制很大。

值得一体的是，Go的struct的成员可以定义Tag这种描述信息，程序里没有直接的作用，但可以通过reflect访问到：

``` go
type A struct {
	i int `tag:"abc"`
}

v := reflect.TypeOf(new(A))
f, _ := v.FieldByName("i")
f.Tag.Get("tag") == "abc"
```

虽然目前Go的标准库里只用Tag来做json编码/解码时对应域的名字，不过似乎可以有更有趣的用法。

### channel

在Go之前，就有不少语言以支持轻量进程的并发为特点，比如广为人知的Erlang（其语法的诡异导致没有大规模流行）。不过Go比Erlang更多了一种叫做channel的类型，用于在进程间传递消息。Erlang里，如果要和一个进程通信，只能给这个进程的pid发消息，消息里带有一个标号。这个进程收到消息后，根据标号再做不同的处理。这种做法使得Erlang里大量出现通信时根据标号做模式匹配的语句，可以类比C的大块大块switch/case，配合Erlang的另一大特点“代码热更新”，经常会写出十分难读的代码。另一方面由于pid要先创建进程后才能拿到，如果想让两个进程互相通信，就必须先创建进程A拿到pid_a，再创建进程B，把pid_a传给进程B，再把进程B的pid_b传给进程A，A拿到pid_b后会对自己的执行体做更新，去实现真正的功能。这个说起来似乎简单，真写一写的话实在头疼。

Go在Erlang的基础上进一步抽象出了channel，使得进程间通信变的更加清晰。一个goroutine可以持有一个或者多个channel。可以先创建channel，把创建好的channel传给若干个需要互相通信的goroutine。这样就完美的解决了Erlang里遇到的两个很拧巴的问题。

### goroutine

一句话：并发变得如此简单。

### one executable binary

目前Go在编译好后只会有一个bin文件，而且不使用cgo引用c库的话，也不会依赖特殊的库。在生产环境部署Go真是痛快无比，再也不用想是不是要升级这个gem，是不是要下那个egg，是不是这个版本滞后了，是不是那个api不兼容……

### go fmt

配合[Sublime2](http://www.sublimetext.com/2) + [GoSublime](https://github.com/DisposaBoy/GoSublime)，再也不用费心代码格式的问题了。

## 使用中遇到的问题

### 用成员首字母的大小写来控制可见性

<del>这真是很诡异的特性：</del>所有名字首字母大写的成员，是对包外可见的；所有名字首字母小写的成员，都是包外不可见的。

<del>这一条就使得Go命名与下划线分割的命名方式绝缘，只能选用驼峰命名法。因为PublicName和privateName看上去还算协调，如果出现Public_name，就怎么看怎么诡异了。或许以后可以用驼峰作为公开命名PublicName，而用下划线作为私有命名private_name。</del>

更新：经过一段时间的使用，Go选择这种命名方式真是太好了。在看一段代码时，只要看到首字母大写的，就能知道这个变量/函数是公开的，不能轻易修改；而对于小写的变量/函数修改就像对自由很多。维护的时候再也不用去来回翻阅声明，检查一个变量/函数是不是可以变了！

不过Go官方推荐都用驼峰命名。

多说一句，在做json解码时，如果对应的struct没有特殊声明，会把json的域写入对应名字首字母大写的struct的成员里。而json编码时默认会以struct域的名字作为json域名，如果要对应到小写，需要声明相关域的Tag：

``` go
type A struct {
	I int `json:"i"`
}
```

### reflect还有问题

前面也提过，不能根据reflect.Type直接生成对应的Slice或者Array或者Map实在太讨厌了！

## 期望

Go还是一门很年轻的语言，如果要对其提出展望的话，我期望以下特性：

### reflect支持创建对应Type的Slice和Array

前面多次提到了。

### struct的成员函数也能支持tag

目前tag只能支持成员变量，如果也能给成员函数写tag就太cool了：

``` go
type A struct {}

func (a *A) `tag:"id"` SomeFunc() {}
```

### 完善库

没有IMAP好痛苦！自己实现IMAP好蛋疼！ _(:з」∠)_

目前我可能比较急需的库：多语言本地化（大概把ICU直接port过来），更多的编解码，能换个更好用的text模版库么（模版里写个range都没法判断是不是到了最后一个元素，想用模版输出“a, b, c and d.”简直要死人啊）。

### heroku

严格来说这个不是对Go语言的期望。现在GAE已经支持Go了，但是因为GAE的api太特殊，为GAE写的程序只能跑在GAE，不能自己部署，所以稍微有点不爽。如果heroku可以支持Go的话，就可以做到本地云间一个样了。可惜看上去heroku目前并[没有支持Go的打算](https://twitter.com/heroku/status/221990016329596928)。

（不过heroku内部已经把一部分ruby模块切换到Go了，或许可以期待一下？）

## 后记

Go的前途是光明的！道路是曲折的！以后我也会在blog里多分享一些自己使用Go遇到的问题和惯用法。
