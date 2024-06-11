+++
comments = true
date = "2018-01-10T15:24:03+08:00"
share = true
tags = ["go"]
title = "我对Go 2类型系统的期望"

+++

我应该算是第一批使用Go做实际开发的程序员，也写过一些比较深入的项目（比如go-socket.io)。我想总结一下Go里关于类型系统好用的部分以及不好用的部分。这些特性会集中在语言层面，而且基本上是Go 1基本不可能有改动的特性。

<!--more-->

我现在对于语言的类型系统的看法：类型系统是对程序承诺行为的一组静态约束。比如，对一个变量的类型约束为int8，表示这个变量具有以1 byte为存储单位，带有符号位的整数数字的行为。这种约束的好处，一方面可以让编译器根据承诺的行为来做优化（比如为这个变量分配1 byte而不是默认寄存器字长），另一方面可以让代码本身包含更多的意义，方便读代码和静态检查是否违反了约束。

由此，类型系统的灵活性，决定了语言能写出多强大的静态约束，能在多大程度上帮助程序员不犯错误。

先简要说一下好的部分吧。

在Go之前，主流的语言的都认为面向对象（OO）是大型工程代码的组织方式，再往前主流的组织方式分成以描述过程为主的组织方式（过程式编程），和描述转化为主的组织方式（函数式编程）。面向对象更像是试图结合过程式编程和函数式编程的一次尝试：将过程式的描述进行封装，对外暴露转化行为（接口），并在更高层次上统一处理某一类的转化（多态）。其目的是将状态管理集中在类的一组方法中，外部不直接操作状态，而是通过方法调用来让类的实例产生行为。这种方法很适合将各种功能解耦，由专门的人来负责开发维护。功能内的状态只由内部维护；功能间依靠接口来约束行为。这让功能间的耦合可以脱离具体数据，只关心状态的变化和流程。由于数据的变化和维护要远难于状态转化的变化和维护（想一想历史数据清洗和迁移），这种组织方式很适合现代大规模软件工程。

但是面向对象普遍使用的继承，会在父类和子类之间共享状态，而且很容易出现状态同时被父类和子类修改的情况。另外多继承导致的状态不一致也是很大的问题。

Go对此的解决方案是，取消继承，将多态的功能完全交给接口来实现，并通过匿名组合来实现复用。这样，面向对象的三大基本思想“封装，继承，多态”就分别由“struct，compose，interface”三个特性来完成。由于组合不会在类型间共享状态，也就避免了继承以及多重继承带来的一系列问题。

由此，Go在编写实现的时候会重点关注struct内部的数据。如果封装合理，struct应该和业务逻辑有一对一的实现。同时，模块之间使用interface来约束行为。由于interface没有状态，所以可以轻易组合interface来产生新的行为类。

然后，Go类型系统的好处，大概就这么多了。

Go目前被人诟病最多的，大概就是错误处理时遍地`if err != nil`。Go函数习惯上会利用多返回值的最后一个值，作为错误标志。但是，语法上这些返回值是并列关系，并不互斥。也就是说，完全可以在前面的值返回合法值的同时，最后返回一个错误。而且Go的标准库里就有类似的情况：

```go
// ...
// When Read encounters an error or end-of-file condition after
// successfully reading n > 0 bytes, it returns the number of
// bytes read. It may return the (non-nil) error from the same call
// or return the error (and n == 0) from a subsequent call.
// An instance of this general case is that a Reader returning
// a non-zero number of bytes at the end of the input stream may
// return either err == EOF or err == nil. The next Read should
// return 0, EOF.
// ...
type Reader interface {
    Read(p []byte) (n int, err error)
}
```

io.Reader接口的Read方法，在读取到结束状态时，既可以n返回非0值的同时返回读取结束（非nil）的错误，也可以在下一次调用时n返回0的时候返回读取结束的错误。首先，这个约束无法用Go的语法描述出来，只能通过注释的方式写明。其次，这个约束其实描述了两种不同的处理方式，导致这个函数语义与其他Go函数返回错误的语义完全不一致（比如NewXXX()类的函数语义就是有错误不创建，创建成功没错误）。

一个比较好的解决这种问题的方案就是更新类型系统。Go的类型组合可以认为是一个“和”类型的语义，但是缺乏组合“或”的语义。如果可以用`A | B`来表示某个类型是“类型A或类型B”，那么上一个接口就可以表示为：

```go
type Reader interface {
    Read(p []byte) (int | error)
}
```

这样，Read函数就非常明确的表示出，要么返回读取成功的字节数，要么读取错误。

“或”类型有另外一个好处，就是可以将nil定义为一个单独的类型，所有的*类型，都可以认为是某个类型`T | nil`的另一种写法。而nil类型只有唯一的一个值nil。这样就可以避免Go里令人恼火的另一个问题`(*int)(nil) != nil`。

这里涉及到一个后续的问题，如何处理错误。即便有了或语义，可能错误处理会类似：

```go
ret := f.Read(p)
if err := ret.(error); err != nil {
    // block a
    return
}
// block b
```

这个至少看上去，不比原来的`if err != nil`要差（反正原来打字也要写不少）。不过问题在于，ret的类型为int或error，而if语句已经判断了ret为error的情况，那么在block a里，ret的类型应当自动被识别成error，而由于有return的存在（假设没有跨语句块的goto），block b里应当可以将ret当作int来直接使用，而不需要再次cast。否则使用ret的时候就会显得很啰嗦。不过这种判断并不好实现，if内部可能没有return，而是用某种panic的手段来停止程序，而这个panic可能会隐藏在很深的函数里。同时goto的存在会让整个情况更加难以判断。如果是某种可以恢复的if语句，会让整个逻辑更加复杂，比如：

```go
f := io.Open(file)
if err := f.(error); err != nil {
    f = io.Create(file)
    if err := f.(error); err != nil {
        return err
    }
}

// f should be file, not error
```

另一种可行的方法是类似Rust的match，或者说让switch支持返回值的方式，来处理返回值。比如：

```go
f := switch v := io.Open(file).(type) {
case error:
    return v
default:
    v
}
```

其中`return v`依旧是退出外部函数的语义，而`default`分支里的`v`则是switch语句整体的返回值，会赋值给f。不过总觉得这样的处理语句并不如if来的明确。另外，如果在error分支里需要做一些处理，则会让switch语句有很深的嵌套。

当然，类似Rust实现一个`Result<T, E>`类型也是个办法，但这就需要语言具备处理泛型的能力。是否要支持泛型，已经是Go的月经问题，在此不做展开讨论。

另外，Go的多值返回目前看起来也是一个不够完善的特性。函数的多值返回是个需求，但是由于Go的类型系统没有“轻量”组合类型的能力，导致不得不增加一个特殊语法来支持多值返回。如果Go的类型系统支持其他语言里的元组（Tuple）概念，则可以通过类型系统达到更广泛的支持。

所谓元组，就是`(A, B)`会定义一个新类型，包含A和B两个类型。如果元组还支持匹配赋值的能力的话，就可以这样实现多值返回：

```go
func f() (int, bool) {
    return 1, true
}

(i, ok) := f()
```

如果配合之前的类型“或”的能力，就能实现更加复杂的函数约束：

```go
func f() ((int, bool) | error) {
    ...
}

ret := f()
if ret.(error) != nil {
    return
}

(i, ok) := ret
```

不过这样的话，括号`()`就会具有两种语义：改变表达式优先级和定义元组。这个大概不太符合Go的语法习惯。

如果展开一点，将error作为环境上下文来看待，类比Haskell的Monad的话，可以将error作为一个附加在函数上的上下文，根据error的值来做处理：要么退出一个语句块，要么经过处理回复error。其实其他语言里的try/catch就是这种环境的一个实现。只不过，在支持Monad的类型里，可以不依赖编译器的语法，来实现类似try/catch。

既然这里提到了Monad，多说一下。Go的defer/context，目前在Python和Node.js里大热的future，都是类似的给函数附加上下文的语义。比如，defer附加了延迟执行的功能，contenxt附加了deadline和一些值，future附加了异步执行的功能。甚至顺序执行本身，都可以看作一组函数，根据顺序附加了执行先后次序（IO Monad）。

Monad利用回调机制，将函数注册到一个符合某个Monad的类型的实例里，然后由这个实例，按照某种规则，调用所有/部分注册进来的函数。

```go
type Maybe struct {
    f []FuncType
}

func (m *Maybe) Map(f FuncType) {
    m.f = append(m.f, f)
}

func (m *Maybe) Do(arg ArgType, ...) RetType {
    for _, f := range m.f {
        ret := f(arg, ...)
        if ret.(error) != nil {
            return ret
        }
        (arg, ...) = ret
    }
}
```

为了让Monad足够灵活，不能对回调函数做过多限制，所以经典的泛型方案也不能完全实现Monad的意图。比如，刚才的代码是无法写出FuncType的定义的。FuncType看上去应该是`func (...) ...`类型， 同时要求返回的值必须存在error的可能。如果利用上面提到的机制，就是类似`func (...) (... | error)`。为了保证灵活，函数的签名部分不能约束参数个数，而返回值其他的可能类型也不能被约束。利用泛型，可以做到返回值的其他可能类型不被约束，但是无法做到不约束参数个数。所以即便支持了泛型，也无法完全实现Monad。

Haskell等函数式语言对此的解决办法是，函数柯里化。对于`func (a A, b B, c C) D`，将其看作`f: A -> B -> C -> D`，这样，就可以不管函数有多少个输入参数，统一写为`X -> Y`，对于刚才的f，有`X := A, Y := B -> C -> D, f: X -> Y = A -> (B -> C -> D) = A -> B -> C -> D`。柯里化后，FuncType就可以直接定义为`FuncType: X -> Monad Y`。对于返回的约束，由于Haskell支持高阶类型，所以并不是直接约束返回值，而是将Monad定义为一个高阶类型，并且要求`Map: Monad X -> (X -> Monad Y) -> Monad Y`，从而让Map可以对Monad链式执行。

上面Maybe类型实现时，另一个无法做到的事情是，如何在Do里将不确定个数的参数传递到内部函数调用f上。和之前分析一样，这个无法使用泛型来解决，而Haskell依旧使用柯里化避免了这个问题。

另一方面，go generate也无法辅助定义FuncType。假设可以用某种WrapFunc来包装FuncType的实例，使其类型统一变成某个类型WrappedFunc，而这个WrapFunc可以通过go generate的方式执行，检查某个func的签名并生成一段特殊的代码来实现Wrap功能。那么，当对属于另外的package的func做Wrap时，比如：

```go
maybe.Map(wrap(os.Open, "..."))
```

如果要生成wrap，需要知道os.Open的函数签名。而使用go generate解析函数签名的时候，需要拿到对应的源代码。也就是说，如果我能写出一个generator，这个generator需要实现一部分go编译器的行为：根据import查找对应的源代码。而这个行为，和go generate的设计用途不一致，实现起来也会有很多问题。

我个人还是很希望Go 2能有一种方法，能够对某类类型批量生成一系列的行为，而不用为每个类型手写一遍。
