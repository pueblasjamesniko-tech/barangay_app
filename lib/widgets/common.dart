import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/config.dart';
import '../core/theme.dart';

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

void showMsg(BuildContext context, String text, {bool error = false}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    backgroundColor: error ? AppColors.red : AppColors.navy,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    duration: Duration(seconds: error ? 5 : 3),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    content: Row(
      children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  ));
}

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.isNegative || d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} hr${d.inHours == 1 ? '' : 's'} ago';
  if (d.inDays < 7) return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
  return DateFormat('MMM d, y').format(t);
}

/// Where a report is in its life. The API only stores a status text,
/// so unknown words are treated as "in progress".
enum ReportStage { pending, inProgress, resolved }

ReportStage stageOf(String status) {
  final s = status.trim().toLowerCase();
  if (s == 'resolved' || s == 'completed' || s == 'closed' || s == 'done') {
    return ReportStage.resolved;
  }
  if (s.isEmpty || s == 'pending' || s == 'new' || s == 'submitted') {
    return ReportStage.pending;
  }
  return ReportStage.inProgress;
}

BoxDecoration cardDecoration([double radius = 18]) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
            color: Color(0x0F0B2D6B), blurRadius: 10, offset: Offset(0, 3)),
      ],
    );

InputDecoration appInputDecoration({
  String? hint,
  IconData? icon,
  bool onDark = false,
  Widget? suffix,
}) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle:
        GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF8795AA)),
    filled: true,
    fillColor: Colors.white,
    prefixIcon:
        icon == null ? null : Icon(icon, size: 21, color: AppColors.muted),
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: b(AppColors.border),
    enabledBorder: b(AppColors.border),
    disabledBorder: b(AppColors.border),
    focusedBorder: b(AppColors.navy, 2),
    errorBorder: b(AppColors.red),
    focusedErrorBorder: b(AppColors.red, 2),
    errorMaxLines: 3,
    errorStyle: GoogleFonts.poppins(
      fontSize: 12.5,
      color: onDark ? AppColors.errorOnDark : AppColors.red,
    ),
  );
}

// ---------------------------------------------------------------------------
// Form widgets
// ---------------------------------------------------------------------------

class FieldLabel extends StatelessWidget {
  final String text;
  final bool onDark;
  const FieldLabel(this.text, {super.key, this.onDark = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: AppText.label.copyWith(
            color: onDark ? Colors.white : AppColors.text,
          ),
        ),
      );
}

class AppField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool password;
  final bool onDark;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool enabled;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final void Function(String)? onChanged;
  final int? maxLength;

  const AppField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.password = false,
    this.onDark = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.maxLength,
  });

  @override
  State<AppField> createState() => _AppFieldState();
}

class _AppFieldState extends State<AppField> {
  bool _hide = true;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return TextFormField(
      controller: w.controller,
      obscureText: w.password && _hide,
      keyboardType: w.keyboardType,
      validator: w.validator,
      maxLines: w.password ? 1 : w.maxLines,
      maxLength: w.maxLength,
      enabled: w.enabled,
      textInputAction: w.textInputAction,
      onFieldSubmitted: w.onSubmitted,
      onChanged: w.onChanged,
      style: GoogleFonts.poppins(fontSize: 15, color: AppColors.text),
      decoration: appInputDecoration(
        hint: w.hint,
        icon: w.icon,
        onDark: w.onDark,
        suffix: w.password
            ? IconButton(
                tooltip: _hide ? 'Show password' : 'Hide password',
                icon: Icon(
                  _hide
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 22,
                  color: AppColors.muted,
                ),
                onPressed: () => setState(() => _hide = !_hide),
              )
            : null,
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navy,
          disabledBackgroundColor: const Color(0xFFE9D6AE),
          disabledForegroundColor: const Color(0xFF8A7A55),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.navy),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, size: 21),
                  ],
                ],
              ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.navy,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 15.5)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cards, banners, headings
// ---------------------------------------------------------------------------

/// White rounded card with a proper tap effect.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color color;
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.margin = EdgeInsets.zero,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: color,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
      ),
    );
  }
}

enum BannerKind { info, warning, error, success }

/// A message box that stays on screen (better than a snackbar for important text).
class InfoBanner extends StatelessWidget {
  final String text;
  final BannerKind kind;
  const InfoBanner(this.text, {super.key, this.kind = BannerKind.info});

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Color fg;
    late IconData icon;
    switch (kind) {
      case BannerKind.info:
        bg = AppColors.softBlue;
        fg = AppColors.navy;
        icon = Icons.info_outline_rounded;
        break;
      case BannerKind.warning:
        bg = AppColors.softGold;
        fg = AppColors.goldDark;
        icon = Icons.hourglass_top_rounded;
        break;
      case BannerKind.error:
        bg = AppColors.softRed;
        fg = AppColors.red;
        icon = Icons.error_outline_rounded;
        break;
      case BannerKind.success:
        bg = AppColors.softGreen;
        fg = AppColors.green;
        icon = Icons.check_circle_outline_rounded;
        break;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style:
                    GoogleFonts.poppins(fontSize: 13, height: 1.4, color: fg)),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionTitle(this.title, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.heading)),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(48, 40),
              ),
              child: Text(actionLabel!,
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading placeholders (shown instead of a spinner)
// ---------------------------------------------------------------------------

class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
              const Color(0xFFE3E9F3), const Color(0xFFF2F5FA), _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A few grey card shapes that look like the real list while it loads.
class SkeletonCards extends StatelessWidget {
  final int count;
  const SkeletonCards({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: cardDecoration(16),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Skeleton(width: 40, height: 40, radius: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(width: 130, height: 13),
                          SizedBox(height: 6),
                          Skeleton(width: 80, height: 11),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                Skeleton(height: 13),
                SizedBox(height: 8),
                Skeleton(width: 220, height: 13),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Images and avatars
// ---------------------------------------------------------------------------

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: AppColors.gold,
          child: Icon(Icons.shield, size: size * 0.55, color: AppColors.navy),
        ),
      ),
    );
  }
}

class NetImage extends StatelessWidget {
  final String? path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;
  const NetImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 0,
  });

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.imageUrl(path);
    final placeholder = Container(
      width: width,
      height: height,
      color: AppColors.softBlue,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: AppColors.muted),
    );
    if (url.isEmpty) {
      return ClipRRect(
          borderRadius: BorderRadius.circular(radius), child: placeholder);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Skeleton(width: width, height: height ?? 120, radius: 0),
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String? path;
  final String name;
  final double radius;
  const Avatar(
      {super.key, required this.path, required this.name, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.imageUrl(path);
    final trimmed = name.trim();
    final initials = trimmed.isEmpty
        ? '?'
        : trimmed
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join();
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.gold,
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
          fontSize: radius * 0.7,
        ),
      ),
    );
    if (url.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

/// Status badge: colour AND icon AND text, so it is clear even without colour.
class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Color fg;
    late IconData icon;
    switch (stageOf(status)) {
      case ReportStage.resolved:
        bg = AppColors.softGreen;
        fg = AppColors.green;
        icon = Icons.check_circle_rounded;
        break;
      case ReportStage.inProgress:
        bg = AppColors.softBlue;
        fg = AppColors.navy;
        icon = Icons.autorenew_rounded;
        break;
      case ReportStage.pending:
        bg = AppColors.softGold;
        fg = AppColors.goldDark;
        icon = Icons.schedule_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            status.trim().isEmpty ? 'Pending' : status,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page header, filters, empty / error states
// ---------------------------------------------------------------------------

/// Clean white header used by every inner screen.
class TabHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? bottom;
  final VoidCallback? onBack;
  const TabHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.bottom,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          onBack == null ? 20 : 4, top + 10, 12, bottom == null ? 12 : 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  tooltip: 'Back',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: AppColors.navy),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.title),
                    if (subtitle != null) Text(subtitle!, style: AppText.small),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (bottom != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.only(
                  left: onBack == null ? 0 : 16, right: onBack == null ? 8 : 4),
              child: bottom!,
            ),
          ],
        ],
      ),
    );
  }
}

class FilterChips extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  const FilterChips({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sel = i == selected;
          return Material(
            color: sel ? AppColors.navy : Colors.white,
            shape: StadiumBorder(
              side: BorderSide(color: sel ? AppColors.navy : AppColors.border),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => onSelected(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    labels[i],
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : AppColors.text,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
                color: AppColors.navySoft, shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: AppColors.navy),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: AppText.heading),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: AppText.small),
          if (action != null) ...[
            const SizedBox(height: 20),
            action!,
          ],
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                color: AppColors.softRed, shape: BoxShape.circle),
            child: const Icon(Icons.wifi_off_rounded,
                size: 34, color: AppColors.red),
          ),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center, style: AppText.small),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
