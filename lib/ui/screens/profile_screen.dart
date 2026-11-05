import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/logo.dart';
import '../../services/app_controller.dart';
import '../sheets/session_sheets.dart';
import '../widgets/app_page.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final employee = controller.employee;
    if (employee == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.mint));
    }
    final report = controller.permissions;
    final issues = report?.issues ?? const <String>[];
    final attendance = controller.attendance;

    return TabBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TabHeader(
            eyebrow: 'FIELD IDENTITY',
            title: 'Your field\nprofile.',
            subtitle: 'Local session · Phase 1',
          ),
          GlassPanel(
            radius: 28,
            padding: const EdgeInsets.all(18),
            glowColor: AppColors.mint,
            child: Column(
              children: [
                Row(
                  children: [
                    AppAvatar(
                      name: employee.name,
                      seed: employee.avatarSeed,
                      size: 66,
                      showStatus: true,
                      statusColor: controller.isTrackingLive ? AppColors.mint : AppColors.textDim,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee.name,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            employee.designation,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              StatusPill(label: employee.code, color: AppColors.mint, dense: true, icon: Icons.badge_outlined),
                              StatusPill(
                                label: controller.isTrackingLive ? 'ON DUTY' : 'OFF DUTY',
                                color: controller.isTrackingLive ? AppColors.cyan : AppColors.textMuted,
                                dense: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ProfileStat(
                          label: 'TODAY',
                          value: attendance == null ? 'Off duty' : Fmt.clock(attendance.workedDuration),
                          accent: attendance == null ? AppColors.textMuted : AppColors.mint,
                        ),
                      ),
                      Container(width: 1, height: 30, color: AppColors.line),
                      Expanded(
                        child: _ProfileStat(
                          label: 'SITES',
                          value: '${controller.todayStats.siteVisits}',
                          accent: AppColors.violet,
                        ),
                      ),
                      Container(width: 1, height: 30, color: AppColors.line),
                      Expanded(
                        child: _ProfileStat(
                          label: 'QUEUE',
                          value: '${controller.pendingSync}',
                          accent: controller.pendingSync > 0 ? AppColors.amber : AppColors.mint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionHeading(title: 'Employee record', subtitle: 'Seeded locally for the Phase 1 demo'),
          GlassPanel(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.badge_outlined,
                  title: employee.code,
                  subtitle: 'Employee identifier',
                  accent: AppColors.mint,
                ),
                const Divider(height: 1),
                InfoRow(
                  icon: Icons.mail_outline_rounded,
                  title: employee.email,
                  subtitle: 'Work email',
                  accent: AppColors.cyan,
                ),
                const Divider(height: 1),
                InfoRow(
                  icon: Icons.call_outlined,
                  title: employee.phone,
                  subtitle: 'Contact number',
                  accent: AppColors.violet,
                ),
                const Divider(height: 1),
                InfoRow(
                  icon: Icons.workspaces_outlined,
                  title: employee.department,
                  subtitle: 'Department · joined ${employee.joinedAt}',
                  accent: AppColors.amber,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionHeading(
            title: 'Permissions',
            subtitle: issues.isEmpty ? 'All field permissions are ready' : '${issues.length} item(s) need attention',
            action: 'Manage',
            onAction: () => showPermissionSheet(context),
          ),
          GlassPanel(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      issues.isEmpty ? Icons.verified_rounded : Icons.warning_amber_rounded,
                      size: 19,
                      color: issues.isEmpty ? AppColors.mint : AppColors.amber,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        issues.isEmpty
                            ? 'Location, background tracking and notifications are granted.'
                            : issues.first,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlineButton(
                        label: 'Request',
                        icon: Icons.lock_open_rounded,
                        height: 42,
                        color: AppColors.mint,
                        onPressed: controller.requestPermissions,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlineButton(
                        label: 'Settings',
                        icon: Icons.settings_outlined,
                        height: 42,
                        color: AppColors.textMuted,
                        onPressed: controller.openAppSettingsPage,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionHeading(title: 'App settings', subtitle: 'Device-level controls'),
          GlassPanel(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.gps_fixed_rounded,
                  title: 'Location settings',
                  subtitle: 'GPS and precise location',
                  accent: AppColors.cyan,
                  onTap: controller.openLocationSettingsPage,
                  trailing: const Icon(Icons.chevron_right_rounded, size: 17, color: AppColors.textDim),
                ),
                const Divider(height: 1),
                InfoRow(
                  icon: Icons.settings_applications_rounded,
                  title: 'App permissions',
                  subtitle: 'Background location and notifications',
                  accent: AppColors.violet,
                  onTap: controller.openAppSettingsPage,
                  trailing: const Icon(Icons.chevron_right_rounded, size: 17, color: AppColors.textDim),
                ),
                const Divider(height: 1),
                InfoRow(
                  icon: Icons.cloud_off_rounded,
                  title: 'Local storage',
                  subtitle: '${controller.pendingSync} records pending a future sync',
                  accent: AppColors.mint,
                  trailing: StatusPill(
                    label: 'OFFLINE',
                    color: AppColors.cyan,
                    dense: true,
                  ),
                ),
                const Divider(height: 1),
                InfoRow(
                  icon: Icons.memory_rounded,
                  title: controller.simulation ? 'Simulation mode' : 'Native tracking',
                  subtitle: controller.simulation
                      ? 'Desktop demo engine with a compressed route'
                      : 'Kotlin service / Swift Core Location',
                  accent: AppColors.amber,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          GlassPanel(
            radius: 22,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const AppLogo(size: 38, glow: false),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        AppConfig.appName,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${AppConfig.version} · ${AppConfig.appTagline}',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textDim),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlineButton(
            label: 'Log out of PropCare',
            icon: Icons.logout_rounded,
            color: AppColors.coral,
            onPressed: () => showLogoutSheet(context),
          ),
          const SizedBox(height: 9),
          const Center(
            child: Text(
              'Logout is allowed at any time. It never records an office check-out.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textDim),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value, required this.accent});

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: accent,
          ),
        ),
        const SizedBox(height: 3),
        MonoLabel(label, size: 7.5, letterSpacing: 1.2),
      ],
    );
  }
}
