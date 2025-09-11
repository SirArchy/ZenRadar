import 'package:flutter/material.dart';

/// Enhanced skeleton loading widgets for better UX
class SkeletonLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Color? baseColor;
  final Color? highlightColor;
  final BorderRadius? borderRadius;

  const SkeletonLoading({
    super.key,
    required this.child,
    required this.isLoading,
    this.baseColor,
    this.highlightColor,
    this.borderRadius,
  });

  @override
  State<SkeletonLoading> createState() => _SkeletonLoadingState();
}

class _SkeletonLoadingState extends State<SkeletonLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    // Main shimmer animation
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOutSine),
      ),
    );

    // Subtle pulse animation for more dynamic effect
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    if (widget.isLoading) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(SkeletonLoading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _animationController.repeat();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseColor =
        widget.baseColor ??
        (isDark
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surfaceContainerHigh);

    final highlightColor =
        widget.highlightColor ??
        (isDark
            ? theme.colorScheme.surfaceContainerHighest.withAlpha(200)
            : theme.colorScheme.onSurface.withAlpha(40));

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [baseColor, highlightColor, baseColor],
                stops: [
                  (_animation.value - 0.3).clamp(0.0, 1.0),
                  _animation.value.clamp(0.0, 1.0),
                  (_animation.value + 0.3).clamp(0.0, 1.0),
                ],
                begin: const Alignment(-1.5, -0.5),
                end: const Alignment(1.5, 0.5),
              ),
              borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withAlpha(25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Enhanced skeleton card for product cards with grid layout design
class SkeletonProductCard extends StatelessWidget {
  const SkeletonProductCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top section: Image placeholder (takes about 50% of height)
          Expanded(
            flex: 3,
            child: SkeletonLoading(
              isLoading: true,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          // Middle section: Details (takes about 50% of height)
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top details
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product name (2 lines)
                      SkeletonLoading(
                        isLoading: true,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 14,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SkeletonLoading(
                        isLoading: true,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 14,
                          width: 120,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Website name
                      SkeletonLoading(
                        isLoading: true,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          height: 12,
                          width: 80,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Category badge
                      SkeletonLoading(
                        isLoading: true,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 18,
                          width: 60,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Stock status
                      SkeletonLoading(
                        isLoading: true,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          height: 11,
                          width: 65,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Last updated
                      SkeletonLoading(
                        isLoading: true,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          height: 10,
                          width: 90,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Bottom: Price
                  SkeletonLoading(
                    isLoading: true,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 16,
                      width: 70,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Enhanced skeleton for activity items with more detail
class SkeletonActivityItem extends StatelessWidget {
  const SkeletonActivityItem({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Status indicator
            SkeletonLoading(
              isLoading: true,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timestamp
                  SkeletonLoading(
                    isLoading: true,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 18,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Items scanned
                  SkeletonLoading(
                    isLoading: true,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 14,
                      width: 180,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Duration
                  SkeletonLoading(
                    isLoading: true,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 14,
                      width: 120,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Status message
                  SkeletonLoading(
                    isLoading: true,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 12,
                      width: 160,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Status badge
            SkeletonLoading(
              isLoading: true,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 85,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Enhanced skeleton for website overview cards
class SkeletonWebsiteCard extends StatelessWidget {
  const SkeletonWebsiteCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with icon and title
            Row(
              children: [
                SkeletonLoading(
                  isLoading: true,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Website name
                      SkeletonLoading(
                        isLoading: true,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 20,
                          width: 160,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Subtitle
                      SkeletonLoading(
                        isLoading: true,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          height: 14,
                          width: 120,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats section
            Row(
              children: [
                Expanded(child: _buildStatSkeleton(context)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatSkeleton(context)),
              ],
            ),

            const SizedBox(height: 16),

            // Second row of stats
            Row(
              children: [
                Expanded(child: _buildStatSkeleton(context)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatSkeleton(context)),
              ],
            ),

            const SizedBox(height: 20),

            // Chart placeholder
            SkeletonLoading(
              isLoading: true,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatSkeleton(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withAlpha(30)),
      ),
      child: Column(
        children: [
          SkeletonLoading(
            isLoading: true,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 24,
              width: 50,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SkeletonLoading(
            isLoading: true,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 14,
              width: 70,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Enhanced skeleton for stats header with better design
class SkeletonStatsHeader extends StatelessWidget {
  const SkeletonStatsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withAlpha(50)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header title
          SkeletonLoading(
            isLoading: true,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 28,
              width: 200,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(3, (index) {
              return _buildStatItemSkeleton(context);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItemSkeleton(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Icon
        SkeletonLoading(
          isLoading: true,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Value
        SkeletonLoading(
          isLoading: true,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 22,
            width: 45,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Label
        SkeletonLoading(
          isLoading: true,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 14,
            width: 65,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }
}
