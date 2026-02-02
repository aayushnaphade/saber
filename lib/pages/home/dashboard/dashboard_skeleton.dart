import 'package:flutter/material.dart';
import 'package:saber/components/loading/skeleton_loader.dart';
import 'package:saber/design_system/spacing.dart';
import 'package:saber/design_system/radius.dart';

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSkeleton(context),
          const SizedBox(height: AppSpacing.xl),
          if (width >= 1100)
            _buildDesktopLayoutSkeleton(context)
          else
            _buildMobileLayoutSkeleton(context),
        ],
      ),
    );
  }

  Widget _buildMobileLayoutSkeleton(BuildContext context) {
    return Column(
      children: [
        _buildLiveQueueCardSkeleton(context),
        const SizedBox(height: AppSpacing.lg),
        _buildStatsGridSkeleton(context),
        const SizedBox(height: AppSpacing.lg),
        _buildQueueListSkeleton(context),
      ],
    );
  }

  Widget _buildDesktopLayoutSkeleton(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildLiveQueueCardSkeleton(context),
              const SizedBox(height: AppSpacing.lg),
              _buildQueueListSkeleton(context),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(flex: 2, child: _buildStatsGridSkeleton(context)),
      ],
    );
  }

  Widget _buildHeaderSkeleton(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Leading Avatar/Logo
        const SkeletonLoader(
          width: 56,
          height: 56,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        const SizedBox(width: AppSpacing.md),

        // Middle Text Content
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLoader(width: 100, height: 12), // Clinic Name/Date
              SizedBox(height: 8),
              SkeletonLoader(width: 160, height: 24), // Greeting
              SizedBox(height: 8),
              SkeletonLoader(width: 200, height: 32), // Doctor Name
            ],
          ),
        ),

        // Trailing AI Pulse Status
        const SizedBox(width: AppSpacing.md),
        SkeletonLoader(
          width: 80,
          height: 32,
          borderRadius: BorderRadius.circular(20),
        ),
      ],
    );
  }

  Widget _buildLiveQueueCardSkeleton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              SkeletonLoader.circle(size: 8),
              SizedBox(width: 8),
              SkeletonLoader(width: 80, height: 12),
            ],
          ),
          const SizedBox(height: 24),
          const SkeletonLoader(width: 220, height: 32),
          const SizedBox(height: 12),
          const SkeletonLoader(width: 180, height: 16),
          const Spacer(),
          Row(
            children: [
              SkeletonLoader(
                width: 120,
                height: 44,
                borderRadius: BorderRadius.circular(22),
              ),
              const SizedBox(width: 12),
              SkeletonLoader(
                width: 120,
                height: 44,
                borderRadius: BorderRadius.circular(22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGridSkeleton(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildSingleStatSkeleton(context)),
        const SizedBox(width: 12),
        Expanded(child: _buildSingleStatSkeleton(context)),
        const SizedBox(width: 12),
        Expanded(child: _buildSingleStatSkeleton(context)),
      ],
    );
  }

  Widget _buildSingleStatSkeleton(BuildContext context) {
    return Container(
      height: 130,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.xxlRadius,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SkeletonLoader(
                width: 32,
                height: 32,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              Flexible(
                child: SkeletonLoader(
                  width: 40,
                  height: 18,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
          const Spacer(),
          const SkeletonLoader(width: 60, height: 24),
          const SizedBox(height: 8),
          const SkeletonLoader(width: 80, height: 14),
        ],
      ),
    );
  }

  Widget _buildQueueListSkeleton(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SkeletonLoader(width: 150, height: 28),
            SkeletonLoader(
              width: 80,
              height: 24,
              borderRadius: BorderRadius.circular(12),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Improved list skeleton to look like actual patient cards
        ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.all(0),
          itemCount: 3,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              children: [
                SkeletonLoader.circle(size: 44),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(width: 140, height: 18),
                      SizedBox(height: 6),
                      SkeletonLoader(width: 90, height: 12),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                SkeletonLoader(
                  width: 70,
                  height: 28,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
