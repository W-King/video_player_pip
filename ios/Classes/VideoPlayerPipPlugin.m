#import "VideoPlayerPipPlugin.h"
#import "AppDelegate.h"

NSString *channelNameYKT = @"com.xuetangx.ykt/xtVideoPlay";
NSString *channelNameRain = @"com.xuetangx.rain/xtVideoPlay";

typedef enum : NSUInteger
{
    WillStartPictureInPicture = 1,
    DidStartPictureInPicture = 2,
    failedToStartPictureInPictureWithError = 3,
    WillStopPictureInPicture = 4,
    DidStopPictureInPicture = 5,
    restoreUserInterfaceForPictureInPicture = 6,

} VideoPIPState;

typedef enum : NSUInteger
{
    video_play = 1,
    video_pause = 2,
    video_seek = 3,
    video_end = 4,

} VideoState;

@interface VideoPlayerPipPlugin ()
{
    NSInteger videoValue;
    BOOL isRestoreFlutterPlay;
    BOOL isPlay;

}
@property (strong, nonatomic) FlutterResult                 result;
@property (nonatomic,strong) AVPlayer                       *player;
@property (nonatomic,strong) AVPlayerLayer                  *playerLayer;

@property (nonatomic,strong) AVPictureInPictureController   *pip;

@property (nonatomic, assign) VideoPIPState                 videoPIPState;
@property (nonatomic, assign) VideoState                    videoState;

/*
 videoPIPState
 {
 1:即将开启画中画
 2:已经开启画中画
 3:开启画中画失败
 4:即将关闭画中画
 5:已经关闭画中画
 6:关闭画中画且恢复播放界面
 }
 videoState
 {
 1:play
 2:pause
 3:seek
 4:stop
 }
 videoEndValue
 */
@property (nonatomic, copy) FlutterEventSink eventSink;


@end

@implementation VideoPlayerPipPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"video_player_pip"
            binaryMessenger:[registrar messenger]];
  VideoPlayerPipPlugin* instance = [[VideoPlayerPipPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
    
    FlutterEventChannel *evenChannal = [FlutterEventChannel eventChannelWithName:channelNameRain binaryMessenger:[registrar messenger]];
        // 代理FlutterStreamHandler
    [evenChannal setStreamHandler:instance];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    isRestoreFlutterPlay = NO;
    __weak typeof (self)weakSelf = self;
    if ([@"starPalyVideo" isEqualToString:call.method]) {
        
        NSLog(@"开启PalyVideo");
        NSDictionary *dic = call.arguments;
        [weakSelf starVideoPalyVideoUrl:dic[@"videoUrl"]
                              videoType:dic[@"videoType"]];
        
    }else if([@"enablePIP" isEqualToString:call.method]){
        //开启pip
        NSLog(@"开启画中画");
        NSDictionary *dic = call.arguments;
        [weakSelf enablePIPVideoSeek:dic[@"videoSeek"]];
        
    }else if([@"disablePIP" isEqualToString:call.method]){
        //关闭pip
        [weakSelf disablePIP];
        
    }else{
        result(FlutterMethodNotImplemented);
    }
}

- (void)starVideoPalyVideoUrl:(NSString *)videoUrl
                    videoType:(NSString *)videoType
{
    self.player = nil;
    self.playerLayer = nil;
    self.pip = nil;
    self.pip.delegate = nil;
    videoValue = 0;
    
    if ([videoType isEqualToString:@"0"]) {
        self.player = [AVPlayer playerWithURL:[NSURL URLWithString:videoUrl]];
    }else{
        self.player = [AVPlayer playerWithURL:[NSURL fileURLWithPath:videoUrl]];
    }
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    [self.playerLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    [self.playerLayer setFrame:CGRectMake(0, -200, 100, 100)];
    AppDelegate * appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate.window.rootViewController.view.layer addSublayer:self.playerLayer];
    //1.判断是否支持画中画功能
    if ([AVPictureInPictureController isPictureInPictureSupported]) {
        //2.开启权限
        @try {
            NSError *error = nil;
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
            [[AVAudioSession sharedInstance] setActive:YES error:&error];
        } @catch (NSException *exception) {
            NSLog(@"AVAudioSession错误");
        }
        self.pip = [[AVPictureInPictureController alloc] initWithPlayerLayer:self.playerLayer];
        self.pip.delegate = self;
    }
}

- (void)enablePIPVideoSeek:(NSString *)videoSeek
{
    if ([self isBlankString:videoSeek]) {
        videoValue = 0;
    }else{
        videoValue = [videoSeek integerValue];
    }
    CMTime dragedCMTime = CMTimeMake(videoValue, 1); //kCMTimeZero
    [_player seekToTime:dragedCMTime toleranceBefore:CMTimeMake(1,1) toleranceAfter:CMTimeMake(1,1) completionHandler:^(BOOL finished) {
        _videoState = video_play;
    }];
    __weak typeof (self)weakSelf = self;
    [_player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 1.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        /// 更新播放进度
        NSLog(@"time: %@",@(time.value/time.timescale));
        videoValue = time.value/time.timescale;
        _videoState = video_play;
        [weakSelf ocPassFlutterVideoState:_videoState];
    }];
    [self.pip startPictureInPicture];
    isPlay = YES;
    [_player play];/// 添加监听.以及回调
}

- (void)disablePIP{
    [self.pip stopPictureInPicture];
    [_player pause];
}

// 即将开启画中画
- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    NSLog(@"即将开启画中画");
    _videoPIPState = WillStartPictureInPicture;
    [self ocPassFlutterVideoPIPState:_videoPIPState];
}
// 已经开启画中画
- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    NSLog(@"已经开启画中画");
    _videoPIPState = DidStartPictureInPicture;
    [self ocPassFlutterVideoPIPState:_videoPIPState];
}
// 开启画中画失败
- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController failedToStartPictureInPictureWithError:(NSError *)error {
    NSLog(@"开启画中画失败");
    _videoPIPState = failedToStartPictureInPictureWithError;
    [self ocPassFlutterVideoPIPState:_videoPIPState];
}
// 即将关闭画中画
- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    NSLog(@"即将关闭画中画");
    _videoPIPState = WillStopPictureInPicture;
    [self ocPassFlutterVideoPIPState:_videoPIPState];
}
// 已经关闭画中画
- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    NSLog(@"已经关闭画中画");
    if (!isRestoreFlutterPlay) {
        _videoPIPState = DidStopPictureInPicture;
        [self ocPassFlutterVideoPIPState:_videoPIPState];
        _videoState = video_end;
        [_player pause];
    }
    

}
// 关闭画中画且恢复播放界面  ,点击×的时候不走这个方法
- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
    NSLog(@"关闭画中画且恢复播放界面");
    isRestoreFlutterPlay = YES;

    _videoPIPState = restoreUserInterfaceForPictureInPicture;
    _videoState = video_pause;
    [self ocPassFlutterVideoPIPState:_videoPIPState];
    [_player pause];
}
- (void)ocPassFlutterVideoPIPState:(NSInteger )videoPIPState
{
    NSMutableDictionary *messageMutDic = [[NSMutableDictionary alloc]init];
    if (!_videoPIPState) {
        _videoPIPState = WillStartPictureInPicture;
    }
    [messageMutDic setObject:[NSString stringWithFormat:@"%lu",(unsigned long)_videoPIPState] forKey:@"videoPIPState"];
    if (!_videoState) {
        _videoState = video_play;
    }
    [messageMutDic setObject:[NSString stringWithFormat:@"%lu",(unsigned long)_videoState] forKey:@"videoState"];
    [messageMutDic setObject:[NSString stringWithFormat:@"%ld",(long)videoValue] forKey:@"videoEndValue"];
    
    self.eventSink(messageMutDic);
}
- (void)ocPassFlutterVideoState:(NSInteger )videoState
{
    NSMutableDictionary *messageMutDic = [[NSMutableDictionary alloc]init];
    if (!_videoPIPState) {
        _videoPIPState = WillStartPictureInPicture;
    }
    [messageMutDic setObject:[NSString stringWithFormat:@"%lu",(unsigned long)_videoPIPState] forKey:@"videoPIPState"];
    if (!_videoState) {
        _videoState = video_play;
    }
    [messageMutDic setObject:[NSString stringWithFormat:@"%lu",(unsigned long)_videoState] forKey:@"videoState"];
    [messageMutDic setObject:[NSString stringWithFormat:@"%ld",(long)videoValue] forKey:@"videoEndValue"];
    
    self.eventSink(messageMutDic);
}

#pragma mark - <FlutterStreamHandler>
// 这个onListen是Flutter端开始监听这个channel时的回调，第二个参数 EventSink是用来传数据的载体。
- (FlutterError * _Nullable)onListenWithArguments:(id _Nullable)arguments eventSink:(nonnull FlutterEventSink)events {
    // arguments flutter给native的参数
    // 回调给flutter， 建议使用实例指向，因为该block可以使用多次
    if (events) {
//      events(@"FlutterStreamHandler iOS");
      self.eventSink = events;
    }
    return nil;
}

/// flutter不再接收
- (FlutterError * _Nullable)onCancelWithArguments:(id _Nullable)arguments {
    self.eventSink = nil;
    return nil;
}

- (BOOL)isBlankString:(NSString *)string {//判断字符串是否为空 方法

   if (string == nil || string == NULL) {
       return YES;
   }
   if ([string isKindOfClass:[NSNull class]]) {
       return YES;
   }
   if ([[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length]==0) {
       return YES;
   }
   return NO;
}


/*
 - (void)startPlay;
 - (void)pusePaly;
 - (void)closePlay;
 - (void)seekPlay;
 - (void)endVideo;
 - (void)endPIPVideo;
 */
@end
