---
title: "使用Go Swagger生成OpenAPI定义"
date: 2021-12-04T11:11:08+01:00
categories:
 - 开发
tags:
 - go
 - go-swagger
 - openapi
 - swagger
cover:
  image: /images/go-swagger-spec.jpg
author: "Googol Lee"
---

[OpenAPI](https://swagger.io/specification/)（原名Swagger）是目前比较流行的定义HTTP API的协议。但是OpenAPI的定义文件是方便机器处理的格式，不易编写和阅读。这里介绍一种使用[go-swagger](https://goswagger.io/)，根据Go代码生成OpenAPI定义文件的方法。该方法只使用Go代码来定义API，不强求Server或者Client也使用Go。

目前`go-swagger`只能生成OpenAPI 2.0格式的定义。这个也是现在广泛使用的格式。`go-swagger`未来会支持OpenAPI 3.0。

本文假设已经熟悉Go语法，只对`go-swagger`的扩展部分进行详细解释。

<!--more-->

假设要为一个宠物商店创建一套API。这套API支持定义宠物（Pet）。本文展示如何使用Go来定义这个API。

虽然`go-swagger`不强求使用Go工程，不过为了便于利用补全和代码高亮，这里还是推荐为API单独创建一个Go工程。

首先是定义API的基础信息，比如这套API的名字，协议，支持的序列化格式，基础路径，以及一些安全信息。这些信息定义在`petstore.go`文件里。

```go
// Package petstore The API of the pet store.
//
// The pet store is a demo service to show how to use go-swagger generate
// OpenAPI (Swagger) Spec.
//
// Version: 1.0.0
// BasePath: /v1/petstore
// Schemes: https
// Consumes:
// - application/json
// Produces:
// - application/json
//
// swagger:meta
package petstore

//go:generate go run github.com/go-swagger/go-swagger/cmd/swagger@latest generate spec -o openapi.yaml
//go:generate go run github.com/go-swagger/go-swagger/cmd/swagger@latest validate openapi.yaml
```

根据Go的规范，包的说明，要以`Package petstore`开头。该行的剩余部分，也就是`The API of the pet store.`会作为OpenAPI的`title`部分，其余非`go-swagger`定义的注释，会作为OpenAPI的`description`。

> 注意：如果包说明里不包含`description`的部分，`go-swagger`会把第一行原本作为`title`的部分作为`description`，并把`title`留空。这样定义的OpenAPI文件不符合规范。所以请把两段描述写完整。

从`Version:`行开始，是对`go-swagger`的定义。这部分定义了生成的OpenAPI文件其他基础内容。具体可用的选项可以参照[swagger:meta](https://goswagger.io/use/spec/meta.html)。最后一行的`swagger:meta`表示这段注释用于`go-swagger`生成基础信息。

之后的两行`go:generate`用来生成OpenAPI文件。为了保证执行时不会缺少可执行文件，这里使用`go run github.com/go-swagger/go-swagger/cmd/swagger@latest`来调用`go-swagger`。如果可以保证执行环境已经安装了`go-swagger`，这两行`go run ...`可以直接简化为`swagger`。简化后会提高生成时的执行速度。

> 安装`go-swagger`可以参照[官网](https://goswagger.io/install.html)。如果有Go环境，可以直接通过`go install github.com/go-swagger/go-swagger/cmd/swagger@latest`安装。注意需要把`$GOPATH/bin`加入到`$PATH`里，方便执行。

第一行`generate spec -o openapi.yaml`会根据当前目录的内容，生成OpenAPI文件。第二行`validate openapi.yaml`会验证这个OpenAPI文件是否合规。

有了这个文件，就可以通过执行`go generate .`来生成OpenAPI文件。执行后会生成：

```bash
$ cat openapi.yaml 
basePath: /v1/petstore
consumes:
- application/json
info:
  description: |-
    The pet store is a demo service to show how to use go-swagger generate
    OpenAPI (Swagger) Spec.
  title: The API of the pet store.
  version: 1.0.0
paths: {}
produces:
- application/json
schemes:
- https
swagger: "2.0"
```

我们还没有定义任何API，所以`paths`字段为空。后面会逐步补充这个字段的内容。

之后在`pet.go`文件里定义与Pet实例相关的API。

首先定义`Pet`结构：

```go
// NewPet provides data to create a pet.
//
// swagger:model
type NewPet struct {
        // The name of the pet.
        //
        // min length: 1
        // max length: 64
        // example: Yuki
        Name string `json:"name"`
        // The contact email for the pet.
        //
        // min length: 1
        // max length: 64
        // example: person@domain.com
        // swagger:strfmt email
        Contact string `json:"contact"`
}

// Pet provides data of a pet.
//
// swagger:model
type Pet struct {
        // The pet id.
        //
        // example: 1
        ID uint64 `json:"id"`
        // The name of the pet.
        //
        // example: Yuki
        Name string `json:"name"`
        // The contact email for the pet.
        //
        // example: person@domain.com
        // swagger: strfmt email
        Contact string `json:"contact"`
}
```

其中`NewPet`用于创建和修改Pet数据，`Pet`用于展示Pet数据。这两个结构有一些细微差别，比如`NewPet`不会具有`ID`信息，另外`Pet`不需要定义输入限制。在简单场景下，可以合并为一个结构，或者将`NewPet`匿名嵌入`Pet`，简化结构。

`swagger:model`会被`go-swagger`处理为预定义好的结构，并将定义放入`definitions`里。这个结构会在多个API操作方法间复用。

`go-swagger`会根据Go结构的类型，生成对应的类型。每一个字段的注释，可以指定更详细的[值约束](https://goswagger.io/use/spec/model.html#properties)，比如例子中的`min length: 1`和`max length: 64`，就约定了对应字段字符串的长度应该在`[1, 64]`之间。还可以使用[`swagger:strfmt`](https://goswagger.io/use/spec/strfmt.html)对字符串值做进一步的语义约束。

为了在处理出错可以返回另外的结构，还需要定义错误结构：

```go
type Error struct {
        ID     string `json:"error_id"`
        Detail string `json:"error_detail"`
}
```

简单的结构可以不用写明所有的信息，甚至不用标记`swagger:model`。`go-swagger`会自动根据之后方法的定义，来查找对应的结构定义。

处理的结构定义好后，就可以定义具体的操作方法。为了覆盖最广泛的情况，这里以更新`Pet`的方法作为讲解例子。

```go
// swagger:route POST /pets/{pet_id} pet UpdatePet
//
// Update data of a pet.
//
// responses:
//   200: PetReply
//   default: ErrorReply
```

`swagger:route`用来定义一个具体的API方法，格式是`swagger:route <method> <url> <tag> ... <operation id>`。其中`tag`可以有0个或者任意个，给这个方法加上若干个标签。不管有多少`tag`，最后一个参数`operation id`是这个方法的名字。在一个API定义文件里，这个方法名字需要具有唯一性。

具体到例子里，`swagger:router POST /pets/{pet_id} pet CreatePet`的含义如下：

- 遵循常用的API原则，将更新方法定义在`POST /pets/{pet_id}`端点。
  - 路径有一个输入参数`pet_id`。
- 给这个方法加入`pet`标签。
- 方法名字为`CreatePet`。

之后是方法的说明信息。

`responses`是定义`go-swagger`的返回信息，可以根据不同的HTTP Code定义不同的结构。例子里在操作正常也就是`Code 200`时返回`PetReply`结构，其他情况下返回`ErrorReply`结构。

先放下输出结构，看一下如何定义输入结构。

```go
// swagger:parameters UpdatePet RetrievePet DeletePet
type PetIDArg struct {
        // in: path
        ID uint64 `json:"pet_id"`
}

// swagger:parameters CreatePet UpdatePet
type NewPetArg struct {
        // in: body
        NewPet *NewPet
}
```

`swagger:parameters`用来定义个输入结构，格式是`swagger:parameters <operation id> <operation id> ...`。其中`operation id`是用到这个输入结构的方法名字。需要注意的是，可以有多个输入结构用在一个方法上，比如例子里的两个结构都引用了`UpdatePet`。因为一个方法的输入，不仅有HTTP Post报文，还有URL里面的信息，甚至可能会从Header里拿信息。为了能复用这些结构，`go-swagger`可以将不同部分的输入，定义到不同的结构里，并引用到同一个方法上。

例子里，`PetIDArg`通过`in: path`定义了路径参数`pet_id`，其中`pet_id`是用过`json:"pet_id"`定义的。另一个结构`NewPetArg`通过`in: body`定义了Post报文结构`NewPet`，其中`NewPet`是上文描述过的一个结构。

之后是输出结构。

```go
// PetReply returns a pet.
//
// swagger:response
type PetReply struct {
        // in: body
        Pet *Pet
}

// ErrorReply replys an error of API calling.
//
// swagger:response
type ErrorReply struct {
        // in: body
        Error Error
}
```

`swagger:response`用来定义一个输出结构。其名字与`swagger:route`定义的`responses`相同。`in: body`表示对应的字段用于返回的HTTP报文。

至此，Pet的更新方法定义完成。也解释了`go-swagger`绝大部分内容。可以直接执行`go generate .`或者`swagger generate spec`查看输出。关于使用`go-swagger`生成规范文件的更多细节，可以查阅[官网](https://goswagger.io/use/spec.html)。

作为例子，下面的`pet.go`文件给出了Pet操作的所有定义。配合之前提到的`petstore.go`文件，可以直接用来生成`petstore`的OpenAPI定义。

```go
package petstore

// NewPet provides data to create a pet.
//
// swagger:model
type NewPet struct {
	// The name of the pet.
	//
	// min length: 1
	// max length: 64
	// example: Yuki
	Name string `json:"name"`
	// The contact email for the pet.
	//
	// min length: 1
	// max length: 64
	// example: person@domain.com
	// swagger:strfmt email
	Contact string `json:"contact"`
}

// Pet provides data of a pet.
//
// swagger:model
type Pet struct {
	// The pet id.
	//
	// example: 1
	ID uint64 `json:"id"`
	// The name of the pet.
	//
	// example: Yuki
	Name string `json:"name"`
	// The contact email for the pet.
	//
	// example: person@domain.com
	// swagger: strfmt email
	Contact string `json:"contact"`
}

// swagger:parameters UpdatePet RetrievePet DeletePet
type PetIDArg struct {
	// in: path
	ID uint64 `json:"pet_id"`
}

// swagger:parameters CreatePet UpdatePet
type NewPetArg struct {
	// in: body
	NewPet *NewPet
}

// PetReply returns a pet.
//
// swagger:response
type PetReply struct {
	// in: body
	Pet *Pet
}

// PetsReply returns a list of pets.
//
// swagger:response
type PetsReply struct {
	// in: body
	Pets []*Pet
}

type Error struct {
	ID     string `json:"error_id"`
	Detail string `json:"error_detail"`
}

// ErrorReply replys an error of API calling.
//
// swagger:response
type ErrorReply struct {
	// in: body
	Error Error
}

type ErrorInput struct {
	Error
	Fields map[string]Error `json:"error_fields"`
}

// ErrorInputReply replys an error with details of input data.
//
// swagger:response
type ErrorInputReply struct {
	// in: body
	ErrorInput ErrorInput
}

// swagger:route GET /pets pet ListPet
//
// Get the list of pets.
//
// responses:
//   200: PetsReply
//   default: ErrorReply

// swagger:route POST /pets pet CreatePet
//
// Create a new pet.
//
// responses:
//   200: PetReply
//   default: ErrorReply

// swagger:route POST /pets/{pet_id} pet UpdatePet
//
// Update data of a pet.
//
// responses:
//   200: PetReply
//   default: ErrorReply

// swagger:route GET /pets/{pet_id} pet RetrievePet
//
// Get data of a pet.
//
// responses:
//   200: PetReply
//   default: ErrorReply

// swagger:route DELETE /pets/{pet_id} pet DeletePet
//
// Delete a pet.
//
// responses:
//   200: PetReply
//   default: ErrorReply
```
