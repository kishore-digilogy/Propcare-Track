import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/background.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/glass.dart';

/// Standard screen chrome: bright Paper Atlas backdrop, safe-area padding and
/// an optional scroll view.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.child,
    this.scroll = true,
    this.padding = const EdgeInsets.fromLTRB(20, 6, 20, 28),
    this.grid = false,
    this.aurora = false,
    this.bottomNavigationBar,
  });

  final Widget child;
  final bool scroll;
  final EdgeInsetsGeometry padding;
  final bool grid;
  final bool aurora;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final content = scroll
        ? SingleChildScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: padding,
            child: child,
          )
        : Padding(padding: padding, child: child);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: AppBackground(
        grid: grid,
        aurora: aurora,
        child: SafeArea(bottom: bottomNavigationBar == null, child: content),
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// Scrollable body for screens hosted inside [HomeShell]. Leaves room for the
/// floating bottom navigation rail.
class TabBody extends StatelessWidget {
  const TabBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 6, 20, 118),
    this.scroll = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    if (!scroll) return Padding(padding: padding, child: child);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: padding,
      child: child,
    );
  }
}

/// Back button + title used by pushed screens.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 18),
      child: Row(
        children: [
          if (showBack) ...[
            IconBubble(
              icon: Icons.arrow_back_rounded,
              size: 40,
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 13),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

/// Floating white navigation rail shown on every primary tab.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.index,
    required this.onChanged,
    this.items = _defaultItems,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<NavItem> items;

  static const List<NavItem> _defaultItems = [
    NavItem(Icons.calendar_today_rounded, Icons.calendar_today_rounded, 'Today'),
    NavItem(Icons.apartment_rounded, Icons.apartment_rounded, 'Sites'),
    NavItem(Icons.bar_chart_rounded, Icons.bar_chart_rounded, 'History'),
    NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 8, 14, bottom > 0 ? bottom - 2 : 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFEDF2F7), width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0C0F172A),
            blurRadius: 18,
            spreadRadius: -2,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _NavButton(
                item: items[i],
                selected: index == i,
                onTap: () => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}

class NavItem {
  const NavItem(this.icon, this.activeIcon, this.label);

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF0284C7);
    const inactiveColor = Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFE0EDFC) : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                selected ? item.activeIcon : item.icon,
                size: 20,
                color: selected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
                color: selected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact header used at the top of each primary tab.
class TabHeader extends StatelessWidget {
  const TabHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                MonoLabel(eyebrow, color: AppColors.mint.withValues(alpha: 0.8)),
                const SizedBox(height: 5),
                Text(title, style: Theme.of(context).textTheme.displaySmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Small inline banner for notices, warnings and errors.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.message,
    this.color = AppColors.mint,
    this.icon = Icons.info_outline_rounded,
    this.onDismiss,
    this.action,
  });

  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback? onDismiss;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 16, color: color.withValues(alpha: 0.7)),
            ),
        ],
      ),
    );
  }
}

class AppSnack {
  const AppSnack._();

  static void show(BuildContext context, String message, {bool error = false}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                color: error ? AppColors.coral : AppColors.mint,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: AppColors.surfaceHigh,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
          duration: const Duration(seconds: 4),
        ),
      );
  }
}

/// Shared bottom-sheet frame with the drag handle and rounded glass surface.
class SheetShell extends StatelessWidget {
  const SheetShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 10, 22, 26),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFD)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: AppColors.lineStrong)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 30,
            spreadRadius: -6,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => builder(context),
  );
}
