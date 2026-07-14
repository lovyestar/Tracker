import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_theme.dart';

OverlayEntry? _currentEntry;
Timer? _currentTimer;

/// 화면 상단에서 내려오는 스낵바입니다. 기본 [SnackBar](하단 고정)는 사용하지 않고
/// 이 함수로 통일해 항상 위에서 등장하도록 합니다.
///
/// [message]를 주면 기본 네이비 말풍선 스타일로, [content]를 주면 지정한
/// 위젯을 그대로 띄웁니다(예: 영매기 말풍선 토스트).
void showTopSnackBar(
  BuildContext context, {
  String? message,
  Widget? content,
  Duration duration = const Duration(seconds: 3),
  EdgeInsets margin = const EdgeInsets.fromLTRB(16, 12, 16, 0),
}) {
  assert(message != null || content != null,
      'message 또는 content 중 하나는 반드시 지정해야 합니다.');

  final overlay = Overlay.of(context, rootOverlay: true);

  _currentTimer?.cancel();
  _currentEntry?.remove();
  _currentEntry = null;

  final key = GlobalKey<_TopSnackBarState>();
  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => _TopSnackBar(
      key: key,
      margin: margin,
      onDismissed: () {
        entry.remove();
        if (identical(_currentEntry, entry)) {
          _currentEntry = null;
        }
      },
      child: content ??
          Material(
            color: AppTheme.navy,
            elevation: 6,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Text(
                message!,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: AppTheme.serifFamily,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
    ),
  );

  _currentEntry = entry;
  overlay.insert(entry);
  _currentTimer = Timer(duration, () => key.currentState?.dismiss());
}

class _TopSnackBar extends StatefulWidget {
  final Widget child;
  final EdgeInsets margin;
  final VoidCallback onDismissed;

  const _TopSnackBar({
    super.key,
    required this.child,
    required this.margin,
    required this.onDismissed,
  });

  @override
  State<_TopSnackBar> createState() => _TopSnackBarState();
}

class _TopSnackBarState extends State<_TopSnackBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<Offset> _offset = Tween(
    begin: const Offset(0, -1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  Future<void> dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: widget.margin,
          child: SlideTransition(
            position: _offset,
            child: FadeTransition(
              opacity: _controller,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: dismiss,
                onVerticalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) < 0) dismiss();
                },
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}