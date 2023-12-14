+++
date = "2007-09-01T20:00:00+08:00"
title = "尝试用C++实现Y Combinator（之一）"
category = "development"
tags = ["cpp", "y combinator", "python"]
+++

恩……程序员的一大特点：看到别人有个轮子，就想自己动手造个出来……（这样不好，不好……）

<!--more-->

上篇文章翻译了用Python实现Y Combinator。托作者之福，写的清晰易懂，算是让我大概理解了Y Combinator是个什么东西。其实就是把单递归抽象出来嘛，把递归的概念和递归体分离开，这个Y Combinator就是实现了递归概念的函数而已。（真是站着说话不腰疼啊……）

然后，想试试用C++能不能实现这个玩意儿。

基本上，这真是个让我吐血的想法……

最早想一步实现Y Combinator。琢磨着怎么有模板有运算符重载有类的C++，还模拟不出来个函数编程么？结果……唉，具体实现先不提。后来尝试按照文章里讲解Y Combinator的过程，实现某个非递归版本的函，比如那个阶乘：

```c++
class combinator
{
public:
    typedef int (*func_type)(int);

    combinator(func_type arg) : factorial_(arg)
    {}

    int _fn(int n)
    {
        if (n == 0)
            return 1;
        else
            return n * factorial_(n-1);
    }

    int operator()(int arg)
    {
        return _fn(arg);
    }
private:
    func_type factorial_;
};

int error(int n)
{
    throw;
}

int main(int argc, char** argv)
{
    combinator _1(error);

    cout << _1(0) << endl; // print 1
    //cout << _1(1) << endl; // throw exception
    return 0;
}
```

看吧，看吧，果然实现了！

但是，当我想进一步递归的时候，问题出现了……因为对combinator的调用，是通过仿函数实现的，这个没法再次用函数的形式，去构造另一个combinator实例，比如：

``` c++
combinator _2(_1); // 这个不会通过编译的……
```

真是死人。没关系，我们有重载……这样：

``` c++
class combinator
{
public:
    typedef int (*func_type)(int);

    combinator(func_type arg) : factorial_(arg), type_(Function)
    {}

    combinator(combinator *instance/* really want to use ref here, but that can't differ from copy ctor */) : combinator_(instance), type_(Functor)
    {}

    int _fn(int n)
    {
        if (n == 0)
            return 1;
        else
        {
            switch (type_)
            {
            case Function:
                return n * factorial_(n-1);
            case Functor:
                return n * (*combinator_)(n-1);
            }
            throw;
        }
    }

    int operator()(int arg)
    {
        return _fn(arg);
    }

protected:
    combinator(const combinator& arg) // copy ctor be protected can avoid miss usage.
    {}

private:
    enum
    {
        Function,
        Functor,
    } type_;
    func_type factorial_;
    combinator *combinator_; // instance is better than pointer here, for pointer may be deleted. But, how...
};

int error(int n)
{
    throw;
}

int main(int argc, char* argv[])
{
    combinator _1(error); // can be writen like _1(&error) :)

    cout << _1(0) << endl; // print 1
    //cout << _1(1) << endl; // throw exception

    combinator _2(&_1); // well, a little different with python

    cout << _2(0) << endl; // print 1
    cout << _2(1) << endl; // print 1
    //cout << _2(2) << endl; // throw exception

    combinator _3(&_2);

    cout << _3(0) << endl; // print 1
    cout << _3(1) << endl; // print 1
    cout << _3(2) << endl; // print 2
    //cout << _3(3) << endl; // throw exception

    return 0;
}
```

怎么样？很厉害吧？不过，本来在Python里挺短的程序，居然写了这么长，真是Orz！另外，类不能重载么？在类里面存在个type_来判断到底存的是函数还是仿函数，真是不优雅。不过，莫非要我再用类继承来消掉这个type_？那就不仅仅是这么长的代码了！算了，有兴趣追求优雅的，自己去写吧，我忍了……

居然写这个东西要写这么半天，郁闷！而且貌似再往后也不是那么好写的。最终的Y Combinator实现，留到下次吧……
