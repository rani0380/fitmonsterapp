import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smart_app/controllers/game_controller.dart';
import 'package:smart_app/features/home/home_screen.dart';
import 'package:smart_app/ui/fitmon_theme.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GameController>();
    controller.saveCurrentResult();

    return Scaffold(
      backgroundColor: FitmonColors.bg,
      appBar: AppBar(
        title: const Text('운동 결과'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Get.offAll(() => const HomeScreen()),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: FitmonColors.green.withValues(alpha: 0.35)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F2545),
                  Color(0xFF173660),
                  Color(0xFF1A4230)
                ],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '퀘스트 완료!',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'AI 모션 인식으로 생성된 오늘의 운동 기록입니다.',
                        style: TextStyle(
                          color: FitmonColors.muted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Image.asset(
                  'assets/images/active_run_mascot.png',
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _ResultGrid(controller: controller),
          const SizedBox(height: 18),
          _ChartCard(controller: controller),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => Get.offAll(() => const HomeScreen()),
            icon: const Icon(Icons.home),
            label: const Text('홈으로 돌아가기'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultGrid extends StatelessWidget {
  const _ResultGrid({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.35,
        children: [
          _ResultTile(
            icon: Icons.local_fire_department,
            label: '소모 칼로리',
            value: '${controller.totalCalories.value.toStringAsFixed(1)} kcal',
            color: FitmonColors.yellow,
          ),
          _ResultTile(
            icon: Icons.fitness_center,
            label: '스쿼트 공격',
            value: '${controller.squatCount.value}회',
            color: FitmonColors.greenLight,
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
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
      decoration: fitmonCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: FitmonColors.muted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final rpm = controller.currentRPM.value.clamp(10.0, 120.0);
    return Container(
      height: 230,
      padding: const EdgeInsets.all(18),
      decoration: fitmonCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.show_chart, color: FitmonColors.greenLight, size: 20),
              SizedBox(width: 8),
              Text('운동 리듬',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 130,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      const FlSpot(0, 20),
                      FlSpot(1, rpm * 0.72),
                      FlSpot(2, rpm * 0.92),
                      FlSpot(3, rpm * 0.84),
                      FlSpot(4, rpm),
                      FlSpot(5, rpm * 0.78),
                    ],
                    isCurved: true,
                    color: FitmonColors.greenLight,
                    barWidth: 4,
                    belowBarData: BarAreaData(
                      show: true,
                      color: FitmonColors.greenLight.withValues(alpha: 0.14),
                    ),
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
