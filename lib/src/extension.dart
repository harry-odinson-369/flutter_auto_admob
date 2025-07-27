import 'dart:async';

import 'package:flutter_auto_admob/src/flutter_auto_admob.dart';

extension CompleterExtension<T> on Completer<T> {
  void done([FutureOr<T>? result]) {
    if (!isCompleted) complete(result);
  }
}

extension AdStateExtension on AdState {

  /// Ad state that indicate the ad is actually dismissed. and not showing on fullscreen anymore.
  bool get isDismissed => this == AdState.DISMISSED;

  /// Ad state that indicate the ad is actually failed on both [AdState.FAILED_TO_LOAD] and [AdState.FAILED_TO_SHOW].
  bool get isFailed => this == AdState.FAILED_TO_LOAD || this == AdState.FAILED_TO_SHOW;

  /// Ad state that indicate the ad is actually currently showing the fullscreen ad content.
  bool get isShowing => this == AdState.SHOWING || this == AdState.IMPRESSION || this == AdState.CLICKED;

  bool get isCoolingDown => this == AdState.COOLDOWN;

}