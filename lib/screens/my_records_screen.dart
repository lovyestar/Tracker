import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../constants/preset_courses.dart';
import '../models/completion_record.dart';
import '../services/local_store.dart';
import '../widgets/place_photo.dart';
import '../widgets/retro.dart';
import 'completion_detail_screen.dart';

/// 스탬프(내 기록) 화면입니다. (레트로 선셋 시안 07 하단)
///  - 로컬 완주 이력 + 스탬프 컬렉션 도감(미획득은 자물쇠).
class MyRecordsScreen extends StatefulWidget {
  const MyRecordsScreen({super.key});

  @override
  State<MyRecordsScreen> createState() => _MyRecordsScreenState();
}

class _MyRecordsScreenState extends State<MyRecordsScreen> {
  final LocalStore _store = LocalStore();
  List<CompletionRecord> _records = [];
  bool _loading = true;

  /// 스탬프 도감에 노출할 대표 명소(프리셋 코스에서 중복 없이 추출).
  late final List<String> _collectionPlaces = _buildCollectionPlaces();

  static List<String> _buildCollectionPlaces() {
    final seen = <String>{};
    final out = <String>[];
    for (final course in kPresetCourses) {
      for (final name in course.placeNames) {
        if (seen.add(name)) out.add(name);
      }
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await _store.loadRecords();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  int get _totalStamps => _records.fold<int>(0, (s, r) => s + r.stampCount);

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('스탬프')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                color: AppTheme.burntOrange,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _summaryCard(),
                    const SizedBox(height: 22),
                    const SectionHeader(
                        icon: Icons.local_activity, title: '스탬프 컬렉션'),
                    const SizedBox(height: 12),
                    _stampGrid(),
                    const SizedBox(height: 24),
                    const SectionHeader(
                        icon: Icons.emoji_events, title: '완주 기록'),
                    const SizedBox(height: 12),
                    if (_records.isEmpty)
                      _emptyRecords()
                    else
                      for (final r in _records) ...[
                        _recordTile(r),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: AppTheme.sunsetGradient,
      ),
      child: Row(
        children: [
          const Icon(Icons.local_activity, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('완주 ${_records.length}회 · 스탬프 $_totalStamps개',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                const Text('지금까지 모은 기록이다',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stampGrid() {
    final unlocked = _totalStamps;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _collectionPlaces.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, i) {
        final isUnlocked = i < unlocked;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: isUnlocked
                  ? CourseThumb(
                      placeName: _collectionPlaces[i],
                      width: double.infinity,
                      height: double.infinity)
                  : Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF2F7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.lineSoft),
                      ),
                      child: const Center(
                        child: Icon(Icons.lock_outline,
                            color: AppTheme.bodyBrown),
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              isUnlocked ? _collectionPlaces[i] : '미획득',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                color: isUnlocked ? AppTheme.warmBrown : AppTheme.bodyBrown,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _recordTile(CompletionRecord r) {
    // 대표 사진: 완주한 첫 장소 사진(#12). 장소 정보가 없으면 우표 아이콘 폴백.
    final coverName = r.placeNames.isNotEmpty ? r.placeNames.first : null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CompletionDetailScreen(record: r),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.cardDecoration(radius: 16),
        child: Row(
          children: [
            if (coverName != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PlacePhoto(placeName: coverName, width: 56, height: 56),
              )
            else
              const PostageFrame(
                padding: EdgeInsets.all(8),
                child:
                    Icon(Icons.verified, color: AppTheme.burntOrange, size: 22),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppTheme.warmBrown)),
                  const SizedBox(height: 4),
                  Text('${_formatDate(r.date)} · 스탬프 ${r.stampCount}개',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppTheme.bodyBrown)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.bodyBrown),
          ],
        ),
      ),
    );
  }

  Widget _emptyRecords() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: const Center(
        child: Text('아직 완주한 코스가 없데이. 코스 하나 골라서 스탬프 모아봐라!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.bodyBrown)),
      ),
    );
  }
}
