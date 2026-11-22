import 'dart:async';

import 'package:get/get.dart';

import 'fake_api_service.dart';
import '../util/log_service.dart';

class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> properties;
  final DateTime at;

  AnalyticsEvent(this.name, this.properties) : at = DateTime.now();

  Map<String, dynamic> toJson() => {
        'name': name,
        'properties': properties,
        'at': at.toIso8601String(),
      };
}

/// In-memory analytics sink with batched deal-impression delivery.
class AnalyticsService extends GetxService {
  final FakeApiService api;

  AnalyticsService({required this.api});

  final events = <AnalyticsEvent>[].obs;
  final Set<int> _impressedDealIds = {};
  final List<AnalyticsEvent> _pendingImpressions = [];
  Timer? _batchTimer;
  bool _isSendingBatch = false;
  bool _flushRequested = false;

  void logEvent(String name, [Map<String, dynamic> properties = const {}]) {
    _recordEvent(name, properties);
  }

  bool recordDealImpression({
    required int dealId,
    required String source,
    required int position,
  }) {
    if (!_impressedDealIds.add(dealId)) return false;

    final event = _recordEvent('deal_impression', {
      'deal_id': dealId,
      'source': source,
      'position': position,
    });
    _pendingImpressions.add(event);

    if (_pendingImpressions.length >= 10) {
      _batchTimer?.cancel();
      _batchTimer = null;
      unawaited(_flushPendingImpressions());
    } else {
      _scheduleBatchTimer();
    }
    return true;
  }

  AnalyticsEvent _recordEvent(
    String name,
    Map<String, dynamic> properties,
  ) {
    final event = AnalyticsEvent(name, properties);
    events.add(event);
    LogService.log('analytics: $name $properties');
    return event;
  }

  void _scheduleBatchTimer() {
    if (_pendingImpressions.isEmpty || _batchTimer != null) return;
    _batchTimer = Timer(const Duration(seconds: 15), () {
      _batchTimer = null;
      unawaited(_flushPendingImpressions());
    });
  }

  Future<void> _flushPendingImpressions() async {
    if (_pendingImpressions.isEmpty) return;
    if (_isSendingBatch) {
      _flushRequested = true;
      return;
    }

    _batchTimer?.cancel();
    _batchTimer = null;
    final batch = _pendingImpressions.take(10).toList();
    _pendingImpressions.removeRange(0, batch.length);
    _isSendingBatch = true;
    var sent = false;
    try {
      await api.sendAnalyticsBatch(
        batch.map((event) => event.toJson()).toList(),
      );
      sent = true;
    } catch (e) {
      _pendingImpressions.insertAll(0, batch);
      LogService.error('analytics batch send failed', e);
    } finally {
      _isSendingBatch = false;
      if (_pendingImpressions.isNotEmpty) {
        final shouldFlushImmediately =
            sent && (_flushRequested || _pendingImpressions.length >= 10);
        _flushRequested = false;
        if (shouldFlushImmediately) {
          unawaited(_flushPendingImpressions());
        } else {
          _scheduleBatchTimer();
        }
      } else {
        _flushRequested = false;
      }
    }
  }

  @override
  void onClose() {
    _batchTimer?.cancel();
    super.onClose();
  }
}
