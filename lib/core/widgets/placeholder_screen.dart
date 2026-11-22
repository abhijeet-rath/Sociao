import 'package:material_ui/material_ui.dart';

import 'empty_state.dart';

/// Temporary screen body used until a feature is implemented in its phase.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.icon,
    this.actions,
  });

  final String title;
  final IconData? icon;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: EmptyState(
        icon: icon ?? Icons.construction_outlined,
        message: '$title is coming soon',
      ),
    );
  }
}
