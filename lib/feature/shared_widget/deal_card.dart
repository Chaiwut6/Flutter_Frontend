import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app_config.dart';
import '../../model/deal_model.dart';
import '../../routes/routes.dart';
import '../../service/cart_service.dart';
import 'flash_sale_countdown.dart';
import 'the_network_image.dart';

/// Deal card used in the home feed and search results.
class DealCard extends StatefulWidget {
  final DealModel deal;
  final String source;

  const DealCard({super.key, required this.deal, this.source = 'home'});

  @override
  State<DealCard> createState() => _DealCardState();
}

class _DealCardState extends State<DealCard> {
  late bool _expired;

  @override
  void initState() {
    super.initState();
    _expired = widget.deal.isFlashSaleExpired;
  }

  @override
  void didUpdateWidget(covariant DealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deal.id != widget.deal.id ||
        oldWidget.deal.flashSaleEndsAt != widget.deal.flashSaleEndsAt) {
      _expired = widget.deal.isFlashSaleExpired;
    }
  }

  void _onFlashSaleExpired() {
    Get.find<CartService>().expireFlashSale(widget.deal.id);
    if (mounted && !_expired) setState(() => _expired = true);
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    final expired = deal.isFlashSale && (_expired || deal.isFlashSaleExpired);

    return Opacity(
      opacity: expired ? 0.55 : 1,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        clipBehavior: Clip.antiAlias,
        color: Colors.white,
        elevation: 0.5,
        child: InkWell(
          onTap: expired
              ? null
              : () => Get.toNamed(
                    Routes.dealRoute(deal.id, source: widget.source),
                    arguments: deal,
                  ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  TheNetworkImage(
                      url: deal.imageUrl, height: 160, width: double.infinity),
                  if (deal.isFlashSale)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: expired
                            ? const Text(
                                'Expired',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'FLASH SALE',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 6),
                                  FlashSaleCountdown(
                                    endsAt: deal.flashSaleEndsAt!,
                                    onExpired: _onFlashSaleExpired,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${deal.quantityLeft} left',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(deal.storeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('Pick up ${deal.pickupWindow.label}',
                            style: TextStyle(
                                fontSize: 12.5, color: Colors.grey.shade700)),
                        const Spacer(),
                        if (deal.rating != null) ...[
                          const Icon(Icons.star_rounded,
                              size: 15, color: Colors.amber),
                          Text(deal.rating!.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 12.5)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('฿${deal.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppConfig.primaryGreen)),
                        const SizedBox(width: 6),
                        Text('฿${deal.originalPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                                decoration: TextDecoration.lineThrough)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                AppConfig.primaryGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('-${deal.discountPercent}%',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppConfig.primaryGreen)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
