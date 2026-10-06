import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppBottomBarItem {
  const AppBottomBarItem({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Uygulamanın alt sekme çubuğu.
///
/// Material 3 `NavigationBar` ile aynı görünür; ama o, Android'de kendi sistem
/// tıklama sesini kapatmaya izin vermediği için (ses ve titreşim tek noktadan,
/// Ayarlar'daki anahtarlarla yönetiliyor) burada elle yazıldı. Erişilebilirlik
/// için her sekme seçili/seçili değil bilgisiyle düğme olarak bildirilir.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<AppBottomBarItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgBottom,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _BarButton(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({required this.item, required this.selected, required this.onTap});

  final AppBottomBarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        enableFeedback: false, // ses/titreşim TapFeedbackScope'tan gelir
        onTap: onTap,
        splashColor: AppColors.primaryLight.withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 56,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary.withValues(alpha: 0.22) : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                size: 24,
                color: selected ? AppColors.primaryLight : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
