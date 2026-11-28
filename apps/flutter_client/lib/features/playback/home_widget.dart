import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playback.dart';

/// Android home screen player (decision 0013, proposal 7; PlayerWidget.kt):
/// the track playing goes to the widget, its buttons come back to the
/// queue. The playing state is the player service's own.
abstract interface class HomeWidgetApi {
  Future<void> update({String? title, String? artist, String? art});

  /// toggle, next, previous.
  Stream<String> get buttons;
}

class AndroidHomeWidgetApi implements HomeWidgetApi {
  AndroidHomeWidgetApi() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'button' && call.arguments is String) {
        _buttons.add(call.arguments as String);
      }
    });
  }

  static const _channel = MethodChannel('org.miarina.media/home_widget');
  final _buttons = StreamController<String>.broadcast();

  @override
  Future<void> update({String? title, String? artist, String? art}) async {
    try {
      await _channel.invokeMethod<void>('update', {
        'title': title,
        'artist': artist,
        'art': art,
      });
    } catch (_) {
      // No widget side (an older build): nothing to show.
    }
  }

  @override
  Stream<String> get buttons => _buttons.stream;
}

final homeWidgetApiProvider = Provider<HomeWidgetApi?>(
  (_) => Platform.isAndroid ? AndroidHomeWidgetApi() : null,
);

/// Keeps the widget in step with the queue; watched by the app root.
final homeWidgetProvider = Provider<void>((ref) {
  final api = ref.watch(homeWidgetApiProvider);
  if (api == null) return;
  String? sent;
  void sync(QueueEntry? entry) {
    final key = entry == null
        ? ''
        : '${entry.title}|${entry.subtitle}|${entry.artwork}';
    if (key == sent) return;
    sent = key;
    unawaited(
      api.update(
        title: entry?.title,
        artist: entry?.subtitle,
        art: entry?.artwork,
      ),
    );
  }

  ref.listen(
    queueProvider.select((q) => q.current),
    (_, entry) => sync(entry),
    fireImmediately: true,
  );
  final buttons = api.buttons.listen((b) async {
    final queue = ref.read(queueProvider.notifier);
    switch (b) {
      case 'toggle':
        await queue.togglePlay();
      case 'next':
        await queue.next();
      case 'previous':
        await queue.previous();
    }
  });
  ref.onDispose(buttons.cancel);
});
