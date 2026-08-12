import 'package:flutter/widgets.dart';

import '../vitrine_page_layout.dart';

class VitrinePageSections extends StatelessWidget {
  const VitrinePageSections({
    super.key,
    required this.layout,
    required this.builder,
  });

  final VitrinePageLayout layout;
  final Widget Function(BuildContext context, VitrinePageSection section)
  builder;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final section in layout.sections)
        if (section.visible) builder(context, section),
    ],
  );
}
