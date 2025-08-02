import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_openseeface_plugin_method_channel.dart';

abstract class FlutterOpenseefacePluginPlatform extends PlatformInterface {
  /// Constructs a FlutterOpenseefacePluginPlatform.
  FlutterOpenseefacePluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterOpenseefacePluginPlatform _instance = MethodChannelFlutterOpenseefacePlugin();

  /// The default instance of [FlutterOpenseefacePluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterOpenseefacePlugin].
  static FlutterOpenseefacePluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterOpenseefacePluginPlatform] when
  /// they register themselves.
  static set instance(FlutterOpenseefacePluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
