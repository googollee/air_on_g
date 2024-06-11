+++
date = "2007-08-31T20:00:00+08:00"
title = "Y Combinator in Python"
category = "development"
tags = ["python", "y combinator"]
+++

译自（由于某种原因，请用代理访问）：[Y Combinator in Python](http://siddhi.blogspot.com/2007/08/y-combinator-in-python.html)

<!--more-->

我刚刚读完《The Little Schemer》一书。真是本好书啊！我喜欢书里那种Q&A的风格，而且更加期待这系列的第二本书，《The Seasoned Schemer》。（g9老大好像在某篇blog里提到过这两本书。）

第九章和第十章（最后两章）真是太好了。第十章是关于如何写一个小型的Schemer解释器的（怎么国外的语言牛书都爱自己写解释器……）。但是在这篇 blog里，我想谈谈第九章，因为这章介绍了Y Combinator（记得刘老大把这个翻译为Y算子还是啥的，突然找不到那篇blog了，干脆不翻）。

我过去曾试图理解这个概念，但是失败了（wikipedia page的解释真是莫名其妙），但是这本书却给出了一个华丽丽的解释。实际上，书里从Y Combinator的源头开始解释，并且每一步清晰易懂。

作为练习，我试着在Python里实现这个概念。最终结果是这样的：

``` python
def Y(le):
  def _anon(cc):
    return le(lambda x: cc(cc)(x))
  return _anon(_anon)
```

如果你并不知道Y Combinator的含义，那这段程序看上去实在诡异。

一个简单的解释是，Y Combinator是一个函数，这个函数以一个函数为输入，以这个函数的递归版本做输出。可能一个例子能够更好的说明这点：

``` python
def _1(factorial):
  def _fn(n):
    if n == 0:
      return 1
    else:
      return n*factorial(n-1)
  return _fn
```

看这个函数。函数名字是`_1`。函数体含有看上去像是递归求阶乘的实现，只是这个递归从没有调用函数自身（记住，函数名字是`_1`），而是调用的函数参数`factorial`。

factorial参数本身是个函数，所以`_1`的意思是：

- 如果n为0，返回1
- 否则，利用从factorial传入的函数，以n-1为参数调用这个函数，并且将其返回值乘以n，返回最终的结果

再进一步：

``` python
def error(n): raise Exception

f = _1(error) # passing function "error" as the parameter
f(0)   # prints 1
f(1)   # Exception F (1) # Exception
```

上面的函数f传入error函数做参数。所以如果n为0，返回1。其它情况，程序走到else的分支，调用我们作为参数传入的那个函数，在这里是指error，最终抛出了个异常。

按照递归的规则，我们不想调用error，而是想再次调用某个相同的函数。如果我们传入一个相同的函数呢？（意指给`_1`传入`_1`）这样在else的部分，就不会调用error，而是调用函数自己了。就像这样：

``` python
f = _1(_1(error))
f(0)   # prints 1
f(1)   # prints 1
f(2)   # Exception

f = _1(_1(_1(_1(error))))
f(0)   # prints 1
f(1)   # prints 1
f(2)   # prints 2
f(3)   # prints 6
f(4)   # Exception
```

恩……在每个例子里，递归在遇到error函数时终止。一个真正的递归版本应该像这样：

``` python
f = _1(_1(_1(_1(_1......
```

恩……基本上来说，这就是Y Combinator所做的。用一些神奇的函数传递，就使`_1`变成了一个递归函数。怎么样？很神奇吧！这里解释起来有点复杂。去找那本书的第九章看看吧。但是它确实按我的意思工作了！看看这个：

``` python
f = Y(_1)
f(0)   # prints 1
f(1)   # prints 1
f(5)   # prints 120
f(10)   # prints 3628800
```

有意思吧？更有意思的是，这并不仅仅限于阶乘。看这个：

``` python
def _2(length):
  def _fn(alist):
    if not alist: return 0
  else:
    return 1 + length(alist[1:])
  return _fn

f = Y(_2) # calculate length of a list
f([])   # prints 0
f([1,2,3,4,5])   # prints 5
```

Woohoo！还可以更进一步：

``` python
def _3(reverse):
  def _fn(alist):
    if not alist: return []
  else:
    return reverse(alist[1:]) + [alist[0]]
  return _fn

f = Y(_3) # reverse a list
f([])   # prints []
f([1,2,3])   # prints [3,2,1]
```

你可以随便找个递归函数，用上面的形式重写，然后使用Y Combinator来完成最终的递归版本。这很酷吧？
