
import 'dart:async';

import 'package:flutter/services.dart';

class VideoPlayerPip {
  static const MethodChannel _channel =
      const MethodChannel('video_player_pip');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
