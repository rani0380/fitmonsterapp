import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smart_app/controllers/game_controller.dart';
import 'package:smart_app/features/calibration/calibration_screen.dart';
import 'package:smart_app/features/jump_run/jump_run_screen.dart';
import 'package:smart_app/ui/fitmon_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FitmonColors.bgDeep,
      body: Stack(
        children: [
          const _HomeBackground(),
          SafeArea(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                _HomeMainContent(),
                _GameContent(),
                _RecordContent(),
                _SettingsContent(),
              ],
            ),
          ),
          _BottomNav(
            selectedIndex: _selectedIndex,
            onChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
        ],
      ),
    );
  }
}

class _HomeMainContent extends StatelessWidget {
  const _HomeMainContent();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 118),
      children: const [
        _TopBar(),
        SizedBox(height: 22),
        _MainCard(),
        SizedBox(height: 22),
        _EnergyCard(),
      ],
    );
  }
}

class _GameContent extends StatelessWidget {
  const _GameContent();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 118),
      children: const [
        _TopBar(),
        SizedBox(height: 22),
        Text(
          '게임',
          style: TextStyle(
            color: FitmonColors.text,
            fontSize: 30,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 10),
        Text(
          '운동 게임을 선택해 시작해보세요',
          style: TextStyle(
            color: FitmonColors.soft,
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 24),
        _ModeGrid(),
      ],
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GameController>();

    return Obx(
      () => ListView(
        padding: const EdgeInsets.fromLTRB(18, 26, 18, 118),
        children: [
          const _TopBar(),
          const SizedBox(height: 22),
          const Text(
            '설정',
            style: TextStyle(
              color: FitmonColors.text,
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '스쿼트 목표 횟수와 캐릭터를 선택하세요.',
            style: TextStyle(
              color: FitmonColors.soft,
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          _GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '스쿼트 목표 횟수',
                  style: TextStyle(
                    color: FitmonColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [10, 20, 30, 50].map((count) {
                    final selected = controller.targetSquatCount.value == count;
                    return ChoiceChip(
                      label: Text('$count회'),
                      selected: selected,
                      onSelected: (_) => controller.setTargetSquatCount(count),
                      selectedColor: FitmonColors.greenLight,
                      backgroundColor:
                          FitmonColors.bgDeep.withValues(alpha: 0.72),
                      labelStyle: TextStyle(
                        color: selected ? FitmonColors.bg : FitmonColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '캐릭터 선택',
                  style: TextStyle(
                    color: FitmonColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _CharacterOption(
                  label: '스마엉',
                  asset: 'assets/images/SEUMAEONG.png',
                  selected: controller.selectedCharacter.value ==
                      GameCharacter.smameong,
                  onTap: () => controller.setCharacter(GameCharacter.smameong),
                ),
                const SizedBox(height: 10),
                _CharacterOption(
                  label: '몬스터 1',
                  asset: 'assets/images/monster01.png',
                  selected: controller.selectedCharacter.value ==
                      GameCharacter.monster01,
                  onTap: () => controller.setCharacter(GameCharacter.monster01),
                ),
                const SizedBox(height: 10),
                _CharacterOption(
                  label: '몬스터 2',
                  asset: 'assets/images/monster02.png',
                  selected: controller.selectedCharacter.value ==
                      GameCharacter.monster02,
                  onTap: () => controller.setCharacter(GameCharacter.monster02),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterOption extends StatelessWidget {
  const _CharacterOption({
    required this.label,
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? FitmonColors.greenLight.withValues(alpha: 0.18)
              : FitmonColors.bgDeep.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? FitmonColors.greenLight
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Image.asset(asset, width: 58, height: 58, fit: BoxFit.contain),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: FitmonColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? FitmonColors.greenLight : FitmonColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordContent extends StatelessWidget {
  const _RecordContent();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GameController>();

    return Obx(() {
      final records = controller.recordHistory;
      final hasRecord = controller.hasSavedRecord.value || records.isNotEmpty;

      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 26, 18, 118),
        children: [
          const _TopBar(),
          const SizedBox(height: 22),
          const Text(
            '기록',
            style: TextStyle(
              color: FitmonColors.text,
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '마지막 운동 결과를 저장해서 보여줍니다',
            style: TextStyle(
              color: FitmonColors.soft,
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          if (!hasRecord)
            const _EmptyRecordCard()
          else ...[
            _RecordSummaryCard(controller: controller),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.25,
              children: [
                _RecordTile(
                  icon: Icons.local_fire_department,
                  label: '소모 칼로리',
                  value:
                      '${controller.savedCalories.value.toStringAsFixed(1)} kcal',
                  color: FitmonColors.yellow,
                ),
                _RecordTile(
                  icon: Icons.fitness_center,
                  label: '스쿼트 결과',
                  value: '${controller.savedSquatCount.value}회',
                  color: FitmonColors.greenLight,
                ),
                _RecordTile(
                  icon: Icons.favorite,
                  label: '심박수',
                  value: '${controller.savedHeartRate.value} bpm',
                  color: FitmonColors.cyan,
                ),
                _RecordTile(
                  icon: Icons.analytics,
                  label: '정자세 프레임',
                  value: '${controller.savedCorrectPostureFrames.value}',
                  color: FitmonColors.pink,
                ),
              ],
            ),
            if (records.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                '누적 기록',
                style: TextStyle(
                  color: FitmonColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              ...records.map((record) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RecordHistoryTile(record: record),
                  )),
            ],
          ],
        ],
      );
    });
  }
}

class _RecordHistoryTile extends StatelessWidget {
  const _RecordHistoryTile({required this.record});

  final GameRecord record;

  @override
  Widget build(BuildContext context) {
    final time =
        '${record.createdAt.month}/${record.createdAt.day} ${record.createdAt.hour.toString().padLeft(2, '0')}:${record.createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: fitmonCard(color: FitmonColors.card.withValues(alpha: 0.88)),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (record.completed
                      ? FitmonColors.greenLight
                      : FitmonColors.yellow)
                  .withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              record.completed ? Icons.emoji_events : Icons.flag,
              color: record.completed
                  ? FitmonColors.greenLight
                  : FitmonColors.yellow,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${record.mode} · $time',
                  style: const TextStyle(
                    color: FitmonColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${record.primaryLabel} ${record.primaryValue}  ·  ${record.secondaryLabel} ${record.secondaryValue}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FitmonColors.soft,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordSummaryCard extends StatelessWidget {
  const _RecordSummaryCard({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final progress =
        (controller.savedSquatCount.value / controller.targetSquatCount.value)
            .clamp(0.0, 1.0)
            .toDouble();

    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '최근 운동 완료',
                  style: TextStyle(
                    color: FitmonColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '목표 ${controller.targetSquatCount.value}회 중 ${controller.savedSquatCount.value}회',
                  style: const TextStyle(
                    color: FitmonColors.soft,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 9,
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      FitmonColors.greenLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Image.asset(
            'assets/images/SEUMAEONG.png',
            width: 76,
            height: 76,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: fitmonCard(color: FitmonColors.card.withValues(alpha: 0.9)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: FitmonColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FitmonColors.soft,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecordCard extends StatelessWidget {
  const _EmptyRecordCard();

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      child: const Column(
        children: [
          Icon(Icons.history, color: FitmonColors.muted, size: 42),
          SizedBox(height: 14),
          Text(
            '아직 기록이 없어요',
            style: TextStyle(
              color: FitmonColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '게임을 완료하면 여기에 결과가 저장됩니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: FitmonColors.soft,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBackground extends StatelessWidget {
  const _HomeBackground();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF08131F), FitmonColors.bgDeep],
            ),
          ),
          child: SizedBox.expand(),
        ),
        Positioned(
          right: -72,
          top: -120,
          child: _GlowCircle(size: 260, color: FitmonColors.yellow),
        ),
        Positioned(
          left: -110,
          top: 160,
          child: _GlowCircle(size: 230, color: FitmonColors.green),
        ),
        Positioned(
          right: -96,
          bottom: 92,
          child: _GlowCircle(size: 260, color: FitmonColors.cyan),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Fit Monster',
            style: TextStyle(
              color: FitmonColors.text,
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                FitmonColors.yellow.withValues(alpha: 0.88),
                FitmonColors.greenLight.withValues(alpha: 0.78),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.32),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Image.asset(
                'assets/images/SEUMAEONG.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MainCard extends StatelessWidget {
  const _MainCard();

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '스쿼트와 러닝을\n게임처럼 즐겨보세요',
            style: TextStyle(
              color: FitmonColors.text,
              fontSize: 29,
              height: 1.22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            '카메라로 자세를 인식해 스쿼트를 분석하고, 움직임에 따라 캐릭터가 반응합니다. 전신이 화면에 들어오도록 맞춘 뒤 시작해보세요.',
            style: TextStyle(
              color: FitmonColors.soft,
              fontSize: 16,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Get.to(() => const CalibrationScreen()),
              style: FilledButton.styleFrom(
                minimumSize: const Size(122, 52),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: FitmonColors.text,
                shape: const StadiumBorder(),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              child: const Text('스쿼트 시작'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnergyCard extends StatelessWidget {
  const _EnergyCard();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GameController>();

    return Obx(() {
      final burned = controller.todayBurnedCalories;
      final remaining = controller.todayRemainingCalories;
      final progress =
          (burned / GameController.dailyCalorieGoal).clamp(0.0, 1.0);

      return Container(
        height: 178,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FitmonColors.cyan.withValues(alpha: 0.62),
              FitmonColors.green.withValues(alpha: 0.54),
              FitmonColors.yellow.withValues(alpha: 0.34),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 36,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -6,
              bottom: -2,
              child: Image.asset(
                'assets/images/SEUMAEONG.png',
                width: 118,
                height: 118,
                fit: BoxFit.contain,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '\uC624\uB298 \uC18C\uBAA8\uD574\uC57C \uD560 \uCE7C\uB85C\uB9AC',
                  style: TextStyle(
                    color: FitmonColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${remaining.round()} kcal',
                  style: const TextStyle(
                    color: FitmonColors.text,
                    fontSize: 34,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\uC624\uB298 ${burned.toStringAsFixed(1)} kcal \uC18C\uBAA8 / \uBAA9\uD45C ${GameController.dailyCalorieGoal.round()} kcal',
                  style: const TextStyle(
                    color: FitmonColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 9,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        FitmonColors.yellow,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _ModeGrid extends StatelessWidget {
  const _ModeGrid();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeTile(
            title: '러닝',
            asset: 'assets/images/run.png',
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF24A8D6), Color(0xFF207FBE)],
            ),
            onTap: () => Get.to(() => const JumpRunScreen()),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: _ModeTile(
            title: '스쿼트',
            asset: 'assets/images/squirt.png',
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF06111F), Color(0xFF020913)],
            ),
            onTap: () => Get.to(() => const CalibrationScreen()),
          ),
        ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.asset,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String asset;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 206,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: gradient,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: FitmonColors.text,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Center(
              child: Image.asset(
                asset,
                width: 94,
                height: 94,
                fit: BoxFit.contain,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 18,
      child: SafeArea(
        top: false,
        child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xE609162A),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomNavItem(
                asset: 'assets/images/home.png',
                label: '홈',
                active: selectedIndex == 0,
                onTap: () => onChanged(0),
              ),
              _BottomNavItem(
                asset: 'assets/images/game.png',
                label: '게임',
                active: selectedIndex == 1,
                onTap: () => onChanged(1),
              ),
              _BottomNavItem(
                asset: 'assets/images/record.png',
                label: '기록',
                active: selectedIndex == 2,
                onTap: () => onChanged(2),
              ),
              _BottomNavItem(
                asset: 'assets/images/setting.png',
                label: '설정',
                active: selectedIndex == 3,
                onTap: () => onChanged(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.asset,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String asset;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 62,
        height: 62,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              asset,
              width: 25,
              height: 25,
              color: FitmonColors.text,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? FitmonColors.text : FitmonColors.soft,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: FitmonColors.card.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}
