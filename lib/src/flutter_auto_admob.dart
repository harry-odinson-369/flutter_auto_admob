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

Completer? _interstitialAdCompleter;
Completer? _appOpenAdCompleter;

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

  static void _pauseAppOpenAd() {
    _isAppOpenAdCoolingDown = true;
    _appOpenAdTimer?.cancel();
    _appOpenAdTimer = null;
  }

  static void _resumeAppOpenAd() {
    Future.delayed(_config.delayBetween, () {
      _isAppOpenAdCoolingDown = false;
      _appOpenAdTimer = Timer.periodic(
        _config.calculatedAppOpenAdCooldown,
        _onAppOpenAdTimerExecuted,
      );
    });
  }

  static void _pauseInterstitialAd() {
    _isInterstitialAdCoolingDown = true;
    _interstitialAdTimer?.cancel();
    _interstitialAdTimer = null;
  }

  static void _resumeInterstitialAd() {
    Future.delayed(_config.delayBetween, () {
      _isInterstitialAdCoolingDown = false;
      _interstitialAdTimer = Timer.periodic(
        _config.calculatedInterstitialAdCooldown,
        _onInterstitialAdTimerExecuted,
      );
    });
  }

  static void _createAppOpenCompleter() {
    if (_appOpenAdCompleter?.isCompleted == false) {
      _appOpenAdCompleter?.complete();
    }
    _appOpenAdCompleter = null;
    _appOpenAdCompleter = Completer();
  }

  static void _completeAppOpenAd() {
    if (_appOpenAdCompleter?.isCompleted == false) {
      _appOpenAdCompleter?.complete();
    }
  }

  static void _createInterstitialAdCompleter() {
    if (_interstitialAdCompleter?.isCompleted == false) {
      _interstitialAdCompleter?.complete();
    }
    _interstitialAdCompleter = null;
    _interstitialAdCompleter = Completer();
  }

  static void _completeInterstitialAd() {
    if (_interstitialAdCompleter?.isCompleted == false) {
      _interstitialAdCompleter?.complete();
    }
  }

  static void _onInterstitialAdTimerExecuted(Timer timer) {
    if (_config.interstitialAdLoadType == AutoAdmobLoadType.none) {
      _isInterstitialAdCoolingDown = false;
    } else {
      if (_interstitialAd == null) {
        _createInterstitialAdCompleter();
        InterstitialAd.load(
          adUnitId: _config.interstitialAdUnitId,
          request: AdRequest(),
          adLoadCallback: InterstitialAdLoadCallback(
            onAdLoaded: (ad) {
              _interstitialAd = ad;
              _interstitialAd
                  ?.fullScreenContentCallback = FullScreenContentCallback(
                onAdShowedFullScreenContent: (ad) {
                  _pauseAppOpenAd();
                },
                onAdDismissedFullScreenContent: (ad) {
                  _isInterstitialAdCoolingDown = true;
                  Future.delayed(Duration(seconds: 3), () async {
                    await _interstitialAd?.dispose();
                    _interstitialAd = null;
                  });
                  _resumeAppOpenAd();
                  _completeInterstitialAd();
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
        _createAppOpenCompleter();
        AppOpenAd.load(
          adUnitId: _config.appOpenAdUnitId,
          request: AdRequest(),
          adLoadCallback: AppOpenAdLoadCallback(
            onAdLoaded: (ad) {
              _appOpenAd = ad;
              _appOpenAd?.fullScreenContentCallback = FullScreenContentCallback(
                onAdShowedFullScreenContent: (ad) {
                  _pauseInterstitialAd();
                },
                onAdDismissedFullScreenContent: (ad) {
                  _isAppOpenAdCoolingDown = true;
                  Future.delayed(Duration(seconds: 3), () async {
                    await _appOpenAd?.dispose();
                    _appOpenAd = null;
                  });
                  _resumeInterstitialAd();
                  _completeAppOpenAd();
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
    bool waitUntil = true,
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
        _createInterstitialAdCompleter();
        await InterstitialAd.load(
          adUnitId: config.interstitialAdUnitId,
          request: AdRequest(),
          adLoadCallback:
              callback ??
              InterstitialAdLoadCallback(
                onAdLoaded: (ad) {
                  ad.fullScreenContentCallback = FullScreenContentCallback(
                    onAdShowedFullScreenContent: (ad) {
                      _pauseAppOpenAd();
                    },
                    onAdDismissedFullScreenContent: (ad) {
                      _isInterstitialAdCoolingDown = true;
                      ad.dispose();
                      _resumeAppOpenAd();
                      _completeInterstitialAd();
                    },
                  );
                  ad.show();
                },
                onAdFailedToLoad: (error) => throw Exception(error.message),
              ),
        );
      }
    }
    if (waitUntil) return _interstitialAdCompleter?.future;
  }

  static Future showAppOpenAd({
    AdRequest? request,
    AppOpenAdLoadCallback? callback,
    bool waitUntil = true,
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
        _createAppOpenCompleter();
        await AppOpenAd.load(
          adUnitId: config.appOpenAdUnitId,
          request: AdRequest(),
          adLoadCallback:
              callback ??
              AppOpenAdLoadCallback(
                onAdLoaded: (ad) {
                  ad.fullScreenContentCallback = FullScreenContentCallback(
                    onAdShowedFullScreenContent: (ad) {
                      _pauseInterstitialAd();
                    },
                    onAdDismissedFullScreenContent: (ad) {
                      _isAppOpenAdCoolingDown = true;
                      ad.dispose();
                      _resumeInterstitialAd();
                      _completeAppOpenAd();
                    },
                  );
                  ad.show();
                },
                onAdFailedToLoad: (error) => throw Exception(error.message),
              ),
        );
      }
    }
    if (waitUntil) return _appOpenAdCompleter?.future;
  }
}
