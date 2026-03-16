import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/recipe_suggestion.dart';

class AiSuggestionCarousel extends StatefulWidget {
  final List<RecipeSuggestion> suggestions;
  final Duration autoScrollDuration;
  final Function(RecipeSuggestion)? onViewRecipeTap;

  const AiSuggestionCarousel({
    super.key,
    required this.suggestions,
    this.autoScrollDuration = const Duration(seconds: 7),
    this.onViewRecipeTap,
  });

  @override
  State<AiSuggestionCarousel> createState() => _AiSuggestionCarouselState();
}

class _AiSuggestionCarouselState extends State<AiSuggestionCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    // Vừa auto-scroll nhẹ nhàng, vừa cho phép người dùng vuốt tay
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    if (widget.suggestions.length <= 1) return;

    _autoScrollTimer = Timer.periodic(widget.autoScrollDuration, (_) {
      if (!mounted) return;

      final nextPage = (_currentPage + 1) % widget.suggestions.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Gợi ý hôm nay',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Carousel
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              // Khi người dùng vuốt, cập nhật trang hiện tại và reset timer auto-scroll
              _autoScrollTimer?.cancel();
              setState(() {
                _currentPage = index;
              });
              _startAutoScroll();
            },
            itemCount: widget.suggestions.length,
            itemBuilder: (context, index) {
              return _buildSuggestionCard(widget.suggestions[index]);
            },
          ),
        ),

        const SizedBox(height: 12),

        // Page indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.suggestions.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? AppColors.primary
                    : const Color.fromRGBO(156, 163, 175, 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionCard(RecipeSuggestion suggestion) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            suggestion.imageUrl != null
                ? Image.network(
                    suggestion.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderBg(),
                  )
                : _buildPlaceholderBg(),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color.fromRGBO(0, 0, 0, 0.7),
                  ],
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge
                  // Badge
                  Row(
                    children: [
                      if (suggestion.ingredientsExpiringCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            suggestion.expiringBadgeText,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (suggestion.matchPercentage > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${suggestion.matchPercentage}% Hợp',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF3B82F6,
                              ), // Blue for discovery
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Khám phá',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const Spacer(),

                  // Recipe name
                  Text(
                    suggestion.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Description
                  Text(
                    suggestion.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color.fromRGBO(255, 255, 255, 0.9),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // View recipe button
                  GestureDetector(
                    onTap: () => widget.onViewRecipeTap?.call(suggestion),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Text(
                        'Xem công thức',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderBg() {
    return Container(
      color: AppColors.primaryLight,
      child: const Center(
        child: Icon(Icons.restaurant, size: 60, color: AppColors.primary),
      ),
    );
  }
}
