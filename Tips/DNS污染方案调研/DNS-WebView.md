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

 注意避免执行太晚，如果在 `- (void)viewDidLoad` 中注册，可能会因为注册太晚，引发问题。建议在`+load`方法中执行。

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
    dict[NSHTTPCookieDomain] = @"xxxx.com";
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

### 利用 WKHTTPCookieStore 解决 WKWebView 首次请求不携带 Cookie 的问题

只要是存在WKHTTPCookieStore里的 cookie，WKWebView每次请求都会携带，存在 NSHTTPCookieStorage 的cookie，并不会每次都携带。于是会发生首次WKWebView请求不携带Cookie的问题。

解决方法：

在执行 `-[WKWebView loadReques:]` 前将 `NSHTTPCookieStorage` 中的内容复制到 `WKHTTPCookieStore` 中。示例代码如下：

 ```Objective-C
        [self copyNSHTTPCookieStorageToWKHTTPCookieStoreWithCompletionHandler:^{
            NSURL *url = [NSURL URLWithString:@"https://www.v2ex.com"];
            NSURLRequest *request = [NSURLRequest requestWithURL:url];
            [_webView loadRequest:request];
        }];
 ```

 ```Objective-C
- (void)copyNSHTTPCookieStorageToWKHTTPCookieStoreWithCompletionHandler:(nullable void (^)())theCompletionHandler; {
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
    for (NSHTTPCookie *cookie in cookies) {
        if (cookies.count == 0) {
            !theCompletionHandler ?: theCompletionHandler();
            break;
        }
        [cookieStroe setCookie:cookie completionHandler:^{
            if ([[cookies lastObject] isEqual:cookie]) {
                !theCompletionHandler ?: theCompletionHandler();
                return;
            }
        }];
    }
}
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