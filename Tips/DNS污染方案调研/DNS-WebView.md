# iOS WebView 场景下的防 DNS 污染方案调研

## 使用 NSURLProtocol 拦截 NSURLSession 请求丢失 body

 方案如下： 

  1. 换用 NSURLConnection 
  2. 将 body 放进 Header 中
  3. 使用 HTTPBodyStream 获取 body，并赋值到 body 中


 ```Objective-C
#pragma mark -
#pragma mark 处理POST请求相关POST  用HTTPBodyStream来处理BODY体
- (NSMutableURLRequest *)handlePostRequestBodyWithRequest:(NSMutableURLRequest *)request {
    NSMutableURLRequest * req = [request mutableCopy];
    if ([request.HTTPMethod isEqualToString:@"POST"]) {
        if (!request.HTTPBody) {
            uint8_t d[1024] = {0};
            NSInputStream *stream = request.HTTPBodyStream;
            NSMutableData *data = [[NSMutableData alloc] init];
            [stream open];
            while ([stream hasBytesAvailable]) {
                NSInteger len = [stream read:d maxLength:1024];
                if (len > 0 && stream.streamError == nil) {
                    [data appendBytes:(void *)d length:len];
                }
            }
            req.HTTPBody = [data copy];
            [stream close];
        }
    }
    return req;
}

 ```

## WKWebView 无法使用 NSURLProtocol 拦截请求

 方案如下： 


  1. 换用 UIWebView 
  2. 使用私有API进行注册拦截


 ```Objective-C
//注册自己的protocol
    [NSURLProtocol registerClass:[CustomProtocol class]];

    //创建WKWebview
    WKWebViewConfiguration * config = [[WKWebViewConfiguration alloc] init];
    WKWebView * wkWebView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height) configuration:config];
    [wkWebView loadRequest:webViewReq];
    [self.view addSubview:wkWebView];

    //注册scheme
    Class cls = NSClassFromString(@"WKBrowsingContextController");
    SEL sel = NSSelectorFromString(@"registerSchemeForCustomProtocol:");
    if ([cls respondsToSelector:sel]) {
        // 通过http和https的请求，同理可通过其他的Scheme 但是要满足ULR Loading System
        [cls performSelector:sel withObject:@"http"];
        [cls performSelector:sel withObject:@"https"];
    }

 ```

## WKWebView 使用 NSURLProtocol 拦截请求无法获取 Cookie 信息

iOS11推出了新的 API `WKHTTPCookieStore` 可以用来拦截 WKWebView 的 Cookie 信息

用法示例如下：

 ```Objective-C
  WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
   //get cookies
    [cookieStroe getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull cookies) {
        NSLog(@"All cookies %@",cookies);
    }];

    //set cookie
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[NSHTTPCookieName] = @"userid";
    dict[NSHTTPCookieValue] = @"123";
    dict[NSHTTPCookieDomain] = @"koubei.com";
    dict[NSHTTPCookiePath] = @"/";

    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:dict];
    [cookieStroe setCookie:cookie completionHandler:^{
        NSLog(@"set cookie");
    }];

    //delete cookie
    [cookieStroe deleteCookie:cookie completionHandler:^{
        NSLog(@"delete cookie");
    }];
 ```


## 参考链接

Reference:  [支持SNI与WebView的 alicloud-ios-demo](https://github.com/Dave1991/alicloud-ios-demo) 
Reference: [HybirdWKWebVIew](https://github.com/LiuShuoyu/HybirdWKWebVIew/) 
 [《WWDC ​2017-WKWebView 新功能》]( https://zhuanlan.zhihu.com/p/27914128 ) 

## 走过的弯路

## 误以为 iOS11 新 API 可以原生拦截 WKWebView 的 HTTP/HTTPS 网络请求
 
 参考：[Deal With WKWebView DNS pollution problem in iOS11](https://github.com/ChenYilong/iOS11AdaptationTips/issues/16) 

## 误以为 iOS11 新 API 可以直接拦截 DNS 解析过程

参考：[NEDNSProxyProvider:DNS based on HTTP supported in iOS11](https://github.com/ChenYilong/iOS11AdaptationTips/issues/12) 