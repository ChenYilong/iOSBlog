# 有一种 Block 叫 Callback，有一种 Callback 叫 CompletionHandler

## IM系列文章

IM系列文章分为下面这几篇：

 -  [《IM 即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）》](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md) 
 - [《技术实现细节》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/技术实现细节.md ) 
 - [《有一种 Block 叫 Callback，有一种 Callback 叫 CompletionHandler》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/有一种%20Block%20叫%20Callback，有一种%20Callback%20做%20CompletionHandler.md ) （本文）
 - [《防 DNS 污染方案》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/防%20DNS%20污染方案.md ) 


本文是第三篇。

## 正文

本文会以下面这种情况为切入点来探讨 Block 的种类和用法：

 > 集成 ChatKit 时，如何导入 APP 已有的用户系统，

我们作为开发者去集成一个 Lib （也可以叫轮子、SDK、下文统一叫 Lib）时，我们会发现我们遇到的 `Block`， 按照功能的角度划分，其实可以分为这几种：

 - Lib 通知开发者，**Lib**操作已经完成。一般命名为 Callback
 - 开发者通知 Lib，**开发者**的操作已经完成。一般可以命名为 CompletionHandler。

这两处的区别： 前者是 “Block 的执行”，后者是 “Block 的填充”。

 `Callback vs CompletionHandler` 命名与功能的差别，Apple 也没有明确的编码规范指出过，只不过如果按照“执行与填充”的功能划分的话，`callback` 与 `completionHandler` 的命名可以区分开来对待。同时也方便调用者理解 block 的功能。但总体来说，Apple 官方的命名中，“Block 填充“这个功能一般都会命名为 “completionHandler”，“Block 执行”这个功能大多命名为了“callback” ，也有少部分命名为了 “completionHandler”。

比如：

NSURLSession 中，下面的函数将 “callback” 命名为了 “completionHandler”：


 ```Objective-C
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

 ```


我们常常见到 `CompletionHandler` 被用到了第一种场景，而第一种场景“Block 执行”命名为 Callback 则更合适。

 > 不是所有 Block 都适合叫做 CompletionHandler

一般情况下，CompletionHandler 的设计往往考虑到多线程操作，于是，你就完全可以异步操作，然后在线程结束时执行该 CompletionHandler，下文的例子中会讲述下 `CompletionHandler` 方式在多线程场景下的一些优势。

## CompletionHandler + Delegate 组合

在 iOS10 中新增加的 `UserNotificaitons` 中大量使用了这种 Block，比如：

 ```Objective-C
- (void)userNotificationCenter:(UNUserNotificationCenter *)center 
didReceiveNotificationResponse:(UNNotificationResponse *)response 
         withCompletionHandler:(void (^)(void))completionHandler;
 ```

 [文档](https://developer.apple.com/reference/usernotifications/unusernotificationcenterdelegate/1649501-usernotificationcenter?language=objc) 对 completionHandler 的注释是这样的：

 ```Objective-C
The block to execute when you have finished processing the user’s response. You must execute this block from your method and should call it as quickly as possible. The block has no return value or parameters.
 ```

同样在这里也有应用：

 ```Objective-C
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * __nullable credential))completionHandler;
 ```



还有另外一个也非常普遍的例子（Delegate 方式使用URLSession 时候必不可少的 4个代理函数之一 ）


 ```Objective-C
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                 didReceiveResponse:(NSURLResponse *)response
                                  completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler;
 ```


在代理方法实现代码里面，若是不执行 completionHandler(NSURLSessionResponseAllow) 话，http请求就终止了。

## CompletionHandler + Block 组合

函数中将函数作为参数或者返回值，就叫做高阶函数。

按照这种定义，Block 中将 Block 作为参数，这也就是高阶函数。

结合实际的应用场景来看一个例子：

如果有这样一个需求：

以我之前的一个 IM 项目 ChatKit-OC （开源的，下面简称 ChatKit）为例，当你的应用想要集成一个 IM 服务时，可能这时候，你的 APP 已经上架了，已经有自己的注册、登录等流程了。用 ChatKit 进行聊天很简单，只需要给 ChatKit 一个 id 就够了。聊天是正常了，但是双方只能看到一个id，这样体验很不好。但是如何展示头像、昵称呢？于是就设计了这样一个接口，`-setFetchProfilesBlock:` 。

这是上层（APP）提供用户信息的 Block，由于 ChatKit 并不关心业务逻辑信息，比如用户昵称，用户头像等。用户可以通过 ChatKit 单例向 ChatKit 注入一个用户信息内容提供 Block，通过这个用户信息提供 Block，ChatKit 才能够正确的进行业务逻辑数据的绘制。

示意图如下：

![](http://ww2.sinaimg.cn/large/801b780ajw1f8ah885yn0j20e70bw754.jpg)

具体实现如下：

方法定义如下：

 ```Objective-C
/*!
 *  @brief The block to execute with the users' information for the userIds. Always execute this block at some point when fetching profiles completes on main thread. Specify users' information how you want ChatKit to show.
 *  @attention If you fetch users fails, you should reture nil, meanwhile, give the error reason.
 */
typedef void(^LCCKFetchProfilesCompletionHandler)(NSArray<id<LCCKUserDelegate>> *users, NSError *error);

/*!
 *  @brief When LeanCloudChatKit wants to fetch profiles, this block will be invoked.
 *  @param userIds User ids
 *  @param completionHandler The block to execute with the users' information for the userIds. Always execute this block at some point during your implementation of this method on main thread. Specify users' information how you want ChatKit to show.
 */
typedef void(^LCCKFetchProfilesBlock)(NSArray<NSString *> *userIds, LCCKFetchProfilesCompletionHandler completionHandler);

@property (nonatomic, copy) LCCKFetchProfilesBlock fetchProfilesBlock;

/*!
 *  @brief Add the ablitity to fetch profiles.
 *  @attention  You must get peer information by peer id with a synchronous implementation.
 *              If implemeted, this block will be invoked automatically by LeanCloudChatKit for fetching peer profile.
 */
- (void)setFetchProfilesBlock:(LCCKFetchProfilesBlock)fetchProfilesBlock;
 ```


用法如下所示：


 ```Objective-C
#warning 注意：setFetchProfilesBlock 方法必须实现，如果不实现，ChatKit将无法显示用户头像、用户昵称。以下方法循环模拟了通过 userIds 同步查询 users 信息的过程，这里需要替换为 App 的 API 同步查询
    [[LCChatKit sharedInstance] setFetchProfilesBlock:^(NSArray<NSString *> *userIds,
                             LCCKFetchProfilesCompletionHandler completionHandler) {
         if (userIds.count == 0) {
             NSInteger code = 0;
             NSString *errorReasonText = @"User ids is nil";
             NSDictionary *errorInfo = @{
                                         @"code":@(code),
                                         NSLocalizedDescriptionKey : errorReasonText,
                                         };
             NSError *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                                  code:code
                                              userInfo:errorInfo];
             
             !completionHandler ?: completionHandler(nil, error);
             return;
         }
         
         NSMutableArray *users = [NSMutableArray arrayWithCapacity:userIds.count];
#warning 注意：以下方法循环模拟了通过 userIds 同步查询 users 信息的过程，这里需要替换为 App 的 API 同步查询
         
         [userIds enumerateObjectsUsingBlock:^(NSString *_Nonnull clientId, NSUInteger idx,
                                               BOOL *_Nonnull stop) {
             NSPredicate *predicate = [NSPredicate predicateWithFormat:@"peerId like %@", clientId];
             //这里的LCCKContactProfiles，LCCKProfileKeyPeerId都为事先的宏定义，
             NSArray *searchedUsers = [LCCKContactProfiles filteredArrayUsingPredicate:predicate];
             if (searchedUsers.count > 0) {
                 NSDictionary *user = searchedUsers[0];
                 NSURL *avatarURL = [NSURL URLWithString:user[LCCKProfileKeyAvatarURL]];
                 LCCKUser *user_ = [LCCKUser userWithUserId:user[LCCKProfileKeyPeerId]
                                                       name:user[LCCKProfileKeyName]
                                                  avatarURL:avatarURL
                                                   clientId:clientId];
                 [users addObject:user_];
             } else {
                 //注意：如果网络请求失败，请至少提供 ClientId！
                 LCCKUser *user_ = [LCCKUser userWithClientId:clientId];
                 [users addObject:user_];
             }
         }];
         // 模拟网络延时，3秒
         //         sleep(3);
         
#warning 重要：completionHandler 这个 Bock 必须执行，需要在你**获取到用户信息结束**后，将信息传给该Block！
         !completionHandler ?: completionHandler([users copy], nil);
     }];
 ```


对于以上 Fetch 方法的这种应用场景，其实用方法的返回值也可以实现，但是与 CompletionHandler 相比，无法自由切换线程是个弊端。


## IM系列文章

IM系列文章分为下面这几篇：

 -  [《IM 即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）》](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md) 
 - [《技术实现细节》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/技术实现细节.md ) 
 - [《有一种 Block 叫 Callback，有一种 Callback 叫 CompletionHandler》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/有一种%20Block%20叫%20Callback，有一种%20Callback%20做%20CompletionHandler.md ) （本文）
 - [《防 DNS 污染方案》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/防%20DNS%20污染方案.md ) 


本文是第三篇。

----------

Posted by [微博@iOS程序犭袁](http://weibo.com/luohanchenyilong/)  
原创文章，版权声明：自由转载-非商用-非衍生-保持署名 | [Creative Commons BY-NC-ND 3.0](http://creativecommons.org/licenses/by-nc-nd/3.0/deed.zh)
<p align="center"><a href="http://weibo.com/u/1692391497?s=6uyXnP" target="_blank"><img border="0" src="http://service.t.sina.com.cn/widget/qmd/1692391497/b46c844b/1.png"/></a></a>

