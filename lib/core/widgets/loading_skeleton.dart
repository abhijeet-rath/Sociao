import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Placeholder list shown while content loads. Pass a custom [itemBuilder]
/// that renders a dummy version of the real item; defaults to a generic card.
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({super.key, this.itemCount = 4, this.itemBuilder});

  final int itemCount;
  final IndexedWidgetBuilder? itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: itemBuilder ?? (_, _) => const _DefaultCard(),
      ),
    );
  }
}

class _DefaultCard extends StatelessWidget {
  const _DefaultCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: CircleAvatar(),
        title: Text('Placeholder username'),
        subtitle: Text('Placeholder text for a loading post card'),
      ),
    );
  }
}
