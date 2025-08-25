import 'package:flutter/material.dart';

/// Skeleton loading widgets for better UX
class SkeletonLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonLoading({
    super.key,
    required this.child,
    required this.isLoading,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<SkeletonLoading> createState() => _SkeletonLoadingState();
}

class _SkeletonLoadingState extends State<SkeletonLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
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
    final baseColor = widget.baseColor ?? theme.colorScheme.surface;
    final highlightColor =
        widget.highlightColor ?? theme.colorScheme.onSurface.withAlpha(25);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [baseColor, highlightColor, baseColor],
              stops:
                  [
                    _animation.value - 0.3,
                    _animation.value,
                    _animation.value + 0.3,
                  ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
              begin: const Alignment(-1.0, 0.0),
              end: const Alignment(1.0, 0.0),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Skeleton card for product cards
class SkeletonProductCard extends StatelessWidget {
  const SkeletonProductCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonLoading(
                  isLoading: true,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoading(
                        isLoading: true,
                        child: Container(
                          height: 20,
                          width: double.infinity,
                          color: Colors.grey[300],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SkeletonLoading(
                        isLoading: true,
                        child: Container(
                          height: 16,
                          width: 120,
                          color: Colors.grey[300],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonLoading(
                  isLoading: true,
                  child: Container(
                    height: 24,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SkeletonLoading(
                  isLoading: true,
                  child: Container(
                    height: 20,
                    width: 60,
                    color: Colors.grey[300],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for activity items
class SkeletonActivityItem extends StatelessWidget {
  const SkeletonActivityItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SkeletonLoading(
              isLoading: true,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoading(
                    isLoading: true,
                    child: Container(
                      height: 18,
                      width: double.infinity,
                      color: Colors.grey[300],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SkeletonLoading(
                    isLoading: true,
                    child: Container(
                      height: 14,
                      width: 200,
                      color: Colors.grey[300],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SkeletonLoading(
                    isLoading: true,
                    child: Container(
                      height: 14,
                      width: 100,
                      color: Colors.grey[300],
                    ),
                  ),
                ],
              ),
            ),
            SkeletonLoading(
              isLoading: true,
              child: Container(
                width: 80,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for website overview cards
class SkeletonWebsiteCard extends StatelessWidget {
  const SkeletonWebsiteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonLoading(
                  isLoading: true,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoading(
                        isLoading: true,
                        child: Container(
                          height: 18,
                          width: 150,
                          color: Colors.grey[300],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SkeletonLoading(
                        isLoading: true,
                        child: Container(
                          height: 14,
                          width: 100,
                          color: Colors.grey[300],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SkeletonLoading(
                    isLoading: true,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SkeletonLoading(
                    isLoading: true,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for stats header
class SkeletonStatsHeader extends StatelessWidget {
  const SkeletonStatsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(50),
        ),
      ),
      child: Column(
        children: [
          SkeletonLoading(
            isLoading: true,
            child: Container(height: 24, width: 200, color: Colors.grey[300]),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(3, (index) {
              return Column(
                children: [
                  SkeletonLoading(
                    isLoading: true,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SkeletonLoading(
                    isLoading: true,
                    child: Container(
                      height: 20,
                      width: 40,
                      color: Colors.grey[300],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SkeletonLoading(
                    isLoading: true,
                    child: Container(
                      height: 14,
                      width: 60,
                      color: Colors.grey[300],
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
