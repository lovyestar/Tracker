import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../constants/app_theme.dart';
import '../constants/messages_ko.dart';
import '../models/completion_record.dart';
import '../models/user_course.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/local_store.dart';
import '../services/notification_store.dart';
import '../services/user_course_store.dart';
import '../services/voice_service.dart';
import '../widgets/retro.dart';
import '../widgets/top_snack_bar.dart';
import 'add_course_screen.dart';
import 'leaderboard_screen.dart';
import 'notifications_screen.dart';

/// 마이(내 정보) 화면입니다. (레트로 선셋 시안 07)
///  - 프로필(닉네임 편집) + 3스탯 + 영도 랭킹 + 완주 기록
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final LocalStore _store = LocalStore();
  final FirebaseService _firebase = FirebaseService();
  final UserCourseStore _courseStore = UserCourseStore();
  String? _nickname;
  List<CompletionRecord> _records = [];
  List<UserCourse> _myCourses = [];
  bool _loading = true;
  bool _signingIn = false;
  bool _voiceOn = VoiceService.instance.enabled;

  /// 현재 로그인된 Google 계정(비로그인 시 null).
  User? _user;

  /// 프로필 사진 파일. 미설정/유실이면 null → 기본(영매기) 표시.
  File? _profilePhoto;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final nick = await _store.getNickname();
    final records = await _store.loadRecords();
    final photoPath = await _store.getProfilePhotoPath();
    final courses = await _courseStore.loadCourses();
    await NotificationStore.instance.refreshUnread();
    if (!mounted) return;
    setState(() {
      _nickname = nick;
      _records = records;
      _myCourses = courses;
      _user = AuthService.instance.currentUser;
      // 파일이 삭제/유실됐으면 기본으로 폴백.
      _profilePhoto = (photoPath != null && File(photoPath).existsSync())
          ? File(photoPath)
          : null;
      _loading = false;
    });
  }

  Future<void> _signIn() async {
    setState(() => _signingIn = true);
    final result = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _signingIn = false);

    if (result.cancelled) return; // 조용히 종료.
    if (!result.isSuccess) {
      showTopSnackBar(context,
          message: result.errorMessage ?? '로그인에 실패했데이.');
      return;
    }
    // 로그인 성공 → 로컬 기록을 uid 문서로 1회 병합 + 코스·완주 기록 클라우드 동기화.
    await _mergeLocalRecordsOnce(result.user!);
    await _syncCloudOnLogin(result.user!);
    await NotificationStore.instance
        .recordLogin(result.user!.displayName ?? '여행자');
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    showTopSnackBar(context, message: '로그인 완료! 이제 기기가 바뀌어도 기록이 이어진데이.');
  }

  /// 로그인 시점 1회 마이그레이션: 로컬 완주 기록을 uid 리더보드 문서로 병합.
  Future<void> _mergeLocalRecordsOnce(User user) async {
    try {
      if (await _store.isMergedForUid(user.uid)) return;
      final records = await _store.loadRecords();
      if (records.isNotEmpty) {
        final nickname =
            (await _store.getNickname()) ?? user.displayName ?? '여행자';
        final totalStamps =
            records.fold<int>(0, (s, r) => s + r.stampCount);
        await _firebase.mergeLocalRecords(
          uid: user.uid,
          nickname: nickname,
          totalStamps: totalStamps,
          completions: records.length,
        );
      }
      await _store.markMergedForUid(user.uid);
    } catch (e) {
      debugPrint('[Profile] 로컬 기록 병합 실패: $e');
    }
  }

  /// 로그인 시 로컬 코스·완주 기록을 클라우드와 양방향 병합합니다. (#5)
  ///  1) 로컬 → Firestore 업로드(merge; 로컬 id/내용키를 문서 id 로).
  ///  2) Firestore → 로컬 내려받아 병합(없던 것만 추가; 로컬 우선).
  /// 사진 파일은 업로드하지 않습니다(로컬 경로 전용; Storage 범위 밖).
  Future<void> _syncCloudOnLogin(User user) async {
    if (!_firebase.isAvailable) return;
    try {
      final uid = user.uid;
      final localCourses = await _courseStore.loadCourses();
      final localRecords = await _store.loadRecords();

      for (final c in localCourses) {
        await _firebase.uploadCourse(uid, c);
      }
      for (final r in localRecords) {
        await _firebase.uploadRecord(uid, r);
      }

      final remoteCourses = await _firebase.downloadCourses(uid);
      final remoteRecords = await _firebase.downloadRecords(uid);
      await _courseStore.upsertCourses(remoteCourses);
      await _store.upsertRecords(remoteRecords);
    } catch (e) {
      debugPrint('[Profile] 클라우드 동기화 실패(로컬 우선): $e');
    }
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    await _load();
  }

  /// 갤러리에서 사진을 골라 앱 문서 디렉토리에 복사 후 경로를 저장합니다.
  Future<void> _pickProfilePhoto() async {
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final ext = picked.path.split('.').last;
      final dest =
          '${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(picked.path).copy(dest);
      await _store.setProfilePhotoPath(dest);
      if (!mounted) return;
      setState(() => _profilePhoto = File(dest));
    } catch (e) {
      debugPrint('[Profile] 프로필 사진 변경 실패: $e');
      if (!mounted) return;
      showTopSnackBar(context, message: '사진을 불러오지 못했데이. 다시 해보이소.');
    }
  }

  Future<void> _editNickname() async {
    final controller = TextEditingController(text: _nickname ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardCream,
        title: const Text('닉네임 설정'),
        content: TextField(
          controller: controller,
          maxLength: 12,
          decoration: const InputDecoration(hintText: '리더보드에 표시할 닉네임'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _store.setNickname(result);
      if (!mounted) return;
      setState(() => _nickname = result);
    }
  }

  int get _totalStamps => _records.fold<int>(0, (s, r) => s + r.stampCount);

  /// 표시 이름: 사용자가 직접 설정한 닉네임 > 구글 이름 > 기본값.
  String get _displayName =>
      _nickname ?? _user?.displayName ?? '여행자';

  /// 아바타 위젯: 로컬 사진 > 구글 사진 > 기본(영매기). 각 단계 실패 시 다음으로 폴백.
  Widget _avatarImage() {
    const double size = 62;
    if (_profilePhoto != null) {
      return Image.file(_profilePhoto!,
          width: size, height: size, fit: BoxFit.cover);
    }
    final photoUrl = _user?.photoURL;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Image.network(
        photoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset('assets/images/yeongmaegi.jpg',
            width: size, height: size, fit: BoxFit.cover),
      );
    }
    return Image.asset('assets/images/yeongmaegi.jpg',
        width: size, height: size, fit: BoxFit.cover);
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                color: AppTheme.burntOrange,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Row(
                      children: [
                        Text('Tracker', style: AppTheme.logo(size: 26)),
                        const Spacer(),
                        _notificationBell(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _profileCard(),
                    if (_user == null) ...[
                      const SizedBox(height: 12),
                      _loginButton(),
                    ],
                    const SizedBox(height: 16),
                    _statsRow(),
                    const SizedBox(height: 16),
                    _rankCard(),
                    const SizedBox(height: 16),
                    _voiceToggleCard(),
                    const SizedBox(height: 24),
                    const SectionHeader(
                      icon: Icons.flag,
                      title: '내가 만든 코스',
                    ),
                    const SizedBox(height: 12),
                    if (_myCourses.isEmpty)
                      _emptyCourses()
                    else
                      for (final c in _myCourses) ...[
                        _myCourseCard(c),
                        const SizedBox(height: 10),
                      ],
                    const SizedBox(height: 24),
                    SectionHeader(
                      icon: Icons.emoji_events,
                      title: '나의 완주 기록',
                      actionText: _records.isEmpty ? null : '전체보기',
                      onAction: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LeaderboardScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_records.isEmpty)
                      _emptyRecords()
                    else
                      for (final r in _records.take(4)) ...[
                        _recordTile(r),
                        const SizedBox(height: 10),
                      ],
                    if (_user != null) ...[
                      const SizedBox(height: 8),
                      _logoutButton(),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  /// 상단 알림 벨: 탭하면 알림 기록 화면으로 이동합니다.
  /// 읽지 않은 알림이 있으면 코랄 점/숫자 배지를 겹쳐 표시합니다. (#6)
  Widget _notificationBell() {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationStore.instance.unread,
      builder: (context, unread, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none,
                  color: AppTheme.warmBrown),
              tooltip: '알림',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()),
                );
                if (!mounted) return;
                await NotificationStore.instance.refreshUnread();
              },
            ),
            if (unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.coralRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 비로그인 시 노출되는 "Google로 로그인" 버튼(흰 배경 라운드 pill).
  /// 로그인은 선택 사항이며, 게스트로도 모든 기능이 그대로 동작합니다.
  Widget _loginButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _signingIn ? null : _signIn,
        icon: _signingIn
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.lineSoft),
                ),
                child: const Text('G',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: AppTheme.skyBlue)),
              ),
        label: Text(_signingIn ? '로그인 중…' : 'Google로 로그인'),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppTheme.cardWhite,
          foregroundColor: AppTheme.navy,
          side: const BorderSide(color: AppTheme.lineSoft),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  /// 로그인 상태일 때 하단에 작게 노출되는 로그아웃 버튼.
  Widget _logoutButton() {
    return Center(
      child: TextButton.icon(
        onPressed: _signOut,
        icon: const Icon(Icons.logout, size: 16, color: AppTheme.bodyBrown),
        label: const Text('로그아웃',
            style: TextStyle(fontSize: 13, color: AppTheme.bodyBrown)),
      ),
    );
  }

  Widget _profileCard() {
    return RetroCard(
      onTap: _editNickname,
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickProfilePhoto,
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.gold, width: 2.5),
                  ),
                  child: ClipOval(child: _avatarImage()),
                ),
                // 카메라 뱃지: 사진 변경 가능 표시.
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.skyBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(_displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.warmBrown)),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.edit, size: 16, color: AppTheme.bodyBrown),
                  ],
                ),
                const SizedBox(height: 4),
                Text(MessagesKo.greetingForHour(DateTime.now().hour),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.bodyBrown, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        _statCard(Icons.flag, '완주 코스', '${_records.length}'),
        const SizedBox(width: 10),
        _statCard(Icons.local_activity, '획득 스탬프', '$_totalStamps'),
        const SizedBox(width: 10),
        _statCard(Icons.place, '방문 명소', '$_totalStamps'),
      ],
    );
  }

  Widget _statCard(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: AppTheme.cardDecoration(radius: 16),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.burntOrange, size: 24),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.warmBrown)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(fontSize: 11.5, color: AppTheme.bodyBrown)),
          ],
        ),
      ),
    );
  }

  Widget _rankCard() {
    if (!_firebase.isAvailable) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: AppTheme.sunsetGradient,
        ),
        child: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.white, size: 30),
            SizedBox(width: 12),
            Expanded(
              child: Text('Firebase를 연결하면 영도 랭킹이 뜬데이!',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }
    return StreamBuilder<List<LeaderboardEntry>>(
      stream: _firebase.leaderboardStream(),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <LeaderboardEntry>[];
        int? rank;
        if (_nickname != null) {
          final idx = entries.indexWhere((e) => e.nickname == _nickname);
          if (idx >= 0) rank = idx + 1;
        }
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: AppTheme.sunsetGradient,
          ),
          child: Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.white, size: 34),
              const SizedBox(width: 14),
              const Expanded(
                child: Text('이번 영도 랭킹',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
              Text(rank == null ? '순위권 밖' : '$rank위',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900)),
            ],
          ),
        );
      },
    );
  }

  Widget _voiceToggleCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: AppTheme.cardDecoration(radius: 16),
      child: Row(
        children: [
          const Icon(Icons.record_voice_over, color: AppTheme.skyBlue),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('영매기 목소리',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy)),
          ),
          Switch(
            value: _voiceOn,
            onChanged: (value) async {
              setState(() => _voiceOn = value);
              await VoiceService.instance.setEnabled(value);
            },
          ),
        ],
      ),
    );
  }

  /// "내가 만든 코스" 카드: 썸네일+제목+카테고리 칩+위치.
  /// 탭하면 상세 시트, 길게 누르면 삭제 확인 다이얼로그.
  Widget _myCourseCard(UserCourse course) {
    return GestureDetector(
      onTap: () => _showMyCourse(course),
      onLongPress: () => _confirmDeleteCourse(course),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.cardDecoration(radius: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _courseThumb(course, 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppTheme.warmBrown)),
                  const SizedBox(height: 4),
                  Text(course.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppTheme.bodyBrown)),
                  if (course.categories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final c in course.categories.take(3))
                          InfoTag(icon: Icons.tag, text: c),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 코스 썸네일: 첫 사진이 있으면 Image.file, 없거나 유실이면 플레이스홀더.
  Widget _courseThumb(UserCourse course, double size) {
    final path = course.photoPaths.isNotEmpty ? course.photoPaths.first : null;
    if (path == null || !File(path).existsSync()) {
      return CourseThumb(width: size, height: size, radius: 14);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            CourseThumb(width: size, height: size, radius: 14),
      ),
    );
  }

  void _showMyCourse(UserCourse course) {
    final validPhotos =
        course.photoPaths.where((p) => File(p).existsSync()).toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(course.title,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.warmBrown)),
              const SizedBox(height: 6),
              if (validPhotos.isNotEmpty) ...[
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: validPhotos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(validPhotos[i]),
                        width: 160,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  const Icon(Icons.place_outlined,
                      size: 16, color: AppTheme.bodyBrown),
                  const SizedBox(width: 4),
                  Expanded(child: Text(course.location)),
                ],
              ),
              if (course.categories.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in course.categories) Chip(label: Text(c)),
                  ],
                ),
              ],
              if (course.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(course.description,
                    style: const TextStyle(
                        color: AppTheme.bodyBrown, height: 1.5)),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('이 코스 수정'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _editCourse(course);
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('이 코스 삭제'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.coralRed,
                  side: const BorderSide(color: AppTheme.coralRed),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDeleteCourse(course);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 내가 만든 코스를 수정 모드로 열고, 저장되면 목록을 새로고칩니다. (#4)
  Future<void> _editCourse(UserCourse course) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddCourseScreen(initial: course)),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _confirmDeleteCourse(UserCourse course) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardWhite,
        title: const Text('코스 삭제'),
        content: Text('\'${course.title}\' 코스를 지울까? 되돌릴 수 없데이.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.coralRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _courseStore.deleteCourse(course.id);
    // 로그인 상태면 클라우드에서도 삭제(실패해도 로컬 삭제는 유지).
    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) await _firebase.deleteCourseDoc(uid, course.id);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    showTopSnackBar(context, message: '코스를 지웠데이.');
  }

  Widget _emptyCourses() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: const Center(
        child: Text('아직 만든 코스가 없데이. 저장 탭에서 코스를 하나 만들어봐라!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.bodyBrown)),
      ),
    );
  }

  Widget _recordTile(CompletionRecord r) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration(radius: 16),
      child: Row(
        children: [
          const CourseThumb(width: 56, height: 56, radius: 14),
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
                        color: AppTheme.warmBrown)),
                const SizedBox(height: 4),
                Text(_formatDate(r.date),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppTheme.bodyBrown)),
              ],
            ),
          ),
          const PostageFrame(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Icon(Icons.verified, color: AppTheme.burntOrange, size: 18),
          ),
        ],
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
