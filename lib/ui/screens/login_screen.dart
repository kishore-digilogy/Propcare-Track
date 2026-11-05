import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/background.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/logo.dart';
import '../../services/app_controller.dart';
import '../widgets/app_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _code = TextEditingController(text: 'EMP-1042');
  final _password = TextEditingController(text: AppConfig.demoPassword);
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_error != null) setState(() => _error = null);
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    final controller = context.read<AppController>();
    try {
      await controller.login(_code.text, _password.text);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Sign-in failed. $error');
    }
  }

  void _fillDemo(DemoEmployee employee) {
    HapticFeedback.selectionClick();
    setState(() {
      _code.text = employee.code;
      _password.text = AppConfig.demoPassword;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final busy = controller.busy;

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppLogo(size: 40),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PROPCARE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            'TRACK · FIELD OPS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 7.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2.2,
                              color: AppColors.mint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(label: 'PHASE 1', color: AppColors.violet, icon: Icons.cloud_off_rounded, dense: true),
                  ],
                ),
                const SizedBox(height: 40),
                const MonoLabel('SECURE FIELD ACCESS', color: AppColors.mint),
                const SizedBox(height: 12),
                Text(
                  'Welcome back,\nfield crew.',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 42),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sign in to start the day. Attendance, route breadcrumbs and battery checkpoints are stored locally on this device.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 26),
                GlassPanel(
                  radius: 26,
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                  glowColor: AppColors.mint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MonoLabel('EMPLOYEE ID OR EMAIL'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _code,
                        enabled: !busy,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          letterSpacing: 0.8,
                          color: AppColors.text,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'EMP-1042',
                          prefixIcon: Icon(Icons.badge_outlined, size: 19, color: AppColors.textDim),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const MonoLabel('PASSWORD'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _password,
                        focusNode: _passwordFocus,
                        enabled: !busy,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          letterSpacing: 1.2,
                          color: AppColors.text,
                        ),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19, color: AppColors.textDim),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 19,
                              color: AppColors.textDim,
                            ),
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        child: _error == null
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: NoticeBanner(
                                  message: _error!,
                                  color: AppColors.coral,
                                  icon: Icons.error_outline_rounded,
                                  onDismiss: () => setState(() => _error = null),
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),
                      GradientButton(
                        label: busy ? 'Verifying identity…' : 'Sign in to the field',
                        icon: Icons.arrow_forward_rounded,
                        loading: busy,
                        onPressed: busy ? null : _submit,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 13, color: AppColors.textDim),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Demo password: ${AppConfig.demoPassword} · stored as a salted SHA-256 hash',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                height: 1.4,
                                color: AppColors.textDim,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    const MonoLabel('DEMO CREW'),
                    const SizedBox(width: 10),
                    Expanded(child: Container(height: 1, color: AppColors.line)),
                    const SizedBox(width: 10),
                    MonoLabel('TAP TO FILL', color: AppColors.textDim, size: 8),
                  ],
                ),
                const SizedBox(height: 12),
                for (final employee in AppConfig.demoEmployees) ...[
                  _DemoChip(
                    employee: employee,
                    selected: _code.text.trim().toUpperCase() == employee.code,
                    onTap: busy ? null : () => _fillDemo(employee),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: Container(height: 1, color: AppColors.line)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        AppConfig.version,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 8,
                          letterSpacing: 1.4,
                          color: AppColors.textDim,
                        ),
                      ),
                    ),
                    Expanded(child: Container(height: 1, color: AppColors.line)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoChip extends StatelessWidget {
  const _DemoChip({required this.employee, required this.selected, required this.onTap});

  final DemoEmployee employee;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final seed = employee.id.hashCode.isEven ? 'mint' : 'coral';
    return GlassPanel(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: selected ? AppColors.mint.withValues(alpha: 0.4) : null,
      onTap: onTap,
      child: Row(
        children: [
          AppAvatar(name: employee.name, size: 38, seed: seed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${employee.code} · ${employee.designation}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.mint)
          else
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textDim),
        ],
      ),
    );
  }
}
