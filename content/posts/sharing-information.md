+++
date = "2007-07-03T20:00:00+08:00"
title = "共享信息"
category = "geek"
tags = ["sharing", "recurring"]
+++

题目是这样的：三个学生去教授家里帮忙收拾花园，比较辛苦，三个人的脸上都沾上了泥，但自己并不知道。休息的时候，教授对他们说：不要摸，你们三个中至少有一个人脸上有泥，有泥的人去洗掉。假设三个学生足够聪明，结果谁会去洗呢？

<!--more-->

答案：三个学生互相看着，过了一段时间，同时起身去洗脸。

恩……由于没有时钟同步，“同时起身”这个概念并不好判断。不过，推理的过程还是一样的：如果只有一个人头上有泥，那么他看到别人头上都没有泥，就应该立刻起身，但事实是没有人立刻起身，因此至少两个人头上有泥；如果两个人头上有泥，那么看到只有一个人头上有泥的人就应该在第二刻（这就是我说没有时钟同步的坏处）起身去洗脸；因为前两刻都没有人去洗脸，所以一定三个人脸上都有泥。

其实，更好的题目是那个戴帽子的或者大女子主义村的题。不过我一下子记不起原题是怎么描述的了，大家自己去google吧。

更深一步的想一下：教授说的话，到底告诉三个学生什么了，导致他们发现自己脸上都有泥呢？按说，每个人都会看到另外两个人脸上的泥，因此，教授实际上说了一句他们都已经知道的话，应该是推不出任何东西的！

其实，教授的那句话里还包含了另一层意思，也就是告诉了三个学生一个共享信息。

什么是共享信息？每个人都知道的事实么？这还远远不够。共享信息还需要每个人都知道别人也知道这件事。比较形式化的定义是：X是共享信息，等价于命题Y成立，命题Y为“X且所有人知道Y”。

实际上，这里递归了。

三个学生在思考的每一刻后，这个共享信息都会递归进入一层。一开始是“某一个人脸上有泥”，第二刻是“某两个人脸上有泥”，第三刻是“某三个人脸上有泥”，这时，递归到达了最大深度，于是三个人就直接“弹栈”洗脸去了。

更加形式化的给出一个定义：

Pi是第i个人知道的信息集合，X是某个信息。共享信息是Y={X且对任意i，有Y属于Pi}

这里有一个问题，在递归时，所有人并不明确的知道“哪一个人”或者“哪两个人”脸上有泥（“哪三个人”的时候其实也不知道，但现在一共就三个人，根据不相容抽屉原理可以推出“所有人”）。但这并不妨碍做进一步的推断。这实际是集合论一个备受争议的公理——选择公理——的表现形式。

选择公理是指：有若干个非空集合，可以从每个集合中取出一个元素，组成一个新集合。

很可惜我忘了这条公理的形式化定义。但印象深刻的是，这个公理只是指出了组成新集合的可能性，却并没有指出该如何取，来组成这个新集合。数学界对这条公理的合理性还有争议。因为如果不承认这条公理，就无法得到很多很重要的定理；但如果承认这条公理，又会推出很多悖论。