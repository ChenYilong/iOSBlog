又可以叫《基于 Websocket 的即时通讯技术在多场景下的实践》

# IM 即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）

注：

  - 本文中所涉及到的所有 iOS 相关代码，均已100%开源（不存在 framework ），便于学习参考。
  - 本文侧重移动端的设计与实现，会展开讲，服务端仅仅属于概述，不展开。

希望为大家在设计或优化 IM 时，提供一些参考。

## 提纲

如何设计出一个高可复用性的 IM 模块。

即使你不使用我们做的 Lib，也同样对你在编写自己的 IM 服务中大有好处。

我是如何设计 API 的，一些特殊场景我是如何实现的。

如何确保IM系统的整体安全？因为用户的消息是个人隐私，因此要从多个层面来保证IM系统的安全性。


 [应用场景](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#应用场景) 
 [IM 发展史](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#im-发展史) 
 [大家都在使用什么技术](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#大家都在使用什么技术) 
  [社交场景 ：ChatKit](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md#社交场景-chatkit) 

### 大规模即时通讯技术上的难点

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

一般的网络请求：一问一答

![](http://ww2.sinaimg.cn/large/801b780ajw1f7xlgk8724j214a0b640n.jpg)

轮询：频繁的一问一答。

![](http://ww4.sinaimg.cn/large/801b780ajw1f7xlfsuqyfj21j30v27a3.jpg)

长轮询：耐心地一问一答

![](http://ww1.sinaimg.cn/large/801b780ajw1f7xlfskdsvj21j30v2wjn.jpg)

曾被 Facebook 早起版本采纳：

![](http://ww1.sinaimg.cn/large/801b780ajw1f7xkvkiaiaj20j608cdga.jpg)

一种轮询方式是否为长轮询，是根据服务端的处理方式来决定的，与客户端没有关系。

短轮询很容易理解，那么什么叫长轮询？与短轮询有什么区别。

举个例子，比如一个秒杀页面中有一个字段是库存量，而这个库存量需要实时的变化，保持和服务器里实际的库存一致。这个时候，你会怎么做？

最简单的一种方式，就是你用 JS 写个轮询，不停的去请求服务器中的库存量是多少，然后刷新到这个页面当中，这其实就是所谓的短轮询。

  长轮询和短轮询最大的区别是，短轮询去服务端查询的时候，不管库存量有没有变化，服务器就立即返回结果了。而长轮询则不是，在长轮询中，服务器如果检测到库存量没有变化的话，将会把当前请求挂起一段时间（这个时间也叫作超时时间，一般是几十秒）。在这个时间里，服务器会去检测库存量有没有变化，检测到变化就立即返回，否则就一直等到超时为止。

![](http://ww4.sinaimg.cn/large/7853084cjw1f7y4ix8maaj20k00f0gmm.jpg)

SSE：

（在APP开发中应用少，就不讲了。功能类似 Push。）

![](http://ww3.sinaimg.cn/large/801b780ajw1f7xlft5zckj21j30v2dky.jpg)

HTML5 Websockets: 双向

![](http://ww4.sinaimg.cn/large/801b780ajw1f7xlftf9rzj21j30v2tee.jpg)

参考： [What are Long-Polling, Websockets, Server-Sent Events (SSE) and Comet?](http://stackoverflow.com/a/12855533/3395008) 

从长短轮询到长短连接，使用 WebSocket 来替代 HTTP。

这几种技术的区别主要有：

 1. 概念范畴不同：长短轮询是应用层概念、长短连接是传输层概念
 2. 协商方式不同：一个 TCP 连接是否为长连接，是通过设置 HTTP 的 Connection Header 来决定的，而且是需要两边都设置才有效。而一种轮询方式是否为长轮询，是根据服务端的处理方式来决定的，与客户端没有关系。
 3. 实现方式不同：连接的长短是通过协议来规定和实现的。而轮询的长短，是服务器通过编程的方式手动挂起请求来实现的。

**在移动端上长连接是趋势。**

**轮询与Websocket的花费的流量对比**：

 ![](http://ww1.sinaimg.cn/large/7853084cjw1f81fcbtqqqj20dz0a03z2.jpg)

相同的每秒客户端轮询的次数，当次数高达10W/s的高频率次数的时候，Polling轮询需要消耗665Mbps，而Websocket仅仅只花费了1.526Mbps，将近435倍！！

 数据参考：
   1. [HTML5 WebSocket: A Quantum Leap in Scalability for the Web](https://www.websocket.org/quantum.html) 
   2. [《微信,QQ这类IM app怎么做——谈谈Websocket》]( http://www.jianshu.com/p/bcefda55bce4 ) 
 
下面探讨下长连接实现方式里的协议选择：

### 大家都在使用什么技术

最近做了两个 IM 相关的问卷，累计产生了800多条的投票数据：

 1. [《你项目中使用什么协议实现了 IM 即时通讯》]( http://vote.weibo.com/poll/137494424) 
 2. [《IM 即时通讯中你会选用什么数据传输格式？》](http://vote.weibo.com/poll/137505291) 

注：以上两次投票是发布在微博@iOS程序犭袁 ，鉴于微博的粉丝关注机制，本数据只能反映出 IM 技术在移动领域或者说是 iOS 领域的使用情况，可能并不能反映出整个IT行业的情况。

下文会对这个投票结果进行下分析。

![](http://ww4.sinaimg.cn/large/801b780ajw1f7xh238ofqj20fa0e6myo.jpg)

![](http://ww1.sinaimg.cn/large/7853084cjw1f81edc71a0j20gy0i0tay.jpg)

投票结果  [《你项目中使用什么协议实现了 IM 即时通讯》]( http://vote.weibo.com/poll/137494424) 

协议如何选择？

IM协议选择原则一般是：易于拓展，方便覆盖各种业务逻辑，同时又比较节约流量。后一点的需求在移动端 IM 上尤其重要。常见的协议有：XMPP、SIP、MQTT、私有协议。

名称 | 优点 | 缺点
-------------|-------------|-------------
XMPP | 优点：协议开源，可拓展性强，在各个端(包括服务器)有各种语言的实现，开发者接入方便； | 缺点：缺点也是不少，XML表现力弱、有太多冗余信息、流量大，实际使用时有大量天坑。
SIP | SIP协议多用于VOIP相关的模块，是一种文本协议 | 文本协议这一点几乎可以断定它的流量不会小。
MQTT | 优点：协议简单，流量少；订阅+推送模式，非常适合Uber、滴滴的小车轨迹的移动。 | 缺点：它并不是一个专门为 IM 设计的协议，多使用于推送。IM 情景要复杂得多，pub、sub，比如：加入对话、创建对话等等事件。
私有协议 | 市面上几乎所有主流IM APP都是是使用私有协议，一个被良好设计的私有协议优点非常明显。优点：高效，节约流量(一般使用二进制协议)，安全性高，难以破解；| 缺点：在开发初期没有现有样列可以参考，对于设计者的要求比较高。
WebSocket | web原生支持，很多第三方语言实现，可以搭配XMPP、MQTT等多种聊天协议  | -

一个好的协议需要满足如下条件:高效，简洁，可读性好，节约流量，易于拓展，同时又能够匹配当前团队的技术堆栈。基于如上原则，我们可以得出: 如果团队小，团队技术在 IM 上积累不够可以考虑使用 XMPP 或者 MQTT+HTTP短连接的实现。反之可以考虑自己设计和实现私有协议。

#### 社交场景

我们专门为社交场景开发的开源组件：ChatKit，star数，1000+。

项目地址：[ChatKit-OC]( https://github.com/leancloud/ChatKit-OC ) 

![](http://ww4.sinaimg.cn/large/7853084cgw1f7yuulsdqgj20vf0kgdlk.jpg)

下文会专门介绍下技术实现细节。

#### 直播场景

一个演示如何为直播集成IM的开源直播Demo：

 项目地址：[LiveKit-iOS](https://github.com/leancloud/LeanCloudLiveKit-iOS) 

LiveKit 相较社交场景的特点：

 - 无人数限制的聊天室
 - 自定义消息
 - 打赏机制的服务端配合
 
![](http://ww2.sinaimg.cn/large/72f96cbajw1f7q9sn89lzg20nl0l9b2a.gif)

![](http://ww2.sinaimg.cn/large/72f96cbajw1f7q9sdezf9g20nl0l9kjn.gif)

![](http://ww1.sinaimg.cn/large/72f96cbajw1f7q8zdrdpgg20nl0km7wk.gif)

#### 数据自动更新场景

 - 打车应用场景（Uber、滴滴等APP移动小车）
 - 朋友圈状态的实施更新，朋友圈自己发送的消息无需刷新，自动更新
 
这些场景比聊天要简单许多，仅仅涉及到监听对象的订阅、取消订阅。
正如上文所提到的，使用 MQTT 实现最为经济。用社交类、直播类的思路来做，也可以实现，但略显冗余。

#### 电梯场景（假在线状态处理）

使用 APNs 来作聊天

 iOS端的假在线的状态，有两种方案：
 
  - iOS端只走APNs
  - 双向ping pong机制
 
使用 APNs 来作聊天的优缺点：

  优点：
  
   - 解决了，iOS端假在线的问题。
   - 消息的字节数限制影响更小
  

 APNs新闻一栏

时间 | 新闻 | 参考文档
-------------|-------------|-------------
2014年6月 | 2014年6月份WWDC搭载iOS8及以上系统的iOS设备，能够接收的最大playload大小提升到2KB。低于iOS8的设备以及OS X设备维持256字节。 | [**What's New in Notifications - WWDC 2014 - Session 713 - iOS**]( https://developer.apple.com/videos/play/wwdc2014/713/)  ![enter image description here](http://i.stack.imgur.com/UW3ex.png)
2015年6月 | 2015年6月份WWDC宣布将在不久的将来发布 “基于 HTTP/2 的全新 APNs 协议”，并在大会上发布了仅仅支持测试证书的版本。| [**What's New in Notifications - WWDC 2015 - Session 720 - iOS, OS X**]( https://developer.apple.com/videos/play/wwdc2015/720/ )  ![enter image description here](http://i63.tinypic.com/2cy2ka0.jpg)
2015年12月17日 | 2015年12月17日起，发布 “基于 HTTP/2 的全新 APNs 协议”,iOS 系统以及 OS X 系统，统一将最大 playload 大小提升到4KB。  | [**Apple Push Notification Service Update 12-17 2015**]( https://developer.apple.com/news/?id=12172015b )
 
  缺点：（APNs的缺点）

   - 无法保证消息的及时性。无法保证准确性。
   APNs不保证消息的到达率，消息会被折叠： 

你可能见过这种推送消息：

![enter image description here](http://i67.tinypic.com/5cfuao.jpg)

这中间发生了什么？

当 APNs 向你发送了4条推送，但是你的设备网络状况不好，在 APNs 那里下线了，这时 APNs 到你的手机的链路上有4条任务堆积，APNs 的处理方式是，只保留最后一条消息推送给你，然后告知你推送数。那么其他三条消息呢？会被APNs丢弃。

有一些 App 的 IM 功能没有维持长连接，是完全通过推送来实现到，通常情况下，这些 App 也已经考虑到了这种丢推送的情况，这些 App 的做法都是，每次收到推送之后，然后向自己的服务器查询当前用户的未读消息。但是APNs也同样无法保证这四条推送能至少有一条到达你的 App。很遗憾的告诉这些App，这次的更新对你们所遭受对这些坑，没有改善。

为什么这么设计？APNs的存储-转发能力太弱，大量的消息存储和转发将消耗 Apple 服务器的资源，可能是出于存储成本考虑，也可能是因为 Apple 转发能力太弱。总之结果就是 APNs 从来不保证消息的达到率。并且设备上线之后也不会向服务器上传信息。

现在SDK的提供商依然无法保证，消息推到了 APNs，APNs能推到 App 那里。

即使搭配了这样的策略：每次收到推送就拉历史记录的消息，一旦消息被 APNs 丢弃，这条消息可能会在几天之后受到了新推送后才被查询到。

   - 对服务端的负载要求高
    APNs的实现原理导致了：必须每次收到消息后，拉取历史消息。

参考：[《基于HTTP2的全新APNs协议》](https://github.com/ChenYilong/iOS9AdaptationTips/blob/master/基于HTTP2的全新APNs协议/基于HTTP2的全新APNs协议.md) 

结论：如果面向的目标用户对消息的及时性并不敏感，可以采用这种方案。比如社交场景。（情侣间APP，毫秒级别的应用，就算了）

还有另一种方法：

Message在发送后在服务端，维护一个表，15秒内没有收到ack，就认为应用处于离线状态，然后转而进行推送。这里如果出现，重复推送，客户端要负责保证只。将 Message 消息相当于服务端发送的Ping消息，APP的 ack 作为 pong。

### 基于 WebSocket 的 IM 系统

#### WebSocket简介

WebSocket 是HTML5开始提供的一种浏览器与服务器间进行全双工通讯的网络技术。 WebSocket 通信协定于2011年被IETF定为标准 RFC 6455，WebSocketAPI被W3C定为标准。

在 WebSocket API中，浏览器和服务器只需要要做一个握手的动作，然后，浏览器和服务器之间就形成了一条快速通道。两者之间就直接可以数据互相传送。

🔵只从RFC发布的时间看来，WebSocket要晚近很多，HTTP 1.1是1999年，WebSocket则是12年之后了。WebSocket协议的开篇就说，本协议的目的是为了解决基于浏览器的程序需要拉取资源时必须发起多个HTTP请求和长时间的轮训的问题而创建的。

🔵可以达到支持 iOS，Android，Web 三端同步的特性。

### 技术实现细节

**文章较长，单独成篇。**： [《技术实现细节》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/技术实现细节.md ) 

### 性能调优 -- 针对移动网络特点的性能调优

#### 极简协议，传输协议 Protobuf

![](http://ww1.sinaimg.cn/large/801b780ajw1f7xgu9y7yaj20fa0ejdh7.jpg)

![](http://ww4.sinaimg.cn/large/801b780ajw1f7xhowj9n2j20h30gzmz9.jpg)

[《IM 即时通讯中你会选用什么数据传输格式？》](http://vote.weibo.com/poll/137505291) 
 
注：本次投票是发布在微博@iOS程序犭袁 ，鉴于微博关注机制，本数据只能反映出IM技术在 iOS 领域的使用情况，并不能反映出整个IT行业的情况。

使用 ProtocolBuffer 减少 Payload

🔵微信也同样使用的 Protobuf 协议，定制后的。

 - 测试是省了70%；
 - 滴滴打车40%；
 - 携程是采用新的Protocol Buffer数据格式+Gzip压缩后的Payload大小降低了15%-45%。数据序列化耗时下降了80%-90%。

采用高效安全的私有协议，支持长连接的复用，稳定省电省流量

 1. 【安全】高效安全，采用完全私有的二进制协议：确保数据加密安全
 2. 【省流量】流量消耗极少，省流量。🔵一条消息数据用Protobuf序列化后的大小是 JSON 的1/10、XML格式的1/20、是二进制序列化的1/10。同 XML 相比， Protobuf 性能优势明显。它以高效的二进制方式存储，比 XML 小 3 到 10 倍，快 20 到 100 倍。
 3. 【省电】省电
 4. 【高效心跳包】同时心跳包协议对IM的电量和流量影响很大，对心跳包协议上进行了极简设计：仅 1 Byte 。
 5. 【易于使用】开发人员通过按照一定的语法定义结构化的消息格式，然后送给命令行工具，工具将自动生成相关的类，可以支持java、c++、python、Objective-C等语言环境。通过将这些类包含在项目中，可以很轻松的调用相关方法来完成业务消息的序列化与反序列化工作。语言支持：原生支持c++、java、python、Objective-C等多达10余种语言。 2015-08-27 Protocol Buffers v3.0.0-beta-1中发布了Objective-C(Alpha)版本， 两个月前，2016-07-28 3.0 Protocol Buffers v3.0.0正式版发布，正式支持 Objective-C。
 6. 微信和手机QQ这样的主流IM应用也早已在使用它
 7. 提高网络请求成功率，消息体越大，失败几率越大。

![](http://ww1.sinaimg.cn/large/801b780ajw1f7xg2zq7iwj20rk0tpjz6.jpg)

高性能，序列化、反序列化、创建综合性能高。

发序列化 | 序列化 | 字节长度
-------------|-------------|-------------
![](http://ww2.sinaimg.cn/large/65e4f1e6jw1f822vsywt6j20fb097t9b.jpg)|![](http://ww4.sinaimg.cn/large/65e4f1e6jw1f822vt0izwj20fb0970te.jpg) |![](http://ww4.sinaimg.cn/large/65e4f1e6jw1f822vt6ajij20fb0970tc.jpg)

数据来源：http://www.cnblogs.com/beyondbit/p/4778264.html

![](http://ww4.sinaimg.cn/large/801b780ajw1f7x13q6dnrj20fg0a70tj.jpg)

 数据来自：项目 [thrift-protobuf-compare]( https://github.com/eishay/jvm-serializers/wiki )，测试项为 Total Time，也就是 指一个对象操作的整个时间，包括创建对象，将对象序列化为内存中的字节序列，然后再反序列化的整个过程。从测试结果可以看到 Protobuf 的成绩很好.

缺点：不能表示复杂的数据结构，但 IM 服务已经足够使用。

#### 防止 DNS 污染

**文章较长，单独成篇。**： [《防 DNS 污染方案.md》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/防%20DNS%20污染方案.md ) 

#### 防止 DDos 攻击

主要是服务端，比如可以使用一些专业的DDos防御厂商，客户端中能做的有限，主要是放置备用域名。

## 在安全上做了哪些事情？

IM 服务账号密码一旦泄露，危害更加严峻。尤其是对于消息可以漫游的类型。

![](http://ww1.sinaimg.cn/large/7853084cjw1f7yo8csb6bj20ou0idq4d.jpg)

  1. 帐号安全：

  无侵入的权限控制：
  与用户的用户帐号体系完全隔离，只需要提供一个ID就可以通信，接入方可以对该 ID 进行 MD5 加密后再进行传输和存储，保证开发者用户数据的私密性及安全。
 
  2. 数据传输安全：

  包括：使用二进制通讯协议；

  3. 签名机制

  对关键操作，支持第三方服务器鉴权，保护你的信息安全。

  ![](http://ww4.sinaimg.cn/large/65e4f1e6jw1f81l13ayvsj20je0am3zk.jpg)

  参考： [《实时通信服务总览-权限和认证》]( https://leancloud.cn/docs/realtime_v2.html#权限和认证 ) 
 
  4. 单点登录
  
#### 重连机制

 - 精简心跳包，保证一个心跳包大小在10字节之内；
 - 减少心跳次数：心跳包只在空闲时发送；从收到的最后一个指令包进行心跳包周期计时而不是固定时间。
 - 重连冷却
  2的指数级增长2、4、8，消息往来也算作心跳。类似于 iPhone 密码的 错误机制，冷却单位是5分钟，10次输错，清除数据。

这样灵活的策略也同样决定了，只能在 APP 层进行心跳ping。

![enter image description here](http://www.52im.net/data/attachment/forum/201609/06/152639a88oc4ohnuwp89ny.jpg)

TCP 保活（TCP KeepAlive 机制）和心跳保活区别：
 
 TCP保活 |  心跳保活
-------------|-------------
在定时时间到后，一般是 7200 s，发送相应的 KeepAlive 探针。，失败后重试 10 次，每次超时时间 75 s。（详情请参见《TCP/IP详解》中第23章） | 通常可以设置为3-5分钟发出 Ping
  检测**连接**的死活（对应于下图中的1） | 检测通讯**双方**的存活状态（对应于下图中的2）

保活，究竟保的是谁？

![](http://ww2.sinaimg.cn/large/7853084cjw1f7z3vq9ehhj20ao08l0sw.jpg)

比如：考虑一种情况，某台服务器因为某些原因导致负载超高，CPU 100%，无法响应任何业务请求，但是使用 TCP 探针则仍旧能够确定连接状态，这就是典型的连接活着但业务提供方已死的状态，对客户端而言，这时的最好选择就是断线后重新连接其他服务器，而不是一直认为当前服务器是可用状态，一直向当前服务器发送些必然会失败的请求。

#### 使用 HTTP/2 减少不必要的网络连接

大多数的移动网络(3G)并不允许一个给定IP地址超过两个的并发 HTTP 请求，既当你有两个针对同一个地址的连接时，再发起的第三个连接总是会超时。而2G网络下这个限定为1个。同一时间发起过多的网络请求不仅不会起到加速的效果，反而有副作用。

另一方面，由于网络连接很是费时，保持和共享某一条连接就是一个不错的选择：比如短时间内多次的HTTP请求。

使用 HTTP/2 就可以达到这样的目的。

 > HTTP/2 是 HTTP 协议发布后的首个更新，🔵于2015年2月17日被批准。它采用了一系列优化技术来整体提升 HTTP 协议的传输性能，如异步连接复用、头压缩等等，可谓是当前互联网应用开发中，网络层次架构优化的首选方案之一。

 HTTP/2 也以高复用著称，而且如果我们要使用 HTTP/2，那么在网络库的选择上必然要使用 NSURLSession。所以 AFN2.x 也需要升级到AFN3.x.

#### 设置合理的超时时间

过短的超时容易导致连接超时的事情频频发生，甚至一直无法连接，而过长的超时则会带来等待时间过长，体验差的问题。就目前来看，对于普通的TCP连接30秒是个不错的超时值，而Http请求可以按照重要性和当前网络情况动态调整超时，尽量将超时控制在一个合理的数值内，以提高单位时间内网络的利用率。

#### 图片视频等文件上传

图片格式优化在业界已有成熟的方案，例如Facebook使用的WebP图片格式，已经被国内众多App使用。

分片上传、断点续传、秒传技术、

 - 文件分块上传:因为移动网络丢包严重，将文件分块上传可以使得一个分组包含合理数量的TCP包，使得重试概率下降，重试代价变小，更容易上传到服务器；
 - 提供文件秒传的方式:服务器根据MD5进行文件去重；
 - 支持断点续传。
 - 上传失败，合理的重连，比如3次。

图片性能优化

#### 使用缓存：类似 Hash 的本地缓存校验

🔵 微信是不用考虑消息同步问题，因为微信是不存储历史记录的，卸载重装消息记录就会丢失。

#### 服务健康检查-监控

在服务器部署一个监控程序，每个一段互发消息，如果消息终端，就触发报警。


### 视频通话 WebRTC（待删除）