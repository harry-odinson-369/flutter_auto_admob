import 'dart:async';
import 'dart:developer';

import 'package:flutter_auto_admob/src/config.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

AutoAdmobConfig _config = AutoAdmobConfig();
bool _isInitialized = false;

bool _isInterstitialAdCoolingDown = true;
bool _isAppOpenAdCoolingDown = true;

InterstitialAd? _interstitialAd;
AppOpenAd? _appOpenAd;

Timer? _interstitialAdTimer;
Timer? _appOpenAdTimer;

class AutoAdmob {
  static AutoAdmobConfig get config => _config;
  static set config(AutoAdmobConfig config) {
    _config = config;
  }

  static void onAppLifeCycleStateChanged(
    void Function(AppState state) stateChanged,
  ) {
    AppStateEventNotifier.startListening();
    AppStateEventNotifier.appStateStream.forEach(stateChanged);
    log("[AUTO ADMOB] started listening app life cycle state.");
  }

  static Future initialize({AutoAdmobConfig? config}) async {
    if (config != null) _config = config;
    assert(
      _config.interstitialCooldown.inSeconds >= 60,
      "[AUTO ADMOB] the interstitial ad cool down should be equal or greater than 1 minute.",
    );
    assert(
      _config.appOpenAdCooldown.inSeconds >= 60,
      "[AUTO ADMOB] the app open ad cool down should be equal or greater than 1 minute.",
    );
    await MobileAds.instance.initialize();
    _isInitialized = true;
    _interstitialAdTimer = Timer.periodic(
      _config.calculatedInterstitialAdCooldown,
      _onInterstitialAdTimerExecuted,
    );
    _appOpenAdTimer = Timer.periodic(
      _config.calculatedAppOpenAdCooldown,
      _onAppOpenAdTimerExecuted,
    );
  }

  /// Cancel all auto ad and will require to call initialize again.
  static Future destroy() async {
    _interstitialAdTimer?.cancel();
    _appOpenAdTimer?.cancel();
    _interstitialAdTimer = null;
    _appOpenAdTimer = null;
    _isInterstitialAdCoolingDown = true;
    _isAppOpenAdCoolingDown = true;
    await _interstitialAd?.dispose();
    await _appOpenAd?.dispose();
    _interstitialAd = null;
    _appOpenAd = null;
    _isInitialized = false;
  }

  static void _delayBetweenAppOpenAd() {
    _isAppOpenAdCoolingDown = true;
    _appOpenAdTimer?.cancel();
    _appOpenAdTimer = null;
    Future.delayed(_config.delayBetween, () {
      _isAppOpenAdCoolingDown = false;
      _appOpenAdTimer = Timer.periodic(
        _config.calculatedAppOpenAdCooldown,
        _onAppOpenAdTimerExecuted,
      );
    });
  }

  static void _delayBetweenInterstitialAd() {
    _isInterstitialAdCoolingDown = true;
    _interstitialAdTimer?.cancel();
    _interstitialAdTimer = null;
    Future.delayed(_config.delayBetween, () {
      _isInterstitialAdCoolingDown = false;
      _interstitialAdTimer = Timer.periodic(
        _config.calculatedInterstitialAdCooldown,
        _onInterstitialAdTimerExecuted,
      );
    });
  }

  static void _onInterstitialAdTimerExecuted(Timer timer) {
    if (_config.interstitialAdLoadType == AutoAdmobLoadType.none) {
      _isInterstitialAdCoolingDown = false;
    } else {
      if (_interstitialAd == null) {
        InterstitialAd.load(
          adUnitId: _config.interstitialAdUnitId,
          request: AdRequest(),
          adLoadCallback: InterstitialAdLoadCallback(
            onAdLoaded: (ad) {
              _interstitialAd = ad;
              _interstitialAd
                  ?.fullScreenContentCallback = FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  _isInterstitialAdCoolingDown = true;
                  Future.delayed(Duration(seconds: 3), () async {
                    await _interstitialAd?.dispose();
                    _interstitialAd = null;
                  });
                  _delayBetweenAppOpenAd();
                },
              );
              log(
                "[AUTO ADMOB] [Preload Ad] got a new interstitial ad and will be ready to show in next 15 seconds.",
              );
              Future.delayed(Duration(seconds: 15), () {
                _isInterstitialAdCoolingDown = false;
              });
            },
            onAdFailedToLoad: (error) => throw Exception(error.message),
          ),
        );
      }
    }
  }

  static void _onAppOpenAdTimerExecuted(Timer timer) {
    if (_config.appOpenAdLoadType == AutoAdmobLoadType.none) {
      _isAppOpenAdCoolingDown = false;
    } else {
      if (_appOpenAd == null) {
        AppOpenAd.load(
          adUnitId: _config.appOpenAdUnitId,
          request: AdRequest(),
          adLoadCallback: AppOpenAdLoadCallback(
            onAdLoaded: (ad) {
              _appOpenAd = ad;
              _appOpenAd?.fullScreenContentCallback = FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  _isAppOpenAdCoolingDown = true;
                  Future.delayed(Duration(seconds: 3), () async {
                    await _appOpenAd?.dispose();
                    _appOpenAd = null;
                  });
                  _delayBetweenInterstitialAd();
                },
              );
              log(
                "[AUTO ADMOB] [Preload Ad] got a new app open ad and will be ready to show in next 15 seconds.",
              );
              Future.delayed(Duration(seconds: 15), () {
                _isAppOpenAdCoolingDown = false;
              });
            },
            onAdFailedToLoad: (error) => throw Exception(error.message),
          ),
        );
      }
    }
  }

  static Future showInterstitialAd({
    AdRequest? request,
    InterstitialAdLoadCallback? callback,
  }) async {
    assert(_isInitialized, "[AUTO ADMOB] you need to call initialize first!");
    assert(
      config.interstitialAdUnitId.isNotEmpty,
      "[AUTO ADMOB] interstitial ad unit id must not empty or null.",
    );
    if (!_isInterstitialAdCoolingDown) {
      if (config.interstitialAdLoadType == AutoAdmobLoadType.preload) {
        _interstitialAd?.show();
      } else {
        await InterstitialAd.load(
          adUnitId: config.interstitialAdUnitId,
          request: AdRequest(),
          adLoadCallback:
              callback ??
              InterstitialAdLoadCallback(
                onAdLoaded: (ad) {
                  ad.fullScreenContentCallback = FullScreenContentCallback(
                    onAdDismissedFullScreenContent: (ad) {
                      _isInterstitialAdCoolingDown = true;
                      ad.dispose();
                      _delayBetweenAppOpenAd();
                    },
                  );
                  ad.show();
                },
                onAdFailedToLoad: (error) => throw Exception(error.message),
              ),
        );
      }
    }
  }

  static Future showAppOpenAd({
    AdRequest? request,
    AppOpenAdLoadCallback? callback,
  }) async {
    assert(_isInitialized, "[AUTO ADMOB] you need to call initialize first!");
    assert(
      config.appOpenAdUnitId.isNotEmpty,
      "[AUTO ADMOB] app open ad unit id must not empty or null.",
    );
    if (!_isAppOpenAdCoolingDown) {
      if (config.appOpenAdLoadType == AutoAdmobLoadType.preload) {
        _appOpenAd?.show();
      } else {
        await AppOpenAd.load(
          adUnitId: config.appOpenAdUnitId,
          request: AdRequest(),
          adLoadCallback:
              callback ??
              AppOpenAdLoadCallback(
                onAdLoaded: (ad) {
                  ad.fullScreenContentCallback = FullScreenContentCallback(
                    onAdDismissedFullScreenContent: (ad) {
                      _isAppOpenAdCoolingDown = true;
                      ad.dispose();
                      _delayBetweenInterstitialAd();
                    },
                  );
                  ad.show();
                },
                onAdFailedToLoad: (error) => throw Exception(error.message),
              ),
        );
      }
    }
  }
}
