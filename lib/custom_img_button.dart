import 'package:flutter/material.dart';

class ImgButton extends StatelessWidget {
  final Widget image;
  final Widget? child;
  final VoidCallback? onTap;
  final bool isSelected;

  const ImgButton({
    required this.image,
    this.child,
    this.onTap,
    this.isSelected = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);


    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(12),
              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            ),
            padding: EdgeInsets.all(0.5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8), // Clips the image to stay inside the border
              child: image
            )
          ),
          if (child != null) ...[
            const SizedBox(height: 6),
            child!,
          ],
        ],
      ),
    );
  }
}