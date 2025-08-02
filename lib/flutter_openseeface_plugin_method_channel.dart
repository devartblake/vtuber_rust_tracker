import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_openseeface_plugin_platform_interface.dart';

/// An implementation of [FlutterOpenseefacePluginPlatform] that uses method channels.
class MethodChannelFlutterOpenseefacePlugin extends FlutterOpenseefacePluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_openseeface_plugin');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
