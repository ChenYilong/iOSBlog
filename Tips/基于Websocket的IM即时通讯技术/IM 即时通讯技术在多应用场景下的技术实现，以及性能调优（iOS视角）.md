# IM 即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）

演讲视频（上下两部，时长将近2个半小时）以及 PPT 下载：链接: https://pan.baidu.com/s/1FfhxcRImvwL7w38ZXnnzaw 密码: hb1y

油管在线观看  [《IM 即时通讯技术在多应用场景下的技术实现，以及性能调优（ iOS 视角）（附 PPT 与 2 个半小时视频）》]( https://youtu.be/yIOlzzA_dRQ "") 


2016年9月份[我](https://github.com/ChenYilong)参加了 MDCC2016（中国移动开发者大会），

![2016年9月份我参加了 MDCC2016（中国移动开发者大会）](http://ww2.sinaimg.cn/large/006tNbRwjw1f9bkx4tiuqj30qo0zk0vd.jpg)

在 MDCC2016 上我做了关于 IM 相关分享，会上因为有50分钟的时间限制 ，所以有很多东西都没有展开，这篇是演讲稿的博文版本，比会上讲得更为详细。有些演讲时一笔带过的部分，在文中就可以展开讲讲。

![图为我正在演讲](http://ww4.sinaimg.cn/large/006tNbRwjw1f9bkx4u3oqj30qo0zkq4h.jpg)

注：

  - 本文中所涉及到的所有 iOS 端相关代码，均已100%开源（不存在 framework ），便于学习参考。
  - 本文侧重移动端的设计与实现，会展开讲，服务端仅仅属于概述，不展开。
  - 为大家在设计或改造优化 IM 模块时，提供一些参考。

我现在任职于 [LeanCloud（原名 `AVOS` ）](https://leancloud.cn/?source=T6M35E4H) 。LeanCloud 是国内较早提供 IM 服务的 Paas 厂商，提供 IM 相关的 SDK 供开发者使用，现在采纳我们 IM 方案的 APP 有：知乎Live、掌上链家、懂球帝等等，在 IM 方面也积累了一些经验，这次就在这篇博文分享下。

![采纳了我们IM方案和推送方案的APP](http://ww1.sinaimg.cn/large/006tNbRwjw1f9blvbrujhj30mb0i6tav.jpg)

## IM系列文章

IM 系列文章分为下面这几篇：

 -  [《IM 即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）》](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md) （本文）
 - [《技术实现细节》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/技术实现细节.md ) 
 - [《有一种 Block 叫 Callback，有一种 Callback 做 CompletionHandler》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/有一种%20Block%20叫%20Callback，有一种%20Callback%20做%20CompletionHandler.md ) 
 - [《防 DNS 污染方案》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/防%20DNS%20污染方案.md ) 

本文是第一篇。

## 提纲

  1. [应用场景](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#应用场景) 
    1. [IM 发展史](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#im-发展史) 
    2. [大家都在使用什么技术](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#大家都在使用什么技术) 
    3. [社交场景](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#社交场景) 
    4. [直播场景](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#直播场景) 
    5. [数据自动更新场景](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#数据自动更新场景) 
    6. [电梯场景（假在线状态处理）](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#电梯场景假在线状态处理) 
  2. [技术实现细节](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#技术实现细节)  
    1. [基于 WebSocket 的 IM 系统](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#基于-websocket-的-im-系统) 
    2. [更多](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#更多) 

  3. [性能调优 -- 针对移动网络特点的性能调优](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#性能调优----针对移动网络特点的性能调优) 
    1. [极简协议，传输协议 Protobuf](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#极简协议传输协议-protobuf) 
    2.  [在安全上需要做哪些事情？](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#在安全上需要做哪些事情) 
      1. [防止 DNS 污染](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#防止-dns-污染) 
      2. [账户安全](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#账户安全)     
    3. [重连机制](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#重连机制) 
    4.  [使用 HTTP/2 减少不必要的网络连接](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#使用-http2-减少不必要的网络连接) 
    5. [设置合理的超时时间](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#设置合理的超时时间) 
    6. [图片视频等文件上传](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#图片视频等文件上传) 
    7. [使用缓存：基于 Hash 的本地缓存校验](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#使用缓存基于-hash-的本地缓存校验) 

### 大规模即时通讯技术上的难点

思考几个问题：

 - 如何在移动网络环境下优化电量，流量，及长连接的健壮性？现在移动网络有2G、3G、4G各种制式，并且随时可能切换和中断，移动网络优化可以说是面向移动服务的共同问题。
 - 如何确保IM系统的整体安全？因为用户的消息是个人隐私，因此要从多个层面来保证IM系统的安全性。
 - 如何降低开发者集成门槛？
 - 如何应对新的iOS生态下的政策以及结合新技术：比如HTTP/2、IPv6、新的APNs协议等。

## 应用场景

一个 IM 服务最大的价值在于什么？

可复用的长连接。一切高实时性的场景，都适合使用IM来做。

比如：

 - 视频会议、聊天、私信
 - 弹幕、抽奖
 - 互动游戏
 - 协同编辑
 - 股票基金实时报价、体育实况更新、
 - 基于位置的应用：Uber、滴滴司机位置
 - 在线教育
 - 智能家居

下文会挑一些典型的场景进行介绍，并涉及到技术细节。

###  IM 发展史

基本的发展历程是：轮询、长轮询、长连接。

挑一些代表性的技术做下介绍：

**一般的网络请求：一问一答**

![](http://ww2.sinaimg.cn/large/801b780ajw1f7xlgk8724j214a0b640n.jpg)

**轮询：频繁的一问一答**

![](http://ww4.sinaimg.cn/large/801b780ajw1f7xlfsuqyfj21j30v27a3.jpg)

**长轮询：耐心地一问一答**

![](http://ww1.sinaimg.cn/large/801b780ajw1f7xlfskdsvj21j30v2wjn.jpg)


一种轮询方式是否为长轮询，是根据服务端的处理方式来决定的，与客户端没有关系。

短轮询很容易理解，那么什么叫长轮询？与短轮询有什么区别。

举个例子：

比如中秋节我们要做一个秒杀月饼的页面，要求我们要实时地展示剩余的月饼数量，也就是库存量。这时候如果要求你只能用短轮询或长轮询去做，怎么做呢？

![](http://ww4.sinaimg.cn/large/006tNbRwjw1f9e0nlkxvmj30fi0f93zs.jpg)

  长轮询和短轮询最大的区别是，短轮询去服务端查询的时候，不管服务端有没有变化，服务器就立即返回结果了。而长轮询则不是，在长轮询中，服务器如果检测到库存量没有变化的话，将会把当前请求挂起一段时间（这个时间也叫作超时时间，一般是几十秒）。在这个时间里，服务器会去检测库存量有没有变化，检测到变化就立即返回，否则就一直等到超时为止，这就是区别。
  
  （实际开发中不会使用长短轮询来做这种需求，这里仅仅是为了说明两者区别而做的一个例子。）
  
长轮询曾被 Facebook 早起版本采纳，示意图如下：

![](http://ww1.sinaimg.cn/large/801b780ajw1f7xkvkiaiaj20j608cdga.jpg)

**HTML5 WebSocket: 双向**

![](http://ww4.sinaimg.cn/large/801b780ajw1f7xlftf9rzj21j30v2tee.jpg)

参考： [What are Long-Polling, Websockets, Server-Sent Events (SSE) and Comet?](http://stackoverflow.com/a/12855533/3395008) 


我们可以看到，发展历史是这样：从长短轮询到长连接，使用 WebSocket 来替代 HTTP。

其中长短轮询与长短连接的区别主要有：

 1. 概念范畴不同：长短轮询是应用层概念、长短连接是传输层概念
 2. 协商方式不同：一个 TCP 连接是否为长连接，是通过设置 HTTP 的 Connection Header 来决定的，而且是需要两边都设置才有效。而一种轮询方式是否为长轮询，是根据服务端的处理方式来决定的，与客户端没有关系。
 3. 实现方式不同：连接的长短是通过协议来规定和实现的。而轮询的长短，是服务器通过编程的方式手动挂起请求来实现的。

**在移动端上长连接是趋势。**

其最大的特点是节省 Header。

**轮询与 WebSocket 所花费的Header流量对比**：

让我们来作一个测试：

假设 Header 是871字节，

我们以相同的频率 10W/s 去做网络请求， 对比下轮询与 WebSocket 所花费的 Header 流量：

Header 包括请求和响应头信息。

出于兼容性考虑，一般建立 WebSocket 连接也采用 HTTP 请求的方式，那么从这个角度讲：无论请求如何频繁，都只需要一个 Header。

并且 Websocket 的数据传输是 frame 形式传输的，帧传输更加高效，对比轮询的2个 Header，这里只有一个 Header 和一个 frame。

而 Websocket 的frame 仅仅用2个字节就代替了轮询的871字节！

 ![](http://ww1.sinaimg.cn/large/7853084cjw1f81fcbtqqqj20dz0a03z2.jpg)

相同的每秒客户端轮询的次数，当次数高达 10W/s 的高频率次数的时候，Polling 轮询需要消耗665Mbps，而 WebSocket 仅仅只花费了1.526Mbps，将近435倍！！

 数据参考：
 
   1. [HTML5 WebSocket: A Quantum Leap in Scalability for the Web](https://www.websocket.org/quantum.html) 
   2. [《微信,QQ这类IM app怎么做——谈谈Websocket》]( http://www.jianshu.com/p/bcefda55bce4 ) 
 
下面探讨下长连接实现方式里的协议选择：

### 大家都在使用什么技术

最近做了两个 IM 相关的问卷，累计产生了900多条的投票数据：

 1. [《你项目中使用什么协议实现了 IM 即时通讯》]( http://vote.weibo.com/poll/137494424) 
 2. [《IM 即时通讯中你会选用什么数据传输格式？》](http://vote.weibo.com/poll/137505291) 

注：本次投票是发布在[微博@iOS程序犭袁](http://weibo.com/luohanchenyilong) ，鉴于微博关注机制，本数据只能反映出 IM 技术在 iOS 领域的使用情况，并不能反映出整个IT行业的情况。

下文会对这个投票结果进行下分析。

![](http://ww4.sinaimg.cn/large/801b780ajw1f7xh238ofqj20fa0e6myo.jpg)

![](http://ww1.sinaimg.cn/large/7853084cjw1f81edc71a0j20gy0i0tay.jpg)

投票结果  [《你项目中使用什么协议实现了 IM 即时通讯》]( http://vote.weibo.com/poll/137494424) 

**协议如何选择？**

IM 协议选择原则一般是：易于拓展，方便覆盖各种业务逻辑，同时又比较节约流量。后一点的需求在移动端 IM 上尤其重要。常见的协议有：XMPP、SIP、MQTT、私有协议。

我们这里只关注前三名，

名称 | 优点 | 缺点
-------------|-------------|-------------
XMPP | 优点：协议开源，可拓展性强，在各个端(包括服务器)有各种语言的实现，开发者接入方便； | 缺点：缺点也是不少，XML表现力弱、有太多冗余信息、流量大，实际使用时有大量天坑。
MQTT | 优点：协议简单，流量少；订阅+推送模式，非常适合Uber、滴滴的小车轨迹的移动。 | 缺点：它并不是一个专门为 IM 设计的协议，多使用于推送。IM 情景要复杂得多，pub、sub，比如：加入对话、创建对话等等事件。
私有协议 | 市面上几乎所有主流IM APP都是是使用私有协议，一个被良好设计的私有协议优点非常明显。优点：高效，节约流量(一般使用二进制协议)，安全性高，难以破解；| 缺点：在开发初期没有现有样列可以参考，对于设计者的要求比较高。

一个好的协议需要满足如下条件:高效，简洁，可读性好，节约流量，易于拓展，同时又能够匹配当前团队的技术堆栈。基于如上原则，我们可以得出: 如果团队小，团队技术在 IM 上积累不够可以考虑使用 XMPP 或者 MQTT+HTTP 短连接的实现。反之可以考虑自己设计和实现私有协议，这里建议团队有计划地迁移到私有协议上。

这里特别提一下排名第二的 WebSocket ，区别于上面的聊天协议，这是一个传输通讯协议，那为什么会有这么多人在即时通讯领域运用了这一协议？除了上文说的长连接特性外，这个协议 web 原生支持，有很多第三方语言实现，可以搭配 XMPP、MQTT 等多种聊天协议进行使用，被广泛地应用于即时通讯领。

#### 社交场景

最大的特点在于：模式成熟，界面类似。

我们专门为社交场景开发的开源组件：ChatKit-OC，star数，1000+。

ChatKit-OC 在协议选择上使用的是 WebSocket 搭配私有聊天协议的方式，在数据传输上选择的是 Protobuf 搭配 JSON 的方式。

项目地址：[ChatKit-OC]( https://github.com/leancloud/ChatKit-OC ) 

![](http://ww4.sinaimg.cn/large/7853084cgw1f7yuulsdqgj20vf0kgdlk.jpg)

下文会专门介绍下技术实现细节。

#### 直播场景

一个演示如何为直播集成 IM 的开源直播 Demo：

 项目地址：[LiveKit-iOS](https://github.com/leancloud/LeanCloudLiveKit-iOS) 

（这个库，我最近也在优化，打算做成 Lib，支持下 CocoaPods 。希望能帮助大家快速集成直播模块。有兴趣的也欢迎参与进来提 PR）

LiveKit 相较社交场景的特点：

 - 无人数限制的聊天室
 - 自定义消息
 - 打赏机制的服务端配合
 
有人可能有这样的疑问：

![](http://ww1.sinaimg.cn/large/006tNbRwjw1f9e1zw0h1uj30ga05l3yn.jpg)

（叫我Elon（读：一龙）就好了）

那么可以看下 Demo 的实现：我们可以看到里面的弹幕、礼物、点赞出心这些都是 IM 系统里的自定义消息。

![](http://ww2.sinaimg.cn/large/72f96cbajw1f7q9sn89lzg20nl0l9b2a.gif)

![](http://ww2.sinaimg.cn/large/72f96cbajw1f7q9sdezf9g20nl0l9kjn.gif)

![](http://ww1.sinaimg.cn/large/72f96cbajw1f7q8zdrdpgg20nl0km7wk.gif)

#### 数据自动更新场景

 - 打车应用场景（Uber、滴滴等 APP 首页的移动小车）
 - 朋友圈状态的实施更新，朋友圈自己发送的消息无需刷新，自动更新
 
这些场景比聊天要简单许多，仅仅涉及到监听对象的订阅、取消订阅。
正如上文所提到的，使用 MQTT 实现最为经济。用社交类、直播类的思路来做，也可以实现，但略显冗余。

#### 电梯场景（假在线状态处理）

 iOS端的假在线的状态，有两种方案：
 
  - 双向ping pong机制
  - iOS端只走APNs

**双向 ping-pong 机制**：

Message 在发送后，在服务端维护一个表，一段时间内，比如15秒内没有收到 ack，就认为应用处于离线状态，先将用户踢下线，然后转而进行推送。这里如果出现，重复推送，客户端要负责去重。将 Message 消息相当于服务端发送的 Ping 消息，APP 的 ack 作为 pong。

![](http://ww4.sinaimg.cn/large/006y8lVajw1f873a0br78j30ac0bsgmb.jpg)

**使用 APNs 来作聊天**

优缺点：

  优点：
  
   - 解决了，iOS端假在线的问题。

  缺点：（APNs的缺点）

   - 无法保证消息的及时性。
   - 让服务端负载过重
   
   APNs不保证消息的到达率，消息会被折叠： 

你可能见过这种推送消息：

![enter image description here](http://i67.tinypic.com/5cfuao.jpg)

这中间发生了什么？

当 APNs 向你发送了4条推送，但是你的设备网络状况不好，在 APNs 那里下线了，这时 APNs 到你的手机的链路上有4条任务堆积，APNs 的处理方式是，只保留最后一条消息推送给你，然后告知你推送数。那么其他三条消息呢？会被APNs丢弃。

有一些 App 的 IM 功能没有维持长连接，是完全通过推送来实现的，通常情况下，这些 App 也已经考虑到了这种丢推送的情况，这些 App 的做法都是，每次收到推送之后，然后向自己的服务器查询当前用户的未读消息。但是 APNs 也同样无法保证这四条推送能至少有一条到达你的 App。

为什么这么设计？APNs的存储-转发能力太弱，大量的消息存储和转发将消耗 Apple 服务器的资源，可能是出于存储成本考虑，也可能是因为 Apple 转发能力太弱。总之结果就是 APNs 从来不保证消息的达到率。并且设备上线之后也不会向服务器上传信息。

现在我们可以保证消息一定能推送到 APNs 那里，但是 APNs 不保证帮我们把消息投递给用户。

即使搭配了这样的策略：每次收到推送就拉历史记录的消息，一旦消息被 APNs 丢弃，这条消息可能会在几天之后受到了新推送后才被查询到。

让服务端负载过重：

APNs 的实现原理决定了：必须每次收到消息后，拉取历史消息。这意味着你无法控制 APP 请求服务端的频率，同一时间十万、百万的请求量都是可能的，这带来的负载以及风险，有时甚至会比轮询还要大。

参考：[《基于HTTP2的全新APNs协议》](https://github.com/ChenYilong/iOS9AdaptationTips/blob/master/基于HTTP2的全新APNs协议/基于HTTP2的全新APNs协议.md) 

结论：如果面向的目标用户对消息的及时性并不敏感，可以采用这种方案。比如社交场景。（对消息较为敏感的APP则并不适合，比如：专门为情侣间使用的APP。。。）

### 技术实现细节

###基于 WebSocket 的 IM 系统

**WebSocket简介**

WebSocket 是 HTML5 开始提供的一种浏览器与服务器间进行全双工通讯的网络技术。 WebSocket 通信协定于2011年被 IETF 定为标准 RFC 6455，WebSocket API 被 W3C 定为标准。

在 WebSocket API 中，浏览器和服务器只需要要做一个握手的动作，然后，浏览器和服务器之间就形成了一条快速通道。两者之间就直接可以数据互相传送。

只从 RFC 发布的时间看来，WebSocket要晚很多，HTTP 1.1是1999年，WebSocket 则是12年之后了。WebSocket 协议的开篇就说，本协议的目的是为了解决基于浏览器的程序需要拉取资源时必须发起多个HTTP请求和长时间的轮训的问题而创建的。可以达到支持 iOS，Android，Web 三端同步的特性。

### 更多

**技术实现细节的部分较长，单独成篇。**： [《技术实现细节》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/技术实现细节.md ) 


下面是文章的第二部分：

### 性能调优 -- 针对移动网络特点的性能调优

#### 极简协议，传输协议 Protobuf

目录如下：

  1. 极简协议，传输协议 Protobuf
  2. 在安全上做了哪些事情？
    1. 防止 DNS 污染
    2. 账户安全
  3. 重连机制
  4. 使用 HTTP/2 减少不必要的网络连接
  5. 设置合理的超时时间
  6. 图片视频等文件上传
  7. 使用缓存：基于 Hash 的本地缓存校验


首先让我们来看下：

**IM 即时通讯中你会选用什么数据传输格式？**

之前做的调研数据如下：

![](http://ww1.sinaimg.cn/large/801b780ajw1f7xgu9y7yaj20fa0ejdh7.jpg)

![](http://ww4.sinaimg.cn/large/801b780ajw1f7xhowj9n2j20h30gzmz9.jpg)

[《IM 即时通讯中你会选用什么数据传输格式？》](http://vote.weibo.com/poll/137505291) 
 
注：本次投票是发布在[微博@iOS程序犭袁](http://weibo.com/luohanchenyilong) ，鉴于微博关注机制，本数据只能反映出 IM 技术在 iOS 领域的使用情况，并不能反映出整个IT行业的情况。

排名前三的分别的JSON 、ProtocolBuffer、XML；

这里重点推荐下 ProtocolBuffer：

 该协议已经在业内有很多应用，并且效果显著：

**使用 ProtocolBuffer 减少 Payload**

 - 滴滴打车40%；
 - 携程之前分享过，说是采用新的Protocol Buffer数据格式+Gzip压缩后的Payload大小降低了15%-45%。数据序列化耗时下降了80%-90%。

采用高效安全的私有协议，支持长连接的复用，稳定省电省流量
 
 1. 【高效】提高网络请求成功率，消息体越大，失败几率随之增加。
 2. 【省流量】流量消耗极少，省流量。一条消息数据用Protobuf序列化后的大小是 JSON 的1/10、XML格式的1/20、是二进制序列化的1/10。同 XML 相比， Protobuf 性能优势明显。它以高效的二进制方式存储，比 XML 小 3 到 10 倍，快 20 到 100 倍。
 3. 【省电】省电
 4. 【高效心跳包】同时心跳包协议对IM的电量和流量影响很大，对心跳包协议上进行了极简设计：仅 1 Byte 。
 5. 【易于使用】开发人员通过按照一定的语法定义结构化的消息格式，然后送给命令行工具，工具将自动生成相关的类，可以支持java、c++、python、Objective-C等语言环境。通过将这些类包含在项目中，可以很轻松的调用相关方法来完成业务消息的序列化与反序列化工作。语言支持：原生支持c++、java、python、Objective-C等多达10余种语言。 2015-08-27 Protocol Buffers v3.0.0-beta-1中发布了Objective-C(Alpha)版本， 2016-07-28 3.0 Protocol Buffers v3.0.0正式版发布，正式支持 Objective-C。
 6. 【可靠】微信和手机 QQ 这样的主流 IM 应用也早已在使用它（采用的是改造过的Protobuf协议）

![](http://ww1.sinaimg.cn/large/801b780ajw1f7xg2zq7iwj20rk0tpjz6.jpg)

如何测试验证 Protobuf 的高性能？

对数据分别操作100次，1000次，10000次和100000次进行了测试，

纵坐标是完成时间，单位是毫秒，

反序列化 | 序列化 | 字节长度
-------------|-------------|-------------
![](http://ww2.sinaimg.cn/large/65e4f1e6jw1f822vsywt6j20fb097t9b.jpg)|![](http://ww4.sinaimg.cn/large/65e4f1e6jw1f822vt0izwj20fb0970te.jpg) |![](http://ww4.sinaimg.cn/large/65e4f1e6jw1f822vt6ajij20fb0970tc.jpg)

 [数据来源](http://www.cnblogs.com/beyondbit/p/4778264.html)。

![](http://ww4.sinaimg.cn/large/801b780ajw1f7x13q6dnrj20fg0a70tj.jpg)

 数据来自：项目 [thrift-protobuf-compare]( https://github.com/eishay/jvm-serializers/wiki )，测试项为 Total Time，也就是 指一个对象操作的整个时间，包括创建对象，将对象序列化为内存中的字节序列，然后再反序列化的整个过程。从测试结果可以看到 Protobuf 的成绩很好.

缺点：

可能会造成 APP 的包体积增大，通过 Google 提供的脚本生成的 Model，会非常“庞大”，Model 一多，包体积也就会跟着变大。

如果 Model 过多，可能导致 APP 打包后的体积骤增，但 IM 服务所使用的 Model 非常少，比如在 ChatKit-OC 中只用到了一个 Protobuf 的 Model：Message对象，对包体积的影响微乎其微。

在使用过程中要合理地权衡包体积以及传输效率的问题，据说去哪儿网，就曾经为了减少包体积，进而减少了 Protobuf 的使用。

#### 在安全上需要做哪些事情？

##### 防止 DNS 污染

**文章较长，单独成篇。**： [《防 DNS 污染方案.md》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/防%20DNS%20污染方案.md ) 

##### 账户安全

IM 服务账号密码一旦泄露，危害更加严峻。尤其是对于消息可以漫游的类型。比如：
![](http://ww1.sinaimg.cn/large/7853084cjw1f7yo8csb6bj20ou0idq4d.jpg)

介绍下我们是如何做到，即使是我们的服务器被攻破，你的用户系统依然不会受到影响：

  1. 帐号安全：

  无侵入的权限控制：
  与用户的用户帐号体系完全隔离，只需要提供一个ID就可以通信，接入方可以对该 ID 进行 MD5 加密后再进行传输和存储，保证开发者用户数据的私密性及安全。

  2. 签名机制

  对关键操作，支持第三方服务器鉴权，保护你的信息安全。

  ![](http://ww4.sinaimg.cn/large/65e4f1e6jw1f81l13ayvsj20je0am3zk.jpg)

  参考： [《实时通信服务总览-权限和认证》](https://leancloud.cn/docs/realtime_v2.html#权限和认证 ) 
 
  3. 单点登录
    
  让 APP 支持单点登录，能有限减少盗号造成的安全问题。在 ChatKit-OC 中，我们就默认开启了单点登录功能，以此来提升 APP 的安全性。

#### 重连机制

 - 精简心跳包，保证一个心跳包大小在10字节之内；
 - 减少心跳次数：心跳包只在空闲时发送；从收到的最后一个指令包进行心跳包周期计时而不是固定时间。
 - 重连冷却
  2的指数级增长2、4、8，消息往来也算作心跳。类似于 iPhone 密码的 错误机制，冷却单位是5分钟，依次是5分钟后、10分钟后、15分钟后，10次输错，清除数据。

当然，这样灵活的策略也同样决定了，只能在 APP 层进行心跳ping。

![enter image description here](http://www.52im.net/data/attachment/forum/201609/06/152639a88oc4ohnuwp89ny.jpg)

这里有必要提一下重连机制的必要性，我们知道 TCP 也有保活机制，但这个与我们在这里讨论的“心跳保活”机制是有区别的。

TCP 保活（TCP KeepAlive 机制）和心跳保活区别：
 
 TCP保活 |  心跳保活
-------------|-------------
在定时时间到后，一般是 7200 s，发送相应的 KeepAlive 探针。，失败后重试 10 次，每次超时时间 75 s。（详情请参见《TCP/IP详解》中第23章） | 通常可以设置为3-5分钟发出 Ping
  检测**连接**的死活（对应于下图中的1） | 检测通讯**双方**的存活状态（对应于下图中的2）

保活，究竟保的是谁？

![](http://ww2.sinaimg.cn/large/7853084cjw1f7z3vq9ehhj20ao08l0sw.jpg)

比如：考虑一种情况，某台服务器因为某些原因导致负载超高，CPU 100%，无法响应任何业务请求，但是使用 TCP 探针则仍旧能够确定连接状态，这就是典型的连接活着但业务提供方已死的状态，对客户端而言，这时的最好选择就是断线后重新连接其他服务器，而不是一直认为当前服务器是可用状态，一直向当前服务器发送些必然会失败的请求。

#### 使用 HTTP/2 减少不必要的网络连接

大多数的移动网络(3G)并不允许一个给定 IP 地址超过两个的并发 HTTP 请求，既当你有两个针对同一个地址的连接时，再发起的第三个连接总是会超时。而2G网络下这个限定为1个。同一时间发起过多的网络请求不仅不会起到加速的效果，反而有副作用。

另一方面，由于网络连接很是费时，保持和共享某一条连接就是一个不错的选择：比如短时间内多次的HTTP请求。

使用 HTTP/2 就可以达到这样的目的。

 > HTTP/2 是 HTTP 协议发布后的首个更新，于2015年2月17日被批准。它采用了一系列优化技术来整体提升 HTTP 协议的传输性能，如异步连接复用、头压缩等等，可谓是当前互联网应用开发中，网络层次架构优化的首选方案之一。

 HTTP/2 也以高复用著称，而且如果我们要使用 HTTP/2，那么在网络库的选择上必然要使用 NSURLSession。所以 AFN2.x 也需要升级到AFN3.x.

#### 设置合理的超时时间

过短的超时容易导致连接超时的事情频频发生，甚至一直无法连接，而过长的超时则会带来等待时间过长，体验差的问题。就目前来看，对于普通的TCP连接30秒是个不错的超时值，而Http请求可以按照重要性和当前网络情况动态调整超时，尽量将超时控制在一个合理的数值内，以提高单位时间内网络的利用率。

#### 图片视频等文件上传

图片格式优化在业界已有成熟的方案，例如 Facebook 使用的 WebP 图片格式，已经被国内众多 App 使用。

分片上传、断点续传、秒传技术、

 - 文件分块上传:因为移动网络丢包严重，将文件分块上传可以使得一个分组包含合理数量的TCP包，使得重试概率下降，重试代价变小，更容易上传到服务器；
 - 提供文件秒传的方式:服务器根据MD5、SHA进行文件去重；
 - 支持断点续传。
 - 上传失败，合理的重连，比如3次。

#### 使用缓存：基于 Hash 的本地缓存校验

微信是不用考虑消息同步问题，因为微信是不存储历史记录的，卸载重装消息记录就会丢失。

所以我们可以采用一个类似 E-Tag、Last-Modified 的本地消息缓存校验机制，具体做法就是，当我们想加载最近10条的聊天记录时，先将本地缓存的最近10条做一个 hash 值，将 hash 值发送给服务端，服务端将服务端的最近十条做一个 hash ，如果一致就返回304。最理想的情况是服务端一直返回304，一直加载本地记录。这样做的好处：

 - 消息同步
 - 节省流量

## IM系列文章

IM 系列文章分为下面这几篇：

 -  [《IM 即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）》](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md) （本文）
 - [《技术实现细节》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/技术实现细节.md ) 
 - [《有一种 Block 叫 Callback，有一种 Callback 做 CompletionHandler》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/有一种%20Block%20叫%20Callback，有一种%20Callback%20做%20CompletionHandler.md ) 
 - [《防 DNS 污染方案》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/防%20DNS%20污染方案.md ) 

本文是第一篇。


----------

Posted by [微博@iOS程序犭袁](http://weibo.com/luohanchenyilong/)  
原创文章，版权声明：自由转载-非商用-非衍生-保持署名 | [Creative Commons BY-NC-ND 3.0](http://creativecommons.org/licenses/by-nc-nd/3.0/deed.zh)
<p align="center"><a href="http://weibo.com/u/1692391497?s=6uyXnP" target="_blank"><img border="0" src="http://service.t.sina.com.cn/widget/qmd/1692391497/b46c844b/1.png"/></a></a>
