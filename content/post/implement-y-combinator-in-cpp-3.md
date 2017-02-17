+++
date = "2007-09-22T20:00:00+08:00"
title = "尝试用C++实现Y Combinator（之三）"
category = "development"
tags = ["cpp", "y combinator", "python"]
+++

基本上，又进行了几次失败的尝试，具体过程不写了，反正写了也没人看。（其实是我没有存……）

<!--more-->

难点在于C++的类型是在编译时确定的，也就是说，所有函数的返回类型和参数类型必须在编译前确定。但是，重新考察python的实现：

``` python
def Y(le):
  def _anon(cc):
    return le(lambda x: cc(cc)(x))
  return _anon(_anon)
```

你能说清楚那个cc的准确类型么？是，cc返回一个int(int)的函数（是真的函数，不是函数指针！），但是参数类型呢？还是cc，而这个cc的类型还是cc……

难怪说动态语言能实现无穷，实际是这里的类型是无穷递归的……

但是python这里为啥就没有问题呢？原因是python的类型并不是在编译时确定，而是在运行时，也就是说，当执行到cc(cc)时，才确认cc是一个函数，以及这个函数的返回值和参数。你问为啥cc会是个函数？使用者（也就是调用_anon的地方）决定的呗，调用的时候就传入的是个函数。你还问要不是函数咋办？不是函数……抛异常崩溃呗，蓝屏的，见过吧？（还是微软六厂的呢！）

所以说，想靠C++的正常手段实现Y Combinator是没有希望了。C++在编译时可写不出无穷递归的参数类型。不过，我们有void*。（这方面讲，C#和Java的反射也能达到运行时确定参数类型的目的，就是麻烦点。但C#的delegate估计就没戏了。）

不过，由于boost::function的一些在我看来很奇怪的限制，导致我可能要真的重新实现一个function的东西了。比如下面这段居然就编译不过去：

``` c++
typedef boost::function<int(int)> ftype;
typedef boost::function<ftypye(ftype)> letype;
```

而int(int)()(int(int))（天，我竟然能写出这么bt的类型签名，《C专家编程》没白读……）类型正是Y的参数le的类型，也是_1的返回类型。如此重要的类型居然没法用function定义出来……

啊？你说为啥非要用function？这个_1的返回值_fn可是有enclosure在里面的，没有个functor怎么实现？既然有了functor，那普通的函数指针肯定没戏，只能找个类似function的东西。

最终，还是逃不掉再造轮子的宿命。

我命由我不由天口牙~~~~~~~（天渐渐凉了，大家记得多穿衣服，小心寒到……）
