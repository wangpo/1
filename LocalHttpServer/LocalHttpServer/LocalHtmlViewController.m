//
//  LocalHtmlViewController.m
//  WPDevelopProject
//
//  Created by wangpo on 2018/4/9.
//  Copyright © 2018年 BaoFeng. All rights reserved.
//

#import "LocalHtmlViewController.h"
#import <WebKit/WebKit.h>

//搭建本地服务器相关
#import <ifaddrs.h>
#import <arpa/inet.h>
#import "HTTPServer.h"
#import "MyHTTPConnection.h"

#import "WebViewJavascriptBridge.h"
#import "Masonry.h"

@interface LocalHtmlViewController ()<WKUIDelegate,WKNavigationDelegate,WKScriptMessageHandler>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) HTTPServer *httpServer;
@property (nonatomic, copy)   NSString *port;

@property (nonatomic, strong) WebViewJavascriptBridge *bridge;

@end

@implementation LocalHtmlViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.title = @"LocalHtml";
    [self.view addSubview:self.webView];
    [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.bottom.equalTo(self.view);
    }];
    
    //1、WebViewJavascriptBridge
    {
        
        NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"html"];
        NSString *appHtml = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
        NSURL *baseURL = [NSURL fileURLWithPath:htmlPath];
        [self.webView loadHTMLString:appHtml baseURL:baseURL];
        
        [WebViewJavascriptBridge enableLogging];
        self.bridge = [WebViewJavascriptBridge bridgeForWebView:self.webView];
        [self.bridge setWebViewDelegate:self];
        [self renderButtons:self.webView];
        
        [self.bridge registerHandler:@"getUserIdFromObjC" handler:^(id data, WVJBResponseCallback responseCallback) {
            NSLog(@"js call getUserIdFromObjC, data from js is %@", data);
            if (responseCallback) {
                // 反馈给JS
                responseCallback(@{@"userId": @"123456"});
            }
        }];
        
        [self.bridge registerHandler:@"getBlogNameFromObjC" handler:^(id data, WVJBResponseCallback responseCallback) {
            NSLog(@"js call getBlogNameFromObjC, data from js is %@", data);
            if (responseCallback) {
                // 反馈给JS
                responseCallback(@{@"blogName": @"技术博客"});
            }
        }];
        
        [self.bridge callHandler:@"getUserInfos" data:@{@"name": @"标哥"} responseCallback:^(id responseData) {
            NSLog(@"from js: %@", responseData);
        }];
    }
   
   //2、本地html服务+原生js回调
    /*
    {
        //配置本地iPhone服务器
        [self configLocalHttpServer];
        //通过WKWebView加载本地测试页，在同一局域网的电脑端，可以通过ip+port的方式访问该网页
        NSString *str = [NSString stringWithFormat:@"http://localhost:%@",self.port];
        NSURL *url = [NSURL URLWithString:str];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [self.webView loadRequest:request];
    }
     */

    
  
}

//配置本地iPhone服务器
- (void)configLocalHttpServer
{
    _httpServer = [[HTTPServer alloc] init];
    [_httpServer setType:@"_http._tcp."];
//    [_httpServer setPort:12345];
    NSString *webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"web"];
    [_httpServer setDocumentRoot:webPath];//web必须为实际文件目录
    [_httpServer setConnectionClass:[MyHTTPConnection class]];//MyHTTPConnection为链接上传处理类
    NSError *err;
    if ([_httpServer start:&err]) {
        //开启服务
        self.port = [NSString stringWithFormat:@"%d",[_httpServer listeningPort]];
        NSLog(@"port %hu",[_httpServer listeningPort]);
        
    }else{
        NSLog(@"%@",err);
    }
    NSString *ipStr = [self getIpAddresses];
    NSLog(@"ip地址 %@", ipStr);
}

//获取ip地址
- (NSString *)getIpAddresses{
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0)
    {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL)
        {
            if(temp_addr->ifa_addr->sa_family == AF_INET)
            {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"])
                {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;
}



- (WKWebView *)webView
{
    if (!_webView) {
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        config.selectionGranularity = WKSelectionGranularityDynamic;//用户长按复制文字的选择区域是用户自定义
        config.allowsInlineMediaPlayback = YES;
        
        //js注入，所有页面加载完毕后弹出一个对话框
        WKUserContentController *userContentController = [[WKUserContentController alloc] init];
//        NSString *javaScriptSource = @"alert(\"WKUserScript注入js\");";
//        WKUserScript *userScript = [[WKUserScript alloc] initWithSource:javaScriptSource injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO];
//        [userContentController addUserScript:userScript];
        //原生js->oc注册回调
        [userContentController addScriptMessageHandler:self name:@"sayhello"];
        config.userContentController = userContentController;
        
        WKPreferences *preferences = [[WKPreferences alloc] init];
        preferences.javaScriptEnabled = YES;
        preferences.javaScriptCanOpenWindowsAutomatically = YES;
        config.preferences = preferences;
        
        _webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
        _webView.UIDelegate = self;
        _webView.navigationDelegate = self;

    }
    return _webView;
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    //页面开始加载
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
    //开始返回内容
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    //页面加载完成
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(nonnull NSError *)error
{
    //页面加载失败
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    //加载失败
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView
{
    //网页加载内容进程终止
}
- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation
{
    //跳转到其他服务器
}


- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    /* 在发送请求之前，决定是否跳转 */
    //允许跳转
    decisionHandler(WKNavigationActionPolicyAllow);
    //不允许跳转
    //decisionHandler(WKNavigationActionPolicyCancel);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    /* 在收到响应后，决定是否跳转 */
    //允许跳转
    decisionHandler(WKNavigationResponsePolicyAllow);
    //不允许跳转
    //decisionHandler(WKNavigationResponsePolicyCancel);
}

#pragma mark - WKUIDelegate
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
    //创建新webView
    //直接在当前网页去加载要load的请求
    if (!navigationAction.targetFrame.isMainFrame) {
        [webView loadRequest:navigationAction.request];
    }
    return nil;
}


- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler
{
    //js调用alert(),实现此方法弹框
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"alert" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定1" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler();
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)webViewDidClose:(WKWebView *)webView {
    
}


- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL result))completionHandler {
    //js确认框
    completionHandler(YES);
}

- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(nullable NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable result))completionHandler {
    completionHandler(@"oc对象");
}


- (BOOL)webView:(WKWebView *)webView shouldPreviewElement:(WKPreviewElementInfo *)elementInfo {
    //决定是否允许加载预览视图
    return YES;
}



- (void)webView:(WKWebView *)webView commitPreviewingViewController:(UIViewController *)previewingViewController {
    
    NSLog(@"Called when the user performs a pop action on the preview.");
}

#pragma mark - WKScriptMessageHandler
//系统原生JS->OC回调
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message{
    NSLog(@"name:%@\\\\n body:%@\\\\n frameInfo:%@\\\\n",message.name,message.body,message.frameInfo);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/


- (void)renderButtons:(WKWebView*)webView {
    UIFont* font = [UIFont fontWithName:@"HelveticaNeue" size:12.0];
    
    UIButton *callbackButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [callbackButton setTitle:@"打开博文" forState:UIControlStateNormal];
    [callbackButton addTarget:self action:@selector(onOpenBlogArticle:) forControlEvents:UIControlEventTouchUpInside];
    [self.view insertSubview:callbackButton aboveSubview:webView];
    callbackButton.frame = CGRectMake(10, 400, 100, 35);
    callbackButton.titleLabel.font = font;
    
    UIButton* reloadButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [reloadButton setTitle:@"刷新webview" forState:UIControlStateNormal];
    [reloadButton addTarget:webView action:@selector(reload) forControlEvents:UIControlEventTouchUpInside];
    [self.view insertSubview:reloadButton aboveSubview:webView];
    reloadButton.frame = CGRectMake(110, 400, 100, 35);
    reloadButton.titleLabel.font = font;
}

- (void)onOpenBlogArticle:(id)sender {
    // 调用打开本demo的博文
    [self.bridge callHandler:@"openWebviewBridgeArticle" data:nil];
}
@end
