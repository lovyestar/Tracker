import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/app_theme.dart';
import '../constants/messages_ko.dart';
import '../models/saved_ai_course.dart';
import '../models/tour_conditions.dart';
import '../services/local_store.dart';
import '../services/voice_service.dart';
import '../widgets/retro.dart';
import '../widgets/yeongmaegi_bubble.dart';
import 'ai_result_screen.dart';

/// 조건 입력 화면입니다. (SPEC §4-2)
class ConditionInputScreen extends StatefulWidget {
  const ConditionInputScreen({super.key});

  @override
  State<ConditionInputScreen> createState() => _ConditionInputScreenState();
}

class _ConditionInputScreenState extends State<ConditionInputScreen> {
  final TourConditions _c = TourConditions();
  final LocalStore _store = LocalStore();

  SavedAiCourse? _recent;

  static const _genders = ['남성', '여성', '혼성', '무관'];
  static const _ageGroups = [10, 20, 30, 40, 50, 60];
  static const _durations = ['반나절', '1일', '1박2일'];
  static const _themes = ['자연', '역사', '카페', '포토스팟', '맛집'];
  static const _companions = ['혼자', '친구', '커플', '가족', '부모님'];
  static const _styles = ['계획', '즉흥'];
  static const _nationalities = ['내국인', '외국인'];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final recent = await _store.loadLastAiCourse();
    if (!mounted) return;
    setState(() => _recent = recent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 추천')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const YeongmaegiBubble(
              message: '어떤 여행 코스를 원하는지 골라주이소! 니 취향 딱 맞는 코스 찾아주께',
            ),
            if (_recent != null) ...[
              const SizedBox(height: 16),
              _recentCourseCard(_recent!),
            ],
            const SizedBox(height: 20),
            _section('인원'),
            _stepper(),
            _section('성별'),
            _choiceChips(_genders, _c.gender, (v) => setState(() => _c.gender = v)),
            _section('나이대'),
            _choiceChips(
              _ageGroups.map((e) => '$e대').toList(),
              '${_c.ageGroup}대',
              (v) => setState(
                  () => _c.ageGroup = int.parse(v.replaceAll('대', ''))),
            ),
            _section('기간'),
            _choiceChips(
                _durations, _c.duration, (v) => setState(() => _c.duration = v)),
            _section('1인 예산: ${_formatBudget(_c.budgetPerPerson)}'),
            Slider(
              value: _c.budgetPerPerson.toDouble(),
              min: 10000,
              max: 100000,
              divisions: 9,
              label: _formatBudget(_c.budgetPerPerson),
              onChanged: (v) =>
                  setState(() => _c.budgetPerPerson = v.round()),
            ),
            _section('테마 (여러 개 선택 가능)'),
            _filterChips(),
            _section('동행 유형'),
            _choiceChips(_companions, _c.companionType,
                (v) => setState(() => _c.companionType = v)),
            _section('여행 스타일'),
            _choiceChips(
                _styles, _c.travelStyle, (v) => setState(() => _c.travelStyle = v)),
            _section('국적'),
            _choiceChips(_nationalities, _c.nationality,
                (v) => setState(() => _c.nationality = v)),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('코스 추천받기'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              onPressed: _submit,
            ),
            const SizedBox(height: 12),
            Text(
              MessagesKo.recommendStart,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    VoiceService.instance.play(VoiceLine.recommendStart);
    // 현재 위치를 얻으면(권한 있을 때) 출발 좌표로 넘겨 최근접 방문순서 정렬. (#3)
    final pos = await _tryGetCurrentPosition();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiResultScreen(
          conditions: _c,
          startLat: pos?.latitude,
          startLng: pos?.longitude,
        ),
      ),
    );
    // 새 추천을 받고 돌아왔을 수 있으므로 최근 코스 카드 갱신.
    if (mounted) _loadRecent();
  }

  /// 현재 위치를 1회 조용히 얻습니다. 권한/서비스 없으면 null(정렬은 기존 순서 유지). (#3)
  Future<Position?> _tryGetCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      return await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (e) {
      debugPrint('[Condition] 위치 획득 실패(무시): $e');
      return null;
    }
  }

  void _openRecent(SavedAiCourse saved) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AiResultScreen.fromSaved(saved: saved)),
    );
  }

  /// "최근 추천 코스 다시 보기" 카드 — API 재호출 없이 저장된 결과를 다시 엽니다.
  Widget _recentCourseCard(SavedAiCourse saved) {
    final places = saved.recommendations.map((r) => r.placeName).join(' · ');
    return RetroCard(
      onTap: () => _openRecent(saved),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.sunnyYellow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '최근 추천 코스 다시 보기',
                    style: TextStyle(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  saved.title.isNotEmpty
                      ? saved.title
                      : (saved.summary.isEmpty ? 'AI 맞춤 코스' : saved.summary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy),
                ),
                if (saved.title.isNotEmpty && saved.summary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    saved.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.bodyBrown),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  places,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12.5, color: AppTheme.bodyText),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatCreatedAt(saved.createdAt),
                  style:
                      const TextStyle(fontSize: 11.5, color: AppTheme.bodyBrown),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppTheme.skyBlue),
        ],
      ),
    );
  }

  String _formatCreatedAt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}.${two(dt.month)}.${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _formatBudget(int won) => '${(won / 10000).toStringAsFixed(0)}만원';

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(title,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _stepper() {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: _c.groupSize > 1
              ? () => setState(() => _c.groupSize--)
              : null,
          icon: const Icon(Icons.remove),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('${_c.groupSize}명',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        IconButton.filledTonal(
          onPressed: _c.groupSize < 10
              ? () => setState(() => _c.groupSize++)
              : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  Widget _choiceChips(
      List<String> options, String selected, ValueChanged<String> onSelect) {
    return Wrap(
      spacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o),
            selected: selected == o,
            onSelected: (_) => onSelect(o),
          ),
      ],
    );
  }

  Widget _filterChips() {
    return Wrap(
      spacing: 8,
      children: [
        for (final t in _themes)
          FilterChip(
            label: Text(t),
            selected: _c.themes.contains(t),
            onSelected: (sel) => setState(() {
              if (sel) {
                _c.themes.add(t);
              } else {
                _c.themes.remove(t);
              }
            }),
          ),
      ],
    );
  }
}
