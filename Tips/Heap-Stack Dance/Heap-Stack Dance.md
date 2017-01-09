 【使用 Heap-Stack Dance 替代 Weak-Strong Dance，优雅避开循环引用】Weak-Strong Dance这一最佳实践的原理已经被讲烂了，开发者对该写法已经烂熟于心。有相当一部分开发者是不理解 Weak-Strong Dance 的原理，但却写得很溜，即使没必要加 `strongSelf` 的场景下也会添加上 `strongSelf`。没错，这样做，总是没错。
 
有没有想过从API层面简化一下？

介绍下我的做法：
 
为 block 多加一个参数，也就是 self 所属类型的参数，那么在 block 内部，该参数就会和 `strongSelf` 的效果一致。同时你也可以不写 `weakSelf`，直接使用使用该参数（作用等同于直接使用 `strongSelf` ）。这样就达到了：“多加一个参数，省掉两行代码”的效果。原理就是利用了“参数”的特性：参数是存放在栈中的(或寄存器中)，系统负责回收，开发者无需关心。因为解决问题的思路是：将 block 会捕获变量到堆上的问题，化解为了：变量会被分配到栈(或寄存器中)上，所以我把种做法起名叫 Heap-Stack Dance 。
 
具体用法示例如下：
(详见仓库中的[Demo---文件夹叫做：weak-strong-drance-demo](https://github.com/ChenYilong/iOSBlog/tree/master/Tips/Heap-Stack%20Dance) )


 ```Objective-C

#import "Foo.h"

typedef void (^Completion)(Foo *foo);

@interface Foo ()

@property (nonatomic, copy) Completion completion1;
@property (nonatomic, copy) Completion completion2;

@end

@implementation Foo

- (instancetype)init {
    if (!(self = [super init])) {
        return nil;
    }
    __weak typeof(self) weakSelf = self;
    self.completion1 = ^(Foo *foo) {
        NSLog(@"completion1");
    };
    self.completion2 = ^(Foo *foo) {
        __strong typeof(self) strongSelf = weakSelf;
        NSLog(@"completion2");
        NSUInteger delaySeconds = 2;
        dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delaySeconds * NSEC_PER_SEC));
        dispatch_after(when, dispatch_get_main_queue(), ^{
            NSLog(@"两秒钟后");
            foo.completion1(foo);//foo等价于strongSelf
        });
    };
    self.completion2(self);
    return self;
}

- (void)dealloc {
    NSLog(@"dealloc");
}

@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    __autoreleasing Foo *foo = [Foo new];
}

@end
 ```
 
 打印如下：
 
 ```Objective-C
 completion2
 两秒钟后
 completion1
 dealloc

 ```

 举一个实际开发中的例子：
 
 如果我们为UIViewController添加了一个属性，叫做viewDidLoadBlock，让用户来进行一些UI设置。
 
 具体的做法如下：
 
 
 ```Objective-C
@property (nonatomic, copy) CYLViewDidLoadBlock viewDidLoadBlock;

- (void)viewDidLoad {
    [super viewDidLoad];
    //...
    !self.viewDidLoadBlock ?: self.viewDidLoadBlock(self);
}
 ```

 那么可以想象block中必然是要使用到viewController本身，为了避免循环引用，之前我们不得不这样做：
 
 简化前：
 
 ```Objective-C
__weak typeof(controller) weakController = conversationController;
[conversationController setViewDidLoadBlock:^{
    [weakController.navigationItem setTitle:@"XXX"];
}];
 ```

如果借助这种做法，简化后：

 ```Objective-C
    [conversationViewController setViewDidLoadBlock:^(LCCKBaseViewController *viewController) {
        viewController.navigationItem.title = @"XXX";
    }];
 ```
 
 这种可能优势不太明显，毕竟编译器都能看出来，会报警告。但如果遇到了那种很难看出会造成循环引用的情景下，优势就显现出来了。
  尤其是在公开的 API 中，无法获知 `block` 是否被 `self` 持有的，如果在 `block` 中加增一个 `self` 类型的参数，因为 `block` 内部已经提供了 `weakSelf` 或者是 `strongSelf` 的替代者，那么调用者就可以在不使用 Weak-Strong Dance 的情况下避免循环引用。

 下面这个语句，编译器不会报警告，你能看出来有循环应用吗？
 
 比如我们为 `UIViewController` 添加了一个方法，这个方法主要作用就是配置下 `navigationBar` 右上角的 `item` 样式以及点击事件：
 
 ```Objective-C
    [aConversationController configureBarButtonItemStyle:LCCKBarButtonItemStyleGroupProfile
                                                  action:^(__kindof LCCKBaseViewController *viewController, UIBarButtonItem *sender, UIEvent *event) {                                                      [aConversationController.navigationController pushViewController:[UIViewController new] animated:YES];
                                                  }];
 ```

实际上你必须点击进去看一下该 API 的实现，你才能发现原来 `aConversationController` 持有了 `action` 这个 `block`，而在这种用法中 `block` 又持有了 `aConversationController` ，所以这种情况是有循环引用的。

可以看下上述方法的具体的实现：

 ```Objective-C
- (void)configureBarButtonItemStyle:(LCCKBarButtonItemStyle)style action:(LCCKBarButtonItemActionBlock)action {
    NSString *icon;
    switch (style) {
        case LCCKBarButtonItemStyleSetting: {
            icon = @"barbuttonicon_set";
            break;
        }
        case LCCKBarButtonItemStyleMore: {
            icon = @"barbuttonicon_more";
            break;
        }
        case LCCKBarButtonItemStyleAdd: {
            icon = @"barbuttonicon_add";
            break;
        }
        case LCCKBarButtonItemStyleAddFriends:
            icon = @"barbuttonicon_addfriends";
            break;
        case LCCKBarButtonItemStyleSingleProfile:
            icon = @"barbuttonicon_InfoSingle";
            break;
        case LCCKBarButtonItemStyleGroupProfile:
            icon = @"barbuttonicon_InfoMulti";
            break;
        case LCCKBarButtonItemStyleShare:
            icon = @"barbuttonicon_Operate";
            break;
    }
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage lcck_imageNamed:icon bundleName:@"BarButtonIcon" bundleForClass:[self class]] style:UIBarButtonItemStylePlain target:self action:@selector(clickedBarButtonItemAction:event:)];
    self.barButtonItemAction = action;
}

- (void)clickedBarButtonItemAction:(UIBarButtonItem *)sender event:(UIEvent *)event {
    if (self.barButtonItemAction) {
        self.barButtonItemAction(self, sender, event);
    }
}
 ```


> 必须让调用者理解了内部实现，才能用得好的API，不是一个好的API设计。

能不能在API层面就避免？增加一个self类型的参数就好了：

 ```Objective-C
            [aConversationController configureBarButtonItemStyle:LCCKBarButtonItemStyleGroupProfile
                                                          action:^(__kindof LCCKBaseViewController *viewController, UIBarButtonItem *sender, UIEvent *event) {
                                                              [viewController.navigationController pushViewController:[UIViewController new] animated:YES];
                                                          }];

 ```
 
 各位如果觉得好用，可以到你的项目中使用 `Heap-Stack Dance` 替代 `Weak-Strong Dance`，重构一些代码。
 
 

这里还有另外一种方法来证明 self 做参数传进 block 不会被 Block 捕获：
  
用 clang 对 Foo.m 文件转成c/c++代码：
    
   > clang -rewrite-objc Foo.m -Wno-deprecated-declarations -fobjc-arc
    
    
比如如下代码：
    
 ```Objective-C
    int tmpTarget;
    self.completion1 = ^(Foo *foo) {
        tmpTarget;
        NSLog(@"completion1");
    };
    self.completion1(self);
 ```

可以看到 Block 只会对传入的 `tmpTarget` 引用，`self` 不会捕获：

    
 ```C
struct __Foo__init_block_impl_0 {
  struct __block_impl impl;
  struct __Foo__init_block_desc_0* Desc;
  int tmpTarget;
  __Foo__init_block_impl_0(void *fp, struct __Foo__init_block_desc_0 *desc, int _tmpTarget, int flags=0) : tmpTarget(_tmpTarget) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
 ```
  
  
----------

QQ交流群：515295083

Posted by [微博@iOS程序犭袁](http://weibo.com/luohanchenyilong/)  
原创文章，版权声明：自由转载-非商用-非衍生-保持署名 | [Creative Commons BY-NC-ND 3.0](http://creativecommons.org/licenses/by-nc-nd/3.0/deed.zh)
<p align="center"><a href="http://weibo.com/u/1692391497?s=6uyXnP" target="_blank"><img border="0" src="http://service.t.sina.com.cn/widget/qmd/1692391497/b46c844b/1.png"/></a></a> 


