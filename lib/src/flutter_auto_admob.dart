// ignore_for_file: constant_identifier_names, unused_field

import 'dart:async';

import 'package:flutter_auto_admob/src/ads/app_open.dart';
import 'package:flutter_auto_admob/src/ads/interstitial.dart';
import 'package:flutter_auto_admob/src/config.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum AdType { APP_OPEN, INTERSTITIAL }

enum AdState {
  IDLE,
  COOLDOWN,
  REQUESTING,
  LOADED,
  SHOWING,
  DISMISSED,
  IMPRESSION,
  CLICKED,
  FAILED_TO_SHOW,
  FAILED_TO_LOAD,
}

class FlutterAutoAdmob {
  FlutterAutoAdmob();
  FlutterAutoAdmob._singleton();

  FlutterAutoAdmobConfig config = FlutterAutoAdmobConfig();

  static final FlutterAutoAdmob _ads = FlutterAutoAdmob._singleton();
  static FlutterAutoAdmob get ads => _ads;

  AppOpenAdApi get appOpen => AppOpenAdApi.instance;
  InterstitialAdApi get interstitial => InterstitialAdApi.instance;

  /// This [configure] function must be called once for the first time before the ads request.
  Future<InitializationStatus> configure({
    required FlutterAutoAdmobConfig config,
  }) async {
    this.config = config;
    appOpen.configure(config);
    interstitial.configure(config);
    return MobileAds.instance.initialize();
  }

}
