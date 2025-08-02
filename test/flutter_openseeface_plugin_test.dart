import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_openseeface_plugin/flutter_openseeface_plugin.dart';
import 'package:flutter_openseeface_plugin/flutter_openseeface_plugin_platform_interface.dart';
import 'package:flutter_openseeface_plugin/flutter_openseeface_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterOpenseefacePluginPlatform
    with MockPlatformInterfaceMixin
    implements FlutterOpenseefacePluginPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterOpenseefacePluginPlatform initialPlatform = FlutterOpenseefacePluginPlatform.instance;

  test('$MethodChannelFlutterOpenseefacePlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterOpenseefacePlugin>());
  });

  test('getPlatformVersion', () async {
    FlutterOpenseefacePlugin flutterOpenseefacePlugin = FlutterOpenseefacePlugin();
    MockFlutterOpenseefacePluginPlatform fakePlatform = MockFlutterOpenseefacePluginPlatform();
    FlutterOpenseefacePluginPlatform.instance = fakePlatform;

    expect(await flutterOpenseefacePlugin.getPlatformVersion(), '42');
  });
}
