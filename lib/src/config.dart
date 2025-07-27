enum FlutterAutoAdmobLoadType { none, preload }

class FlutterAutoAdmobConfig {

  String interstitialAdUnitId = "";
  String appOpenAdUnitId = "";

  Duration interstitialCooldown = Duration(minutes: 3);
  Duration appOpenAdCooldown = Duration(minutes: 3);

  FlutterAutoAdmobLoadType interstitialAdLoadType = FlutterAutoAdmobLoadType.preload;
  FlutterAutoAdmobLoadType appOpenAdLoadType = FlutterAutoAdmobLoadType.preload;

  FlutterAutoAdmobConfig({
    this.interstitialAdUnitId = "",
    this.appOpenAdUnitId = "",
    this.interstitialCooldown = const Duration(minutes: 3),
    this.appOpenAdCooldown = const Duration(minutes: 3),
    this.interstitialAdLoadType = FlutterAutoAdmobLoadType.preload,
    this.appOpenAdLoadType = FlutterAutoAdmobLoadType.preload,
  });

  FlutterAutoAdmobConfig copyWith({
    String? interstitialAdUnitId,
    String? appOpenAdUnitId,
    Duration? interstitialCooldown,
    Duration? appOpenAdCooldown,
    FlutterAutoAdmobLoadType? appOpenAdLoadType,
    FlutterAutoAdmobLoadType? interstitialAdLoadType,
  }) => FlutterAutoAdmobConfig(
    interstitialAdUnitId: interstitialAdUnitId ?? this.interstitialAdUnitId,
    appOpenAdUnitId: appOpenAdUnitId ?? this.appOpenAdUnitId,
    appOpenAdCooldown: appOpenAdCooldown ?? this.appOpenAdCooldown,
    interstitialCooldown: interstitialCooldown ?? this.interstitialCooldown,
    appOpenAdLoadType: appOpenAdLoadType ?? this.appOpenAdLoadType,
    interstitialAdLoadType: interstitialAdLoadType ?? this.interstitialAdLoadType,
  );

  Duration get calculatedInterstitialAdCooldown {
    if (interstitialAdLoadType == FlutterAutoAdmobLoadType.preload) {
      return Duration(seconds: interstitialCooldown.inSeconds - 15);
    } else {
      return interstitialCooldown;
    }
  }

  Duration get calculatedAppOpenAdCooldown {
    if (appOpenAdLoadType == FlutterAutoAdmobLoadType.preload) {
      return Duration(seconds: appOpenAdCooldown.inSeconds - 15);
    } else {
      return appOpenAdCooldown;
    }
  }
}
