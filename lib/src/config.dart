import 'dart:io';

enum AutoAdmobLoadType { none, preload }

class AutoAdmobConfig {
  String interstitialAdUnitId = "";
  String appOpenAdUnitId = "";

  Duration interstitialCooldown = Duration(minutes: 3);
  Duration appOpenAdCooldown = Duration(minutes: 3);
  Duration delayBetween = Duration(minutes: 3);

  AutoAdmobLoadType interstitialAdLoadType = AutoAdmobLoadType.preload;
  AutoAdmobLoadType appOpenAdLoadType = AutoAdmobLoadType.preload;

  AutoAdmobConfig copyWith({
    String? interstitialAdUnitId,
    String? appOpenAdUnitId,
    Duration? interstitialCooldown,
    Duration? appOpenAdCooldown,
    Duration? delayBetween,
    AutoAdmobLoadType? appOpenAdLoadType,
    AutoAdmobLoadType? interstitialAdLoadType,
  }) => AutoAdmobConfig(
    interstitialAdUnitId: interstitialAdUnitId ?? this.interstitialAdUnitId,
    appOpenAdUnitId: appOpenAdUnitId ?? this.appOpenAdUnitId,
    appOpenAdCooldown: appOpenAdCooldown ?? this.appOpenAdCooldown,
    interstitialCooldown: interstitialCooldown ?? this.interstitialCooldown,
    delayBetween: delayBetween ?? this.delayBetween,
    appOpenAdLoadType: appOpenAdLoadType ?? this.appOpenAdLoadType,
    interstitialAdLoadType:
        interstitialAdLoadType ?? this.interstitialAdLoadType,
  );

  Duration get calculatedInterstitialAdCooldown {
    if (interstitialAdLoadType == AutoAdmobLoadType.preload) {
      return Duration(seconds: interstitialCooldown.inSeconds - 15);
    } else {
      return interstitialCooldown;
    }
  }

  Duration get calculatedAppOpenAdCooldown {
    if (appOpenAdLoadType == AutoAdmobLoadType.preload) {
      return Duration(seconds: appOpenAdCooldown.inSeconds - 15);
    } else {
      return appOpenAdCooldown;
    }
  }

  AutoAdmobConfig({
    this.interstitialAdUnitId = "",
    this.appOpenAdUnitId = "",
    this.interstitialCooldown = const Duration(minutes: 3),
    this.appOpenAdCooldown = const Duration(minutes: 3),
    this.interstitialAdLoadType = AutoAdmobLoadType.preload,
    this.appOpenAdLoadType = AutoAdmobLoadType.preload,
    this.delayBetween = const Duration(minutes: 3),
  });

  static AutoAdmobConfig get test => AutoAdmobConfig(
    appOpenAdUnitId:
        Platform.isIOS
            ? "ca-app-pub-3940256099942544/5575463023"
            : "ca-app-pub-3940256099942544/9257395921",
    interstitialAdUnitId:
        Platform.isIOS
            ? "ca-app-pub-3940256099942544/4411468910"
            : "ca-app-pub-3940256099942544/1033173712",
  );
}
