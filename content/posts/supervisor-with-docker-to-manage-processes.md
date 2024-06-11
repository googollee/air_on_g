+++
date = "2014-03-28T19:46:44+08:00"
title = "在Docker里使用（支持镜像继承的）supervisor管理进程"
category = "development"
tags = ["docker", "operation"]
+++

这篇文章是受[Dockboard](http://dockboard.org)之托帮忙翻译的与docker有关的技术文章。[Dockboard](http://dockboard.org)致力于在中国建立一个Docker技术的开放社区。

<!--more-->

本文译自[Using Supervisor with Docker to manage processes (supporting image inheritance)](http://blog.trifork.com/2014/03/11/using-supervisor-with-docker-to-manage-processes-supporting-image-inheritance)，作者Quinten Krijger。

![Docker-logo](http://blog.trifork.com/wp-content/uploads/2013/08/Docker-logo.png)

在八月份，我写了一篇关于如何创建tomcat镜像的[blog](http://blog.trifork.com/2013/08/15/using-docker-to-efficiently-create-multiple-tomcat-instances/)。从那以后，docker又改进了很多，我对docker的了解也增加了很多。我很高兴和你分们享我找到的关于管理container进程的好办法。在读完这篇文章后，我希望你能善加利用我[github仓库](https://github.com/Krijger/docker-cookbooks)里的supervisor镜像。

## Docker命令

在之前的文章里，我提到Docker（只能）支持运行一个前台进程。我们通常习惯使用类似upstart这种管理服务来初始化启动流程，但是Docker默认没有这些服务的支持。刚开始使用Docker时会很不习惯，你必须指定你想要运行的进程。这种行为和虚拟机相比有个优点，会尽可能的保持轻量的container。你可以通过run命令最后的参数，在启动container时指定进程命令，比如：

	docker run ubuntu echo "hello world"

另外一种方法，你可以利用[CMD](http://docs.docker.io/en/latest/reference/builder/#cmd)指令，在Dockerfile里指定docker run命令的默认参数。比如，如果你目录下的Dockerfile包含以下内容：

	FROM ubuntu
	CMD echo "hello world"

再使用下面的指令构造`hello_world_printer`镜像：

	docker build -t "hello_world_printer" .

使用下面的命令，你可以得到和之前run命令相同的执行结果。

	docker run hello_world_printer

要注意，因为你可以覆盖掉CMD指定的命令行参数，这个只是个运行时的指令。有趣的事情是，在Linux container里，你可以只调用upstart命令然后得到和普通虚拟机大致相同的行为。

## 运行多个命令

运行多个进程是个很正常的想法。比如，一个ssh服务（这样就能登录到正在运行的container）和实际的应用。你可以用下面的方法运行container：

	docker run ... /usr/sbin/sshd && run_your_app_in_foreground

这在开发时很方便。这样，当应用进程退出后，因为唯一的前台程序退出了，container会自动关闭。当然你可以使用`using /usr/bin/sshd -D`保证container不会退出，但是这里真正的问题是，这种使用run命令设置初始程序的方式不够简洁。而且，随着你的container变复杂，run命令会越来越长。

所以，在运行更复杂的container的时候，很多人使用复杂的bash脚本。典型的bash脚本会执行一个前台进程，并开启一个或者多个（renegade）守护进程。与只是用Docker命令行的方式相比，这种方法最重要的改进在于，bash脚本是可以做版本控制的：启动脚本在你的Docker镜像里，新的改动可以和软件项目一起分发。不过，使用bash脚本管理进程依旧简陋枯燥，而且容易出错。

## ……使用supervisor


更好的方法是使用[supervisor](http://supervisord.org/)。supervisor可以更好的管理进程：使用更加简洁的代码管理进程；在崩溃时可以重启进程；允许重启一组进程并且有命令行工具和网页界面来管理进程。当然，越大的能力要求越大的责任：大量使用supervisor特性的代码，预示着你应该将整个服务更好的拆分成多个小的supervisor来管理。

个人来讲，我喜欢supervisor让我用更清晰的代码管理启动的进程。我见过最简洁的使用例子，是子镜像扩展出一个进程组。比如，如果你经常使用SSH，使用一个SSH镜像作为基础镜像就是很合理的。这种情况，在所有基于这个镜像的扩展镜像上实现启动SSH进程的代码，形式少就是一种重复代码。我来给你们展示下我找到的解决这个问题的好办法。

## supervisor基础镜像

首先，因为我默认使用supervisor，所以我所有的镜像都扩展自一个只包含supervisor和最新版本ubuntu的基础镜像。你可以在[这里](https://github.com/Krijger/docker-cookbooks/blob/master/supervisor/Dockerfile)找到这个Dockerfile。这个基础镜像包括一个配置文件`/etc/supervisor.conf`：

	[supervisord]
	nodaemon=true

	[include]
	files = /etc/supervisor/conf.d/*.conf

这个配置让supervisor本身以前台进程运行，这样可以让我们的container启动后持续运行。第二，这个配置将包含所有在`/etc/supervisor/conf.d/`目录下的配置文件，启动任何在这里定义的程序。

## 扩展基础镜像

![tomcat-stack](http://blog.trifork.com/wp-content/uploads/2014/02/tomcat-stack-164x300.png)

是的，想法很简单。所有的子container通过将特定的service.sv.conf放到特定的目录的方式，将其自己的服务加入到supervisor的管理里。之后，使用如下命令启动container：

	docker run child_image_name "supervisor -c /etc/supervisor.conf"

会自动启动所有指定的进程。你可以对镜像做多层扩展，每层扩展加入一个或者多个服务到配置目录。在Docker里使用supervisor启动命令代替upstart也更有效和有范。

作为例子，让我们看看之前blog提到的Tomcat工作栈，是如何使用这种改进后的方法的。

 - 首先，和之前讨论的一样，我们使用从ubuntu扩展而来的supervisor基础镜像

 - 之后，我们使用在supervisor上安装了Java的[JDK镜像](https://github.com/Krijger/docker-cookbooks/tree/master/jdk7-oracle)。Java只是其他服务使用的库，所以我们在这层不指定任何启动服务。这层要做一些类似设置JAVA_HOME环境变量的通常任务

 - Tomcat镜像在工作栈上安装Tomcat并暴露8080端口。这层包括一个名字是Tomcat的服务，定义在[tomcat.sv.conf](https://github.com/Krijger/docker-cookbooks/blob/master/tomcat7/tomcat.sv.conf)：

		[program:webapp]
		command=/bin/bash -c "env > /tmp/tomcat.env && cat /etc/default/tomcat7 >> /tmp/tomcat.env && mv /tmp/tomcat.env /etc/default/tomcat7 && service tomcat7 start"
		redirect_stderr=true

	执行Tomcat服务的命令并不像我喜欢的那样简洁，将其放到一个专门的脚本里会更好。命令先添加了一些环境变量，比如[container的关联参数](http://docs.docker.io/en/latest/use/working_with_links_names/)，到`/etc/default/tomcat7`，这样我们可以在之后的配置中使用这些参数，后面的例子会展示这种用法。也许使用类似etcd的键值存储会更好，不过这超出了本文的范畴。

	当然，我们这里只安装了默认的文件，没有真正的网络应用程序。

 - 你的网络应用程序应当扩展自Tomcat镜像，并安装入真正的应用程序。当启动supervisor的时候，会自动启动Tomcat。

## 一个Tomcat网络程序的Dockerfile例子

如何安装实际的网络应用超出了本文的范畴，不过，作为结束，我给出了个Dockerfile例子，演示如何使用这个工作栈。这个例子完全基于Java Tomcat，所以如果你对这个不感兴趣，别读了，玩别的去吧:)

假设，我们有一个使用Elasticsearch的网络应用：

	FROM quintenk/tomcat:7

	# 安装一些项目的依赖，这些依赖在每次更新时不会改变
	# RUN apt-get -y install ...

	RUN rm -rf /var/lib/tomcat7/webapps/*

	# 将配置加入/etc/default/tomcat7，比如：
	...
	RUN echo 'DOCKER_OPTS="-DELASTICSEARCH_SERVER_URL=${ELASTICSEARCH_PORT_9200_TCP_ADDR}"' >> /etc/default/tomcat7
	RUN echo 'CATALINA_OPTS="... ${DOCKER_OPTS}"' >> /etc/default/tomcat7

	# 加入类似log4j.properties的配置文件，并将其chown root:tomcat7

	# 假设项目已经构建好了，而且ROOT.war在你构建Docker的目录（包含Dockerfile的目录）。基于缓存的考虑，这个作为最后的步骤
	ADD ROOT.war /var/lib/tomcat7/webapps/
	RUN chown root:tomcat7 /var/lib/tomcat7/webapps/ROOT.war

	CMD supervisord -c /etc/supervisor.conf

这段代码里，elasticsearch的相关环境变量（搜索索引）已经被设置了，因为supervisor关于Tomcat的配置，会在启动时将所有环境变量添加到/etc/default/tomcat7。当然，我们在启动网络应用镜像时需要关联到elasticsearch containter，比如：

	docker run -link name_of_elasticsearch_instance:elasticsearch -d name_of_webapp_image "supervisor -c /etc/supervisor.conf"

你现在的网络应用可以去访问`ELASTICSEARCH_SERVER_URL`路径了。你可以在配置文件里使用这个变量，像这样：

	elastic.unicast.hosts=${ELASTICSEARCH_SERVER_URL}

这样就可以将配置暴露给你的应用程序。如果你是个Java开发者，并且也阅读了前一篇文章，希望这让你能开始一段愉快的代码之旅。
