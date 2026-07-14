import 'package:flutter/material.dart';

import '../constants/messages_ko.dart';
import '../models/recommendation.dart';
import '../models/saved_ai_course.dart';
import '../models/tour_conditions.dart';
import '../services/ai_recommend_service.dart';
import '../services/local_store.dart';
import '../services/place_repository.dart';
import '../widgets/recommendation_card.dart';
import '../widgets/yeongmaegi_bubble.dart';
import 'course_start.dart';
import 'preset_courses_screen.dart';

/// AI 추천 결과 화면입니다. (SPEC §4-3, §5)
///
/// 두 가지 모드로 열립니다:
///  - [AiResultScreen] : 조건([conditions])으로 Perplexity API 를 호출해 추천을 받습니다.
///    성공 시 결과를 shared_preferences 에 마지막 코스로 저장합니다.
///  - [AiResultScreen.fromSaved] : 저장된 결과([saved])를 API 재호출 없이 그대로 보여줍니다.
class AiResultScreen extends StatefulWidget {
  final TourConditions? conditions;
  final SavedAiCourse? saved;

  /// 현재 위치 좌표(있으면). 프롬프트 출발 슬롯 + 최근접 방문순서 정렬에 씁니다. (#3)
  final double? startLat;
  final double? startLng;

  const AiResultScreen({
    super.key,
    required TourConditions this.conditions,
    this.startLat,
    this.startLng,
  }) : saved = null;

  const AiResultScreen.fromSaved({super.key, required SavedAiCourse this.saved})
      : conditions = null,
        startLat = null,
        startLng = null;

  @override
  State<AiResultScreen> createState() => _AiResultScreenState();
}

class _AiResultScreenState extends State<AiResultScreen> {
  final PlaceRepository _placeRepo = PlaceRepository();
  final AiRecommendService _ai = AiRecommendService();
  final LocalStore _store = LocalStore();

  bool _loading = true;
  AiResult? _result;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    final places = await _placeRepo.loadPlaces();

    // 저장된 코스 재열람 모드: API 를 호출하지 않고 저장본을 그대로 표시.
    final saved = widget.saved;
    if (saved != null) {
      if (!mounted) return;
      setState(() {
        _result = AiResult(
          recommendations: saved.recommendations,
          courseTitle: saved.title,
        );
        _loading = false;
      });
      return;
    }

    final conditions = widget.conditions!;
    var result = await _ai.recommend(
      conditions: conditions,
      places: places,
      startLat: widget.startLat,
      startLng: widget.startLng,
    );
    // 현재 위치가 있으면 추천 장소를 최근접 방문순서로 재정렬. (#3)
    if (result.isSuccess &&
        widget.startLat != null &&
        widget.startLng != null) {
      final byName = {for (final p in places) p.name: p};
      final ordered = AiRecommendService.orderByNearest(
        result.recommendations,
        byName,
        widget.startLat!,
        widget.startLng!,
      );
      result = AiResult(
        recommendations: ordered,
        courseTitle: result.courseTitle,
      );
    }
    // 성공 시 마지막 AI 코스로 저장(기존 저장본 덮어씀).
    if (result.isSuccess) {
      await _store.saveLastAiCourse(SavedAiCourse(
        recommendations: result.recommendations,
        title: result.courseTitle,
        summary: conditions.summaryText,
        createdAt: DateTime.now(),
      ));
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  /// 조건 기반 로딩 코멘트를 고릅니다.
  String get _loadingComment {
    final c = widget.conditions;
    if (c == null) return MessagesKo.recommendPlanned;
    if (c.isSpontaneous) return MessagesKo.recommendSpontaneous;
    if (c.budgetPerPerson >= 70000) return MessagesKo.recommendRichBudget;
    if (c.budgetPerPerson <= 20000) return MessagesKo.recommendTightBudget;
    return MessagesKo.recommendPlanned;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 추천 결과')),
      body: SafeArea(
        child: _loading ? _buildLoading() : _buildBody(),
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          YeongmaegiBubble(message: _loadingComment),
          const SizedBox(height: 40),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          const Center(child: Text('영도 구석구석 뒤지는 중이라예… 쪼매만 기다리소')),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final result = _result!;
    if (result.isFailure) return _buildFailure(result);

    final recs = result.recommendations;
    final title = result.courseTitle.trim();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (title.isNotEmpty) ...[
          Row(
            children: [
              const Text('🧭 ', style: TextStyle(fontSize: 20)),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        const YeongmaegiBubble(
          message: '이 코스, 내가 자신 있게 미는 데이! 특히 추천 이유 한 번 보이소',
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < recs.length; i++)
          RecommendationCard(index: i + 1, rec: recs[i]),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('이 코스로 출발'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: () => _startCourse(recs, title),
        ),
      ],
    );
  }

  Widget _buildFailure(AiResult result) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          YeongmaegiBubble(
              message: result.errorMessage ?? MessagesKo.errorNoResult),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
            onPressed: _run,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.list_alt),
            label: const Text('추천 코스 11선에서 고르기'),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const PresetCoursesScreen()),
            ),
          ),
        ],
      ),
    );
  }

  void _startCourse(List<Recommendation> recs, String title) {
    // 진행 중 코스로 등록 → 지도 탭이 자동으로 코스 내비를 보여줍니다.
    startActiveCourse(
      context,
      courseName: title.isNotEmpty ? title : 'AI 맞춤 코스',
      stops: recs,
    );
  }
}
