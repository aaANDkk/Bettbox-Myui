import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:flutter/material.dart';

class SubscriptionInfoView extends StatelessWidget {
  final SubscriptionInfo? subscriptionInfo;

  const SubscriptionInfoView({super.key, this.subscriptionInfo});

  @override
  Widget build(BuildContext context) {
    if (subscriptionInfo == null) {
      return const SizedBox.shrink();
    }

    final use = subscriptionInfo!.upload + subscriptionInfo!.download;
    final total = subscriptionInfo!.total;

    // No traffic info
    if (use == 0 && total == 0) {
      return const SizedBox.shrink();
    }

    // Show progress bar
    final progress = (total > 0 ? use / total : 0.0).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2.5),
          child: Container(
            height: 5,
            width: double.infinity,
            alignment: Alignment.centerLeft,
            color: context.colorScheme.primary.withValues(alpha: 0.15),
            child: FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: context.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
