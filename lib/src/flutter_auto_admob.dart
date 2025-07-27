// ignore_for_file: constant_identifier_names, unused_field

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_auto_admob/src/config.dart';
import 'package:flutter_auto_admob/src/extension.dart';
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
  FlutterAutoAdmob._();

  static final FlutterAutoAdmob _instance = FlutterAutoAdmob._();
  static FlutterAutoAdmob get instance => _instance;

  FlutterAutoAdmobConfig _config = FlutterAutoAdmobConfig();

  AdState _interstitialAdState = AdState.IDLE;
  AdState get interstitialAdState => _interstitialAdState;

  AdState _appOpenAdState = AdState.IDLE;
  AdState get appOpenAdState => _appOpenAdState;

  Timer? _appOpenAdTimer;
  Timer? _interstitialAdTimer;

  AppOpenAd? _appOpenAd;
  InterstitialAd? _interstitialAd;

  Function? onAppOpenAdLoaded;
  Function? onInterstitialAdLoaded;

  /// This [initialize] function must be called once for the first time before the ads request.
  Future<InitializationStatus> initialize({
    required FlutterAutoAdmobConfig config,
  }) async {
    _config = config;
    _appOpenAdState = AdState.COOLDOWN;
    _appOpenAdTimer ??= Timer.periodic(
      _config.calculatedAppOpenAdCooldown,
      (t) => _onAppOpenAdTimerExecuted(),
    );
    _interstitialAdState = AdState.COOLDOWN;
    _interstitialAdTimer ??= Timer.periodic(
      _config.calculatedInterstitialAdCooldown,
      (t) => _onInterstitialAdTimerExecuted(),
    );
    return MobileAds.instance.initialize();
  }

  FullScreenContentCallback<T> _defaultCallback<T>(
    void Function(AdState state, T ad) onStateChanged,
  ) {
    return FullScreenContentCallback<T>(
      onAdShowedFullScreenContent: (ad) {
        onStateChanged(AdState.SHOWING, ad);
      },
      onAdDismissedFullScreenContent: (ad) {
        onStateChanged(AdState.DISMISSED, ad);
      },
      onAdClicked: (ad) {
        onStateChanged(AdState.CLICKED, ad);
      },
      onAdImpression: (ad) {
        onStateChanged(AdState.IMPRESSION, ad);
      },
      onAdFailedToShowFullScreenContent: (ad, err1) {
        onStateChanged(AdState.FAILED_TO_SHOW, ad);
      },
    );
  }

  // Interstitial Ad Section

  /// [useAsync] set to true if you want to wait until user close the ad.
  /// [force] set to true to force the ad request and show immediately as possible.
  Future<bool> showInterstitialAd({
    bool useAsync = false,
    bool force = false,
  }) async {
    if (!_interstitialAdState.isCoolingDown && !_appOpenAdState.isShowing) {
      Completer<bool> completer = Completer<bool>();
      if (_config.interstitialAdLoadType == FlutterAutoAdmobLoadType.none ||
          force) {
        var defCallback = _defaultCallback<InterstitialAd>((state, ad) {
          if (state.isDismissed) {
            completer.done(true);
            resetCoolDownNonePreloadedInterstitialAd(ad);
          } else if (state.isFailed) {
            completer.done(false);
            resetCoolDownNonePreloadedInterstitialAd(ad);
          }
        });
        InterstitialAd? ad = await _requestInterstitialAd(
          callback: defCallback,
        );
        ad?.show();
      } else if (_config.interstitialAdLoadType ==
          FlutterAutoAdmobLoadType.preload) {
        _interstitialAd?.show();
        while (true) {
          if (_interstitialAdState.isDismissed) {
            completer.done(true);
            break;
          } else if (_interstitialAdState.isFailed) {
            completer.done(false);
            break;
          }
          await Future.delayed(Duration(seconds: 1));
        }
      }

      if (useAsync) return completer.future;
      return true;
    }
    return false;
  }

  void resetCoolDownNonePreloadedInterstitialAd(InterstitialAd ad) {
    _interstitialAdState = AdState.COOLDOWN;
    Future.delayed(Duration(seconds: 6), () {
      _interstitialAdState = AdState.IDLE;
      _interstitialAd = null;
      ad.dispose();
    });
  }

  void _onInterstitialAdTimerExecuted() async {
    if (_config.interstitialAdLoadType == FlutterAutoAdmobLoadType.preload) {
      var defCallback = _defaultCallback<InterstitialAd>((state, ad) {
        if (state.isDismissed) {
          resetCoolDownNonePreloadedInterstitialAd(ad);
        } else if (state.isFailed) {
          resetCoolDownNonePreloadedInterstitialAd(ad);
        }
      });
      _interstitialAd ??= await _requestInterstitialAd(callback: defCallback);
      if (_interstitialAd != null) {
        debugPrint(
          "[INTERSTITIAL] Preloaded INTERSTITIAL ad is ready to show in the next 15 seconds.",
        );
        Future.delayed(const Duration(seconds: 15), () {
          onInterstitialAdLoaded?.call();
        });
      }
    } else {
      _interstitialAdState = AdState.IDLE;
      onInterstitialAdLoaded?.call();
    }
  }

  Future<InterstitialAd?> _requestInterstitialAd({
    FullScreenContentCallback<InterstitialAd>? callback,
  }) async {
    Completer<InterstitialAd?> completer = Completer<InterstitialAd?>();
    _interstitialAdState = AdState.REQUESTING;
    InterstitialAd.load(
      adUnitId: _config.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          var defCallback = _defaultCallback<InterstitialAd>(
            (state, ad) => _interstitialAdState = state,
          );
          ad.fullScreenContentCallback = callback ?? defCallback;
          completer.done(ad);
          _interstitialAdState = AdState.LOADED;
        },
        onAdFailedToLoad: (error) {
          completer.done();
          _interstitialAdState = AdState.FAILED_TO_LOAD;
        },
      ),
    );
    return completer.future;
  }

  // End of Interstitial Ad Section

  // App Open Ad Section

  /// [useAsync] set to true if you want to wait until user close the ad.
  /// [force] set to true to force the ad request and show immediately as possible.
  Future<bool> showAppOpenAd({
    bool useAsync = false,
    bool force = false,
  }) async {
    if (!_appOpenAdState.isCoolingDown && !_interstitialAdState.isShowing) {
      Completer<bool> completer = Completer<bool>();
      if (_config.appOpenAdLoadType == FlutterAutoAdmobLoadType.none || force) {
        var defCallback = _defaultCallback<AppOpenAd>((state, ad) {
          if (state.isDismissed) {
            completer.done(true);
            resetCoolDownNonePreloadedAppOpenAd(ad);
          } else if (state.isFailed) {
            completer.done(false);
            resetCoolDownNonePreloadedAppOpenAd(ad);
          }
        });
        AppOpenAd? ad = await _requestAppOpenAd(callback: defCallback);
        ad?.show();
      } else if (_config.appOpenAdLoadType ==
          FlutterAutoAdmobLoadType.preload) {
        _appOpenAd?.show();
        while (true) {
          if (_appOpenAdState.isDismissed) {
            completer.done(true);
            break;
          } else if (_appOpenAdState.isFailed) {
            completer.done(false);
            break;
          }
          await Future.delayed(Duration(seconds: 1));
        }
      }

      if (useAsync) return completer.future;
      return true;
    }
    return false;
  }

  void resetCoolDownNonePreloadedAppOpenAd(AppOpenAd ad) {
    _appOpenAdState = AdState.COOLDOWN;
    Future.delayed(Duration(seconds: 6), () {
      _appOpenAdState = AdState.IDLE;
      _appOpenAd = null;
      ad.dispose();
    });
  }

  void _onAppOpenAdTimerExecuted() async {
    if (_config.appOpenAdLoadType == FlutterAutoAdmobLoadType.preload) {
      var defCallback = _defaultCallback<AppOpenAd>((state, ad) {
        if (state.isDismissed) {
          resetCoolDownNonePreloadedAppOpenAd(ad);
        } else if (state.isFailed) {
          resetCoolDownNonePreloadedAppOpenAd(ad);
        }
      });
      _appOpenAd ??= await _requestAppOpenAd(callback: defCallback);
      if (_appOpenAd != null) {
        debugPrint(
          "[APP OPEN] Preloaded APP OPEN ad is ready to show in the next 15 seconds.",
        );
        Future.delayed(const Duration(seconds: 15), () {
          onAppOpenAdLoaded?.call();
        });
      }
    } else {
      _appOpenAdState = AdState.IDLE;
      onAppOpenAdLoaded?.call();
    }
  }

  Future<AppOpenAd?> _requestAppOpenAd({
    FullScreenContentCallback<AppOpenAd>? callback,
  }) async {
    Completer<AppOpenAd?> completer = Completer<AppOpenAd?>();
    _appOpenAdState = AdState.REQUESTING;
    AppOpenAd.load(
      adUnitId: _config.appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          var defCallback = _defaultCallback<AppOpenAd>(
            (state, ad) => _appOpenAdState = state,
          );
          ad.fullScreenContentCallback = callback ?? defCallback;
          completer.done(ad);
          _appOpenAdState = AdState.LOADED;
        },
        onAdFailedToLoad: (error) {
          completer.done();
          _appOpenAdState = AdState.FAILED_TO_LOAD;
        },
      ),
    );
    return completer.future;
  }

  // End of App Open Ad Section
}
