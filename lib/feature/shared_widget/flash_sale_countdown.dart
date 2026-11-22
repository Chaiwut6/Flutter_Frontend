import 'dart:async';

import 'package:flutter/material.dart';

class FlashSaleCountdown extends StatefulWidget {
  final DateTime endsAt;
  final TextStyle? style;
  final VoidCallback? onExpired;

  const FlashSaleCountdown({
    super.key,
    required this.endsAt,
    this.style,
    this.onExpired,
  });

  @override
  State<FlashSaleCountdown> createState() => _FlashSaleCountdownState();
}

class _FlashSaleCountdownState extends State<FlashSaleCountdown> {
  late final ValueNotifier<String> _text;
  Timer? _timer;
  bool _expirationNotified = false;

  @override
  void initState() {
    super.initState();
    _text = ValueNotifier(_formatRemaining());
    _updateCountdown();
  }

  @override
  void didUpdateWidget(covariant FlashSaleCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) {
      _timer?.cancel();
      _timer = null;
      _expirationNotified = false;
      _updateCountdown();
    }
  }

  void _updateCountdown() {
    final remaining = widget.endsAt.difference(DateTime.now());
    final text = _format(remaining);
    if (_text.value != text) _text.value = text;

    if (remaining <= Duration.zero) {
      _timer?.cancel();
      _timer = null;
      _notifyExpired();
    } else {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        _updateCountdown();
      });
    }
  }

  String _formatRemaining() =>
      _format(widget.endsAt.difference(DateTime.now()));

  String _format(Duration remaining) {
    if (remaining <= Duration.zero) return 'Expired';

    final seconds = (remaining.inMilliseconds / 1000).ceil();
    final secondPart = (seconds % 60).toString().padLeft(2, '0');
    if (remaining >= const Duration(hours: 1)) {
      final hours = (seconds ~/ 3600).toString().padLeft(2, '0');
      final minutes = ((seconds ~/ 60) % 60).toString().padLeft(2, '0');
      return '$hours:$minutes:$secondPart';
    }
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    return '$minutes:$secondPart';
  }

  void _notifyExpired() {
    if (_expirationNotified) return;
    _expirationNotified = true;

    final endsAt = widget.endsAt;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.endsAt != endsAt ||
          DateTime.now().isBefore(endsAt)) {
        return;
      }
      widget.onExpired?.call();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: _text,
      builder: (context, text, _) => Text(text, style: widget.style),
    );
  }
}
