+++
date = "2013-12-31T10:48:24+08:00"
title = "go-rest演化"
category = "development"
tags = ["golang", "restful"]
+++

在EXFE创业的两年，虽然项目最终失败了（很可惜），不过自己从头开始写了一个简化RESTful Service实现的Framework——[go-rest](https://github.com/googollee/go-rest)，还算有不少收获。这里记录一下go-rest实现过程中一些重要的演变，以及这些演变背后的原因。

<!--more-->

最开始，我把Service定义为RPC remote式的调用方法。处理逻辑的函数，基本上是这样：

```go
func Handler(input InputType) OutputType { ... }
```

框架主要是解决HTTP协议的处理，以及将Request Post的body部分反序列化为InputType的实例，根据url调用相应的函数，并序列化函数的输出结果。

因此，当时的框架使用起来类似下面的样子（因为最老的一版代码找不到了，这个是凭印象写的）：

```go

func Handler1(input InputType) OutputType { ... }
func Handler2(input InputType) (OutputType, error) { ... }

func main() {
	r := rest.New()
	r.Add("/handler1", Handler1)
	r.Add("/handler2", Handler2)

	http.ListenAndServe(":8000", r)
}
```

优点：

- 自动处理HTTP协议，根据mime选择合适的序列化方法；
- 自动将Request Body和Response Body序列化/反序列化为对应的参数结构，处理函数内不需要考虑序列化问题；
- 逻辑函数易于测试。

缺点：

- 无法自定义任何HTTP协议的处理过程，无法做url参数化或者对url的参数做处理，无法使用HTTP Header信息；
- 只能固定使用POST方法做请求；
- 返回值格式固定，如果出错（处理函数的error返回不为nil），只能使用500一种返回码，调用者无法知道错误细节；

为了解决缺点，最开始使用gorilla/mux库做路由，解决了不能自定义HTTP method的问题。之后为了利用起HTTP协议本身的各种参数化和配置方法，达到更加RESTful的状态，go-rest第二版引入了Context的概念。在注册处理函数时，参考[gorest](https://code.google.com/p/gorest/)也引入了使用将struct做配置的方法。

第二版里定义一个用于处理逻辑的struct如下所示：

```go
type RestExample struct {
    rest.Service `prefix:"/prefix" mime:"application/json"`

    postSample rest.SimpleNode `method:"POST" route:"/post"`
    getSample  rest.SimpleNode `method:"GET" route:"/get/:id"`
}

func (r *RestExample) PostSample(ctx rest.Context, arg InputType) {
    ...
}

func (r *RestExample) GetSample(ctx rest.Context) {
    var id int
    ctx.Bind("id", &id)
    if err := ctx.Error(); err != nil {
        ctx.Return(http.StatusBadRequest, err.Error())
        return
    }
    ...
}
```

优点：

- url配置更加灵活，可以为每个Service分别添加前缀；
- 参数化url，可以写表达性更强的url，而且可以保证处理函数不需要牵涉到HTTP协议的细节；
- 可以使用Context来访问HTTP报文相关内容，比如拿到Request Header，或者改变HTTP Response Code（见GetSample）；
- 使用Context.Bind来处理url参数解析，声明式比过程式更易懂；
- 配置统一定义在RestExample里。

缺点：

- 使用Context处理HTTP相关信息的时候引入了HTTP协议细节，不易测试；
- 函数名和配置变量对应依靠首字母大小写来对应，过于隐晦；
- 没有中间层，对于一些通用处理显得繁琐，比如log，auth等。

因为要对HTTP的细节作处理（Header，url参数化等等），而引入的Context，最终却变成了逻辑函数里额外的部分，导致测试时需要花费很大精力准备一个合法的Context，是这次变动中最失败的部分。但是由于更加符合业务要求，实现出来的接口更容易理解且符合RSETful的要求，这个实现大概维持了1年左右没有变化。

后来团队解散后空余时间比较多，也因为Node.js很火爆，就跑去看了看Node.js上最流行的框架Express.js。Express.js使用的Connect库做到的中间件很有意思。借鉴Connect的中间件思想，就有了go-rest最新的一次改版。这次改版的主要思路在于，使用中间件来处理与HTTP协议相关的逻辑，保持最终的业务逻辑是一个独立的函数，不引入任何与框架相关的约束和假设。改版后的框架使用起来像下面这个样子：

```go

r := rest.New()

// add log midware
r.Use(rest.NewLog(nil))

// add router. router must before mime parser because parser need handler's parameter inserted by router.
r.Use(rest.NewRouter())

// parse json
r.Use(rest.NewJSON()))

// get sample
r.Get("/get/:id", func(params rest.Params) error {
    var id int
    params.Bind("id", &id)
    if err := params.Error(); err != nil {
        return resp.Error(http.StatusBadRequest, err.Error())
    }
    ...
})

// post sample
r.Post("/post", func(arg InputType) {
	...
})

// custom midware
func prefix(prefix string) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        if !strings.HasPrefix(r.URL.Path, prefix) {
            http.NotFound(w, r)
            return
        }
    }
}

// a handler with special midware
r.NotFound(prefix("/static/"), http.FileServer(http.Dir(".")))
```

由于有了灵活的中间件机制（通过Use引入），可以将所有和HTTP解析相关的代码改写为中间件并复用。同时，可以给每个处理函数单独配置自己的中间件，这样不同处理函数也可以复用一些相似的逻辑。需要从HTTP内解析出的变量，通过rest.Params传入处理函数。而rest.Params只是map[string]interface{}的简单封装，测试时很容易构造其中的内容。Params.Bind的部分目前还没有实现，其实这部分可以通过中间件完成的，写在这里是为了展示效果。如果error返回的不是一个rest.Response或者rest.Error，HTTP就会以StatusServerInternalError作为Response Code。

这个框架本身还可以支持多参数的处理函数，不过要自己写相应的中间件对参数顺序做布局。由于通用性不高，我就没有实现相关的内容。

这个框架的优点：

- 中间件机制灵活，可以对某个处理分支加入单独的中间件；
- 处理函数与HTTP协议无关，方便测试和重构；
- 中间件可以改变处理函数需要的参数和返回值的类型，支持类似wrapper的特性而不需要改动业务处理函数。

缺点：

- 实现有一些精巧的不易理解的部分，使用时容易造成困惑；
- 看上去接口并不清晰。
