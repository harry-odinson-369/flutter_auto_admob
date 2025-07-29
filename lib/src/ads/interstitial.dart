import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_auto_admob/src/ads/app_open.dart';
import 'package:flutter_auto_admob/src/config.dart';
import 'package:flutter_auto_admob/src/extension.dart';
import 'package:flutter_auto_admob/src/flutter_auto_admob.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class InterstitialAdApi {
  InterstitialAdApi._();

  FlutterAutoAdmobConfig _config = FlutterAutoAdmobConfig();

  static final InterstitialAdApi _instance = InterstitialAdApi._();
  static InterstitialAdApi get instance => _instance;

  final ValueNotifier<AdState> _state = ValueNotifier(AdState.IDLE);
  ValueNotifier<AdState> get state => _state;

  Timer? _timer;

  InterstitialAd? _ad;

  Function? onLoadedCallback;

  void configure(FlutterAutoAdmobConfig config) {
    _config = config;
    _state.value = AdState.COOLDOWN;
    _timer ??= Timer.periodic(
      _config.calculatedInterstitialAdCooldown,
      (t) => _onTimerExecuted(),
    );
  }

  void cooldown([Duration? duration]) async {
    AdState backupState = AdState.values.firstWhere((e) => e == _state.value);
    _state.value = AdState.COOLDOWN;
    _timer?.cancel();
    _timer = null;
    var dur = duration ?? _config.calculatedInterstitialAdCooldown;
    Future.delayed(dur, () {
      _state.value = backupState;
      _timer = Timer.periodic(
        _config.calculatedInterstitialAdCooldown,
        (t) => _onTimerExecuted(),
      );
    });
  }

  /// [useAsync] set to true if you want to wait until user close the ad.
  /// [force] set to true to force the ad request and show immediately as possible.
  Future<bool> show({bool useAsync = false, bool force = false}) async {
    if (!_state.value.isCoolingDown &&
        !AppOpenAdApi.instance.state.value.isShowing) {
      Completer<bool> completer = Completer<bool>();
      if (_config.interstitialAdLoadType == FlutterAutoAdmobLoadType.none ||
          force) {
        _state.addListener(() {
          if (_state.value.isDismissed) {
            completer.done(true);
            _resetCoolDownNonePreloadedAd();
          } else if (_state.value.isFailed) {
            completer.done(false);
            _resetCoolDownNonePreloadedAd();
          }
        });
        _ad = await _requestAd();
        _ad?.show();
      } else if (_config.interstitialAdLoadType ==
          FlutterAutoAdmobLoadType.preload) {
        _ad?.show();
        while (true) {
          if (_state.value.isDismissed) {
            completer.done(true);
            break;
          } else if (_state.value.isFailed) {
            completer.done(false);
            break;
          }
          await Future.delayed(Duration(seconds: 1));
        }
      }

      if (useAsync) return completer.future;
      return true;
    } else {
      debugPrint("[INTERSTITIAL] The INTERSTITIAL ad is in cooldown!");
      return false;
    }
  }

  void _resetCoolDownNonePreloadedAd() {
    _state.value = AdState.COOLDOWN;
    Future.delayed(Duration(seconds: 6), () {
      _state.value = AdState.IDLE;
      _state.removeListener(_stateListener);
      _ad = null;
      _ad?.dispose();
    });
  }

  void _stateListener() {
    if (_state.value.isDismissed) {
      _resetCoolDownNonePreloadedAd();
    } else if (_state.value.isFailed) {
      _resetCoolDownNonePreloadedAd();
    }
  }

  void _onTimerExecuted() async {
    if (_config.interstitialAdLoadType == FlutterAutoAdmobLoadType.preload) {
      _state.addListener(_stateListener);
      _ad ??= await _requestAd();
      if (_ad != null) {
        debugPrint(
          "[INTERSTITIAL] Preloaded INTERSTITIAL ad is ready to show in the next 15 seconds.",
        );
        Future.delayed(const Duration(seconds: 15), () {
          onLoadedCallback?.call();
        });
      }
    } else {
      _state.value = AdState.IDLE;
      onLoadedCallback?.call();
    }
  }

  Future<InterstitialAd?> _requestAd() async {
    Completer<InterstitialAd?> completer = Completer<InterstitialAd?>();
    _state.value = AdState.REQUESTING;
    InterstitialAd.load(
      adUnitId: _config.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = _fullscreenCallback;
          completer.done(ad);
          _state.value = AdState.LOADED;
        },
        onAdFailedToLoad: (error) {
          completer.done();
          _state.value = AdState.FAILED_TO_LOAD;
        },
      ),
    );
    return completer.future;
  }

  FullScreenContentCallback<InterstitialAd> get _fullscreenCallback {
    return FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (ad) {
        _state.value = AdState.SHOWING;
      },
      onAdDismissedFullScreenContent: (ad) {
        _state.value = AdState.DISMISSED;
        AppOpenAdApi.instance.cooldown();
      },
      onAdClicked: (ad) {
        _state.value = AdState.CLICKED;
      },
      onAdImpression: (ad) {
        _state.value = AdState.IMPRESSION;
      },
      onAdFailedToShowFullScreenContent: (ad, err1) {
        _state.value = AdState.FAILED_TO_SHOW;
      },
    );
  }
}
