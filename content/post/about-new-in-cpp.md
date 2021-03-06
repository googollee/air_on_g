+++
date = "2007-01-20T20:00:00+08:00"
title = "关于C++中的new的一些处理"
category = "development"
tags = ["cpp", "new"]
+++

首先的一点是，C++中new失败后，默认抛异常bad_alloc()，也就是说，判断返回值是否为NULL的方法在现代编译器面前毫无用处——判断执行之前，程序就随着异常的栈展开而销毁了！

<!--more-->

用异常的好处，不用再反反复复的写对new失败的判断了，只用在一个地方捕获异常，即可判断程序中所有的这类情况。

但是，另一方面，我们又很想知道是哪个地方，或者哪个类new失败了。这两个信息中，类new失败对程序的维护更加重要。因为如果一个类重载了new方法，那么new失败的情况很有可能是自己操作不当造成的。而普通的new失败信息，一般是内存用尽，这种情况与程序本身的逻辑没有关系（除非有不可饶恕的内存泄漏），因此知道具体的类，对程序的维护并无太大帮助。那好，这里就谈谈如何在new抛bad_alloc时，记录下一些特定的信息。

new在失败后，并不是直接抛异常，而是会调用一个new_handler的回调函数，期待能让程序通过这个函数获得更多的可用内存。如果没有注册这个回调函数，或者这个函数调用后内存依旧不够用，才会抛异常。这个回调函数可以用set_new_handler来注册。大体流程如下：

``` c++
if (alloc 失败)
{
  std::new_handler old_handler = 0;
  while(true)
  {
    old_handler = std::set_new_handler(0);
    if (old_handler == 0)
    {
      throw std::bad_alloc();
    }
    old_handler();
  }
}
```

那么，我们可以写如下的类，在真正alloc之前插入我们自己的new_handler，并在new_handler中记录alloc失败的情况：

``` c++
class NewHandlerHolder // 这是个辅助类，可以自动保存旧的new_handler
{
public:
  NewHandlerHolder(std::new_hander arg)
    : holder_(arg)
  {}

  ~NewHandlerHolder()
  {
    std::set_new_handler(holder_);
  }

private:
  std::new_hander holder_;
  // 阻止拷贝构造和赋值函数
  NewHandlerHolder(const NewHandlerHolder&);
  NewHandlerHolder& operator =(const NewHandlerHolder&);
}

class MyClass
{
public:
  void* operator new(size_t arg)
  {
    NewHandlerHolder
      holder(std::set_new_handler(&MyClass::myClassNewHandler));
    return ::operator new(arg);
  }

private:
  static void myClassNewHandler();
}
```

但是，写个优秀的MyClass::myClassNewHandler并不是那么简单。如果仅仅是使用cout或者printf输出，能保证cout和printf内部没有做内存的动态分配么？别忘了，调用这个函数时，内存已经极为紧张，无法保证正常的分配了。

我个人的一个想法：

``` c++
extern const char* badAllocClassName;

void MyClass::myClassNewHandler()
{
  badAllocClassName = "MyClass";
}
```

这样，当捕获到bad_alloc异常时，输出badAllocClassName的内容，就可以得到抛异常的类的名字了。
