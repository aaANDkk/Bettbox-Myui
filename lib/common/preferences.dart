import 'dart:async';
import 'dart:convert';

import 'package:bett_box/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constant.dart';

import 'print.dart';

class Preferences {
  static Preferences? _instance;
  Completer<SharedPreferences?> sharedPreferencesCompleter = Completer();

  Future<bool> get isInit async => await sharedPreferencesCompleter.future != null;

  Preferences._internal() {
    SharedPreferences.getInstance()
        .then((value) => sharedPreferencesCompleter.complete(value))
        .onError((_, _) => sharedPreferencesCompleter.complete(null));
  }

  factory Preferences() {
    _instance ??= Preferences._internal();
    return _instance!;
  }

  Future<ClashConfig?> getClashConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    final clashConfigString = preferences?.getString(clashConfigKey);
    if (clashConfigString == null) return null;
    try {
      final clashConfigMap = json.decode(clashConfigString);
      return ClashConfig.fromJson(clashConfigMap);
    } catch (e, stackTrace) {
      commonPrint.log('Failed to parse clash config from preferences: $e\n$stackTrace');
      return null;
    }
  }

  Future<Config?> getConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    final configString = preferences?.getString(configKey);
    if (configString == null) return null;
    try {
      final configMap = json.decode(configString);
      final config = Config.compatibleFromJson(configMap);

      if (preferences?.getBool('autoLaunch') != config.appSetting.autoLaunch) {
        await preferences?.setBool('autoLaunch', config.appSetting.autoLaunch);
      }

      return config;
    } catch (e, stackTrace) {
      commonPrint.log('Failed to parse config from preferences: $e\n$stackTrace');
      return null;
    }
  }

  Future<bool> saveConfig(Config config) async {
    final preferences = await sharedPreferencesCompleter.future;
    
    await preferences?.setBool('autoLaunch', config.appSetting.autoLaunch);
    
    return await preferences?.setString(configKey, json.encode(config)) ??
        false;
  }

  /// 读取「亮屏锁」开关的上次状态（默认关闭）
  Future<bool> getWakelockEnabled() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getBool(wakelockEnabledKey) ?? false;
  }

  /// 记录「亮屏锁」开关状态，重启应用后自动恢复（完全退出时仍会释放系统锁）
  Future<void> setWakelockEnabled(bool value) async {
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setBool(wakelockEnabledKey, value);
  }

  /// 小型流量统计小部件显示上传还是下载数据（默认下载）
  Future<bool> getTrafficUsageShowUpload() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getBool(trafficUsageShowUploadKey) ?? false;
  }

  Future<void> setTrafficUsageShowUpload(bool value) async {
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setBool(trafficUsageShowUploadKey, value);
  }

  Future<void> clearClashConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    preferences?.remove(clashConfigKey);
  }

  Future<void> clearPreferences() async {
    final sharedPreferencesIns = await sharedPreferencesCompleter.future;
    sharedPreferencesIns?.clear();
  }
}

final preferences = Preferences();
