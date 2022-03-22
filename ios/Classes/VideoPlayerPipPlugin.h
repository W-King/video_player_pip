#import <Flutter/Flutter.h>
#import <Foundation/Foundation.h>
#import <AVKit/AVKit.h>

@interface VideoPlayerPipPlugin : NSObject
<FlutterPlugin,
FlutterStreamHandler,
UNUserNotificationCenterDelegate,
AVPictureInPictureControllerDelegate>
@end
