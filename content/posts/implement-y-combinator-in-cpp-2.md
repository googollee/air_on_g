+++
date = "2007-09-06T20:00:00+08:00"
title = "尝试用C++实现Y Combinator（之二）"
category = "development"
tags = ["cpp", "python", "y combinator"]
+++

恩……上篇没写完……

其实，上篇还写错了……

<!--more-->

那个combinator::operator()的返回值是int，但是，看那个Python实现：

``` python
 def _1(factorial):
     def _fn(n):
         if n == 0: return 1
         else:
             return n*factorial(n-1)
     return _fn
```

很明显，这个返回值是一个函数……

那么，现在是到了仔细想想_1返回值类型的时候了。简单来说，返回的是个函数，这个函数以一个int为参数，返回一个int值。也就是_1的返回值是int (*)(int)类型。

很明显， _1的返回值和combinator::operator()的返回值不一致。

问题是，怎么才能把他们写的一致呢？由于_fn函数保存了_1传入的参数factorial，所以_fn一定不是一个传统意义上的C++函数，而应该是个仿函数。由于_fn是个仿函数，那就必然有类的实例的生命周期的问题存在，一个不考虑释放内存的_fn应该是这样：

``` c++
class _fn
{
public:
    typedef int(*func_type)(int);

    _fn(func_type factorial) : func_(factorial), type_(FUNCTION), functor_(0)
    {}

    _fn(_fn *factorial) : type_(FUNCTOR), func_(0), functor_(factorial)
    {}

    int operator()(int n)
    {
        if (n == 0)
            return 1;
        else
        {
            switch (type_)
            {
            case FUNCTION:
                return n * func_(n - 1);
                break;
            case FUNCTOR:
                return n * (*functor_)(n - 1);
                break;
            }
        }
        throw;
    }

private:
    enum
    {
        FUNCTION,
        FUNCTOR,
    } type_;
    func_type func_;
    _fn *functor_;
};
```

对应的_1有两个，分别对应传入参数为函数和仿函数的情况：

``` c++
_fn* _1(_fn::func_type factorial)
{
    return new _fn(factorial);
}

_fn* _1(_fn *factorial)
{
    return new _fn(factorial);
}
```

实验一下：

``` c++
int error(int n)
{
    throw;
}

int main(int argc, char* argv[])
{
    _fn* f1 = _1(error);

    cout << (*f1)(0) << endl; // print 1
    //cout << (*f1)(1) << endl; // throw

    _fn* f2 = _1(_1(error));
    cout << (*f2)(0) << endl; // print 1
    cout << (*f2)(1) << endl; // print 1
    //cout << (*f2)(2) << endl; // throw

    _fn* f3 = _1(_1(_1(_1(error))));
    cout << (*f3)(0) << endl; // print 1
    cout << (*f3)(1) << endl; // print 1
    cout << (*f3)(2) << endl; // print 2
    cout << (*f3)(3) << endl; // print 6
    //cout << (*f3)(4) << endl; // throw

    return 0;
}
```

看上去成功了耶~~~~~

当然，我也考虑过不使用指针，而是使用实例，也就是_fn的构造类似：

``` c++
_fn(_fn &factorial) : type_(FUNCTOR), func_(0), functor_(factorial) // need copy ctor here
{}
```

但这是对应functor_(factorial)，就需要一个类_fn的拷贝构造函数，又由于_fn(_fn &factorial)实际就是_fn的拷贝构造函数，也就是说这里递归了……（x，又是递归！）由于Y Combinator的本意就是不用递归而写出递归，所以这里我就不考虑这种情况了。

另一个不考虑的，就是每个_1都会在堆上建一个_fn的实例，这个实例何时销毁？当然是在最后一个_fn销毁的时候销毁。但是……谁有保证不会有人写出"`_fn *f4 = _1(f3)`"呢？f4销毁的时候，可能有别的地方还在用f3……所以说，gc啊gc，开门吧~~~~~~（就是说，期待C++ 0x的gc吧）

再有，就是诡异的语法了。`(*f1)()`之类的东西实在看的别扭。或者也可以写"`_fn &f1 = *_1(_1(...))`"……总之，甘蔗不能两头甜，大床不能两头睡，凑合吧……

不管怎么说，总算实现了看上去像Y Combinator的东西，下次总该能真正实现个浪费内存诡异语法的Y Combinator了吧？
