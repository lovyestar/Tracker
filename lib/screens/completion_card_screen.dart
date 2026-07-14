import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../constants/messages_ko.dart';
import '../models/completion_record.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/local_store.dart';
import '../services/notification_store.dart';
import '../services/voice_service.dart';
import '../widgets/retro.dart';
import '../widgets/top_snack_bar.dart';
import '../widgets/yeongmaegi_bubble.dart';

/// 완주 카드 화면입니다. (SPEC §4-6)
///  - 영매기 이미지 + 완주 대사 + 코스명/날짜/스탬프 수
///  - 로컬 저장 + (가능하면) Firestore 저장
class CompletionCardScreen extends StatefulWidget {
  final String courseName;
  final int stampCount;

  /// 완주한 장소 이름(방문 순서). 완주 기록 대표 사진·상세에 저장됩니다. (#12/#16)
  final List<String> placeNames;

  /// 내비 중 기록한 GPS 궤적([[lat,lng], ...]). 상세 지도 경로에 저장됩니다. (#16)
  final List<List<double>> route;

  const CompletionCardScreen({
    super.key,
    required this.courseName,
    required this.stampCount,
    this.placeNames = const [],
    this.route = const [],
  });

  @override
  State<CompletionCardScreen> createState() => _CompletionCardScreenState();
}

class _CompletionCardScreenState extends State<CompletionCardScreen> {
  final LocalStore _store = LocalStore();
  final FirebaseService _firebase = FirebaseService();
  final DateTime _date = DateTime.now();
  bool _saved = false;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    VoiceService.instance.play(VoiceLine.complete);
    _save();
  }

  Future<void> _save() async {
    final nickname = (await _store.getNickname()) ?? '여행자';
    final record = CompletionRecord(
      nickname: nickname,
      courseName: widget.courseName,
      date: _date,
      stampCount: widget.stampCount,
      placeNames: widget.placeNames,
      route: widget.route,
    );
    await _store.addRecord(record);
    await NotificationStore.instance
        .recordCompletion(widget.courseName, widget.stampCount);
    try {
      // 로그인 상태면 uid 를 문서 ID 로 써서 기기가 바뀌어도 기록이 이어집니다.
      final uid = AuthService.instance.currentUser?.uid;
      await _firebase.saveCompletion(record, docId: uid);
      // 완주 기록을 users/{uid}/records 에도 저장(로그인 시). 로컬 우선, 실패 무시.
      if (uid != null) await _firebase.uploadRecord(uid, record);
    } catch (_) {
      // Firebase 미설정/오류 시 로컬 저장만 유지합니다.
    }
    if (!mounted) return;
    setState(() {
      _saved = true;
      _statusText = _firebase.isAvailable
          ? '기록이 리더보드에 저장됐데이!'
          : '기록이 이 폰에 저장됐데이! (Firebase 설정하면 리더보드에도 올라간다)';
    });
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.paperGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 8),
              const Center(
                child: Text('· Congratulations! ·',
                    style: TextStyle(
                        fontFamily: AppTheme.serifFamily,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.gold,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text('코스 완주 완료!', style: AppTheme.logo(size: 34)),
              ),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.burntOrange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(widget.courseName,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 20),
              _card(),
              const SizedBox(height: 20),
              if (_saved)
                Text(_statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppTheme.bodyBrown)),
              const SizedBox(height: 4),
              const Text(MessagesKo.completeShare,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppTheme.bodyBrown)),
              const SizedBox(height: 14),
              FilledButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('완주 카드 저장하기'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54)),
                onPressed: () => showTopSnackBar(
                  context,
                  message: '완주 카드가 기록에 저장됐데이!',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: const Text('다음 코스 보기'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(radius: 22),
      child: Column(
        children: [
          const YeongmaegiBubble(message: MessagesKo.complete, avatarSize: 72),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _completedStamp(),
              const SizedBox(width: 18),
              _completeBadge(),
            ],
          ),
          const Divider(height: 28),
          Text('나의 여행 기록',
              style: AppTheme.heading(size: 15, color: AppTheme.gold)),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat(Icons.local_activity, '획득 스탬프', '${widget.stampCount}개'),
              _stat(Icons.flag, '완주', '${widget.stampCount}/${widget.stampCount}'),
              _stat(Icons.calendar_today, '완주일', _formatDate(_date)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _completedStamp() {
    return PostageFrame(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'assets/images/yeongmaegi.jpg',
              width: 84,
              height: 84,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 6),
          const Text('COMPLETED',
              style: TextStyle(
                  fontFamily: AppTheme.serifFamily,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.burntOrange)),
        ],
      ),
    );
  }

  Widget _completeBadge() {
    return Container(
      width: 96,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.sunsetGradient,
        border: Border.all(color: AppTheme.gold, width: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${widget.stampCount}/${widget.stampCount}',
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const Text('완주',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppTheme.burntOrange, size: 22),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppTheme.bodyBrown)),
          const SizedBox(height: 2),
          Text(value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppTheme.warmBrown)),
        ],
      ),
    );
  }
}
