+++
date = "2007-06-13T20:00:00+08:00"
title = "C++中的重载问题"
category = "development"
tags = ["cpp", "overload"]
+++

话说有这样的一族函数：

``` c++
void insert(BaseWidget* w,  int i = -1);
void insert(ThinWidget* w,  int i = -1);
void insert(ThickWidget* w, int i = -1);
void insert(BigWidget* w,   int i = -1);
void insert(SmallWidget* w, int i = -1);
```

<!--more-->

其中xWidget都继承自BaseWidget。这些函数大体功能都一样，只是细微上有一点差别，比如要对BigWidget重新做布局，或者设置ThickWidget的边框。

然后，有人把这些东西改成：

``` c++
void insert(BaseWidget* w,  int i = -1);
void insert(ThinWidget* w,  int i);
void insert(ThickWidget* w, int i);
void insert(BigWidget* w,   int i);
void insert(SmallWidget* w, int i);
```

结果会怎么样呢？

那就是，所有忽略i值的调用都会自动转向：

``` c++
insert(BaseWidget* w,  int i = -1)
```

编译不会出错，运行不会出错，行为…………自然就出错了………………

原因是，如果有ThinWidget *thinW，那么调用：

``` c++
insert(thinW)
```

最初的设计会调用重载：

``` c++
void insert(ThinWidget* w,  int i = -1)
```

但如过按照后来的设计，由于最后一个参数i没有默认值，调用也就无法匹配到正确的函数，只好退而求其次，寻找父类匹配，结果就调用到了：

``` c++
void insert(BaseWidget* w,  int i = -1)
```

考虑到C++一般是定义声明分离，而且默认参数的定义是写在声明里，所以，你就等着一头雾水的解Bug吧。

我这两天就闷了几头雾水解这个bug，查到结果后，郁闷死了，那些声明是另一个同事改的，说是为了明确函数声明……
