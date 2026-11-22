import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../service/analytics_service.dart';

class DealImpressionTracker extends StatefulWidget {
  final int dealId;
  final String source;
  final int position;
  final Widget child;

  const DealImpressionTracker({
    super.key,
    required this.dealId,
    required this.source,
    required this.position,
    required this.child,
  });

  @override
  State<DealImpressionTracker> createState() => _DealImpressionTrackerState();
}

class _DealImpressionTrackerState extends State<DealImpressionTracker> {
  Timer? _visibilityTimer;
  Key _detectorKey = UniqueKey();
  bool _isHalfVisible = false;
  bool _impressionSent = false;

  @override
  void didUpdateWidget(covariant DealImpressionTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dealId != widget.dealId ||
        oldWidget.source != widget.source ||
        oldWidget.position != widget.position) {
      _visibilityTimer?.cancel();
      _visibilityTimer = null;
      _detectorKey = UniqueKey();
      _isHalfVisible = false;
      _impressionSent = false;
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    _isHalfVisible = info.visibleFraction >= 0.5;
    if (!_isHalfVisible) {
      _visibilityTimer?.cancel();
      _visibilityTimer = null;
      return;
    }
    if (_impressionSent || _visibilityTimer != null) return;

    _visibilityTimer = Timer(const Duration(seconds: 1), _recordImpression);
  }

  void _recordImpression() {
    _visibilityTimer = null;
    if (!mounted || !_isHalfVisible || _impressionSent) return;

    _impressionSent = true;
    Get.find<AnalyticsService>().recordDealImpression(
      dealId: widget.dealId,
      source: widget.source,
      position: widget.position,
    );
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: _detectorKey,
      onVisibilityChanged: _onVisibilityChanged,
      child: widget.child,
    );
  }
}
