import 'package:flutter/material.dart';
import 'theme.dart';

typedef ProviderTap = void Function(String providerId);

class ServerGrid extends StatelessWidget {
  const ServerGrid({
    super.key,
    required this.providers,
    required this.activeId,
    required this.onSelect,
    this.crossAxisCount = 5,
  });

  final List<({String id, String name})> providers;
  final String? activeId;
  final ProviderTap onSelect;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cols = width > 1200
        ? 5
        : width > 800
            ? 4
            : width > 500
                ? 3
                : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: providers.length,
      itemBuilder: (_, i) {
        final p = providers[i];
        final active = p.id == activeId;
        return Material(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => onSelect(p.id),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active ? AppTheme.primary : AppTheme.border,
                  width: active ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: active ? AppTheme.primary : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (active)
                        const Icon(Icons.check_circle, size: 16, color: AppTheme.primary),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    active ? '✓ Active' : 'Click to switch',
                    style: TextStyle(
                      fontSize: 11,
                      color: active ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
