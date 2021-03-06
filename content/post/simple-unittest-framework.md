+++
date = "2009-11-28T20:00:00+08:00"
title = "简单的UnitTest框架实现"
category = "development"
tags = ["cpp", "unittest", "embedding"]
+++

这几天试了下TDD，需要一个UnitTest框架。以前用过Google Test和JUnit，不过想了一下，印象里Google Test经过几次升级后，似乎只能单独编译，而JUnit只能用在Java里，都不适合嵌入式运行的场合。所以花了半天左右自己写了个框架。

<!--more-->

框架其实很简单，只支持TestCase，Case的自动注册和运行，以及Case运行前后的环境准备和清理。所有的Case的函数签名是bool func()的形式，存在一个全局vector指针数组里。注册的时候可以利用宏：

``` c++
#define TEST(name) \
static bool test##name(); \
RegisterCase case##name(test##name, #name); \
bool test##name()
```

创建Case的时候，只要像这样就可以：

``` c++
Test(SomeCase)
{ ... }
```

因为注册是通过全局类实例RegisterCase的构造函数完成的，因此在main执行之前，这些Case就已经完成了注册。main里只要遍历vector，并执行就可以。同时对返回值做判断，如果true则继续下一个Case，false则退出。

在实际使用中，发现其实断言还是需要的。默认的assert只能打出错误位置，不能提示更多的错误信息。好的断言应该既可以提供错误位置信息，也可以打出当前错误的语句内容，甚至要是能打点自定义的信息就更好了。另外断言最好是用宏抛异常throw，或者访问NULL，这样在调试时可以不用设断点。

另外发现其实还是需要TestSuite。每个Suite内的Case共享同样的环境准备/清理函数，而Suite之前的环境准备/清理函数则不同。不然的话就要写好几个Test程序。从粒度上讲到是也不错，不过编译脚本写起来比较烦。

至于报告输出……恩……其实还是应该输出的，不过我们还没有集成的自动测试环境，这个就先省了吧。
