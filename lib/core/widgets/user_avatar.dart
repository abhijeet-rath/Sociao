import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

/// Circular avatar with initials fallback and an optional coloured ring
/// (used by stories: blue = unseen, red = live).
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.url,
    this.name = '',
    this.size = 44,
    this.ringColor,
  });

  final String? url;
  final String name;
  final double size;
  final Color? ringColor;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    final image = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: (url == null || url!.isEmpty)
            ? fallback
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
    if (ringColor == null) return image;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor!, width: 2),
      ),
      child: image,
    );
  }
}
