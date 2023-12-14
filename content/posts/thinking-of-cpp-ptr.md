+++
date = "2009-11-07T20:00:00+08:00"
title = "关于C++智能指针的思考"
category = "development"
tags = ["cpp", "auto_ptr"]
+++

最近在公司的项目里开始实践用C++的析构来自动释放已申请的指针，同时保证程序的效率不变。

<!--more-->

由于要使用C库，因此自己写了三个类：local_ptr，local_ptr_f，auto_ptr_f。其中第一个类是类似std::autor_ptr，只是没有拷贝构造函数和赋值构造函数，只能本地使用。两个带_f后缀的，在构造时分别多了一个用于释放内存的函数做参数，目的是可以自动管理C的内存分配。

为什么不直接用boost::share_ptr？首先，我觉得引用计数这东西在大部分场合用不到。用到的时候，也应该作为确认实例生命周期的工具而存在（比如类似COM的应用），而不是成为指针的一部分；另一方面，虽然引用计数引入的操作不多，但是蚂蚁啃大象，直接使用share\_ptr会在不知不觉中引入很多没必要的计数操作，降低效率（记得许老大的blog上有提到过这种情况）。尤其是将share\_ptr直接扔到container里的行为，在我看来，这简直就是对C/C++追求效率的宗旨的肆意践踏！先不说多出来的内存占用量，由于container自身一些调整行为导致的引用计数操作，简直就是不可预测的！

由于没有了share_ptr，weak_ptr自然也就没有存在的必要了。对于不释放的内存引用，直接用原生指针就行。对于不需要在函数间传递的内存引用，使用local_ptr/local_ptr_f，例如：

``` c++
{
  local_ptr<SomeClass> p = new SomeClass;
  // blablabla
}

{
  local_ptr_f<FILE> f(fopen(...), fclose);
  // blablabla
}

{
  local_ptr_f<char> str(strdup(...), free);
  // blablabla
}

{
  local_ptr_f<GFileEnumerator> enum(g_file_enumerate_children(...), g_object_unref);
  GFileInfo* info = NULL;
  while ( (info = g_file_enumerator_next_file(enum.get(), ...)) != NULL )
  {
    local_ptr_f<GFileInfo> p(info, g_object_unref);
    // blablabla
  }
}
```

对于需要传递实例所有权的情况，使用auto_ptr/auto_ptr_f。这个各类C++书籍都有介绍，我就不展示代码了。

使用这些函数，依旧要求程序员像C一样明确一个实例的生存周期，而且还要分辨这个周期中的持有者（对持有者使用local_ptr/local_ptr_f），传递者（对传递者使用auto_ptr/auto_ptr_f）和引用者（对引用者使用原生指针）。优点是：利用C++析构函数自动调用的优点，不需要手动为每一个内存释放点写释放代码；对C风格来说，申请内存的函数和释放内存的函数靠的很近，可以避免误配对；保证对一种内存实例使用同一个内存释放函数。

也有一个缺点：从阅读角度，创建内存实例的时候，赋值操作看着不明显了。比较：

``` c++
char* str = strdup(...);
```

和

``` c++
local_ptr_f<char> str(strdup(...), free);
```

就我自己的感觉，在一堆堆的代码里，前者因为有“=”的存在，能更轻易的被发现，而且现代编辑器可能还会用特殊的颜色标识出来。而后者会和函数调用等语句混在一起，不利于阅读。目前没有想到解决办法。另一个不好的地方是，会把变量初始化的语句写的很长。这个可以通过适当的折行来缩短，不算什么太大的问题。
