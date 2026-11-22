import 'dart:async';

import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../util/log_service.dart';

/// App-wide cart. Lives for the whole session.
///
/// NOTE: the starter cart is purely local — it does not reserve stock on the
/// backend. See the "Reservations" feature task in PROBLEM.md.
class CartService extends GetxService {
  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;
  final Map<int, Timer> _flashSaleExpiryTimers = {};

  bool add(DealModel deal) {
    if (deal.isFlashSaleExpired) {
      expireFlashSale(deal.id);
      return false;
    }

    final existing = items.firstWhereOrNull((i) => i.deal.id == deal.id);
    if (existing != null) {
      if (existing.quantity >= deal.quantityLeft) {
        LogService.log('cart: cannot add more of deal ${deal.id}');
        return false;
      }
      existing.quantity++;
      items.refresh();
    } else {
      items.add(CartItemModel(deal: deal));
    }
    final isStillAvailable = _scheduleFlashSaleExpiry(deal);
    _recount();
    return isStillAvailable;
  }

  void decrement(int dealId) {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null) return;
    existing.quantity--;
    if (existing.quantity <= 0) {
      items.removeWhere((i) => i.deal.id == dealId);
      _cancelFlashSaleExpiry(dealId);
    } else {
      items.refresh();
    }
    _recount();
  }

  void remove(int dealId) {
    items.removeWhere((i) => i.deal.id == dealId);
    _cancelFlashSaleExpiry(dealId);
    _recount();
  }

  void clear() {
    items.clear();
    for (final timer in _flashSaleExpiryTimers.values) {
      timer.cancel();
    }
    _flashSaleExpiryTimers.clear();
    _recount();
  }

  num get total => items.fold(0, (sum, i) => sum + i.lineTotal);

  void expireFlashSale(int dealId) {
    final expiredItem =
        items.firstWhereOrNull((item) => item.deal.id == dealId);
    _cancelFlashSaleExpiry(dealId);
    if (expiredItem == null) return;

    items.removeWhere((item) => item.deal.id == dealId);
    _recount();
    Get.snackbar(
      'Flash sale expired',
      '${expiredItem.deal.name} was removed from your bag.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }

  bool _scheduleFlashSaleExpiry(DealModel deal) {
    final endsAt = deal.flashSaleEndsAt;
    if (endsAt == null || _flashSaleExpiryTimers.containsKey(deal.id)) {
      return true;
    }

    final remaining = endsAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      expireFlashSale(deal.id);
      return false;
    }
    _flashSaleExpiryTimers[deal.id] = Timer(
      remaining,
      () => expireFlashSale(deal.id),
    );
    return true;
  }

  void _cancelFlashSaleExpiry(int dealId) {
    _flashSaleExpiryTimers.remove(dealId)?.cancel();
  }

  void _recount() {
    itemCount.value = items.fold(0, (sum, i) => sum + i.quantity);
  }

  @override
  void onClose() {
    for (final timer in _flashSaleExpiryTimers.values) {
      timer.cancel();
    }
    _flashSaleExpiryTimers.clear();
    super.onClose();
  }
}
