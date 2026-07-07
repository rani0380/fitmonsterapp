import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

enum GameCharacter { smameong, monster01, monster02 }

class GameRecord {
  const GameRecord({
    required this.mode,
    required this.primaryLabel,
    required this.primaryValue,
    required this.secondaryLabel,
    required this.secondaryValue,
    required this.createdAt,
    required this.completed,
    required this.calories,
  });

  final String mode;
  final String primaryLabel;
  final String primaryValue;
  final String secondaryLabel;
  final String secondaryValue;
  final DateTime createdAt;
  final bool completed;
  final double calories;
}

class GameController extends GetxController {
  static const defaultTargetSquatCount = 30;
  static const dailyCalorieGoal = 300.0;

  final currentRPM = 0.0.obs;
  final squatPower = 0.0.obs;
  final isSquatting = false.obs;
  final lateralOffset = 0.5.obs;
  final boosterGauge = 0.0.obs;
  final totalCalories = 0.0.obs;
  final squatCount = 0.obs;
  final raceProgress = 0.0.obs;
  final monsterHp = 1.0.obs;
  final detectedPoseCount = 0.obs;
  final processedFrames = 0.obs;
  final correctPostureFrames = 0.obs;
  final attackTick = 0.obs;
  final monsterAttackTick = 0.obs;
  final hasSavedRecord = false.obs;
  final savedCalories = 0.0.obs;
  final savedSquatCount = 0.obs;
  final savedHeartRate = 0.obs;
  final savedCorrectPostureFrames = 0.obs;
  final targetSquatCount = defaultTargetSquatCount.obs;
  final selectedCharacter = GameCharacter.smameong.obs;
  final recordHistory = <GameRecord>[].obs;

  final questText = '스쿼트하면 스마엉이 공격해요';
  final feedbackText = '카메라에 전신을 맞추고 앉았다 일어나 주세요'.obs;

  DateTime _lastTick = DateTime.now();
  DateTime _lastAttackAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastMonsterAttackAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _currentSquatResultSaved = false;

  double get todayBurnedCalories {
    final now = DateTime.now();
    return recordHistory
        .where((record) =>
            record.createdAt.year == now.year &&
            record.createdAt.month == now.month &&
            record.createdAt.day == now.day)
        .fold(0.0, (total, record) => total + record.calories);
  }

  double get todayRemainingCalories =>
      max(0.0, dailyCalorieGoal - todayBurnedCalories);
  double _lastMotionY = 0.0;
  int _squatFrames = 0;
  int _standFrames = 0;
  bool _hasReachedSquatDepth = false;

  void _updateSafely(void Function() update) {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => update());
      return;
    }

    update();
  }

  void registerFrame() {
    _updateSafely(() {
      processedFrames.value++;
    });
  }

  void updatePoseCount(int count) {
    _updateSafely(() {
      detectedPoseCount.value = count;
      if (count == 0) {
        squatPower.value = 0.0;
        feedbackText.value = '전신이 보이도록 카메라에 맞춰 주세요';
      }
    });
  }

  void updateMotion({
    required bool squat,
    required double lateral,
    required double hipY,
  }) {
    _updateSafely(() {
      final now = DateTime.now();
      final elapsed = max(
        0.08,
        now.difference(_lastTick).inMilliseconds / 1000.0,
      );
      _lastTick = now;

      final bodyMovement =
          _lastMotionY == 0.0 ? 0.0 : (_lastMotionY - hipY).abs();
      _lastMotionY = hipY;

      final poseRpmFloor = detectedPoseCount.value > 0 ? 4.0 : 0.0;
      final rawRpm = bodyMovement / elapsed * 4.0;
      final rpm = max(poseRpmFloor, rawRpm).clamp(0.0, 160.0).toDouble();
      currentRPM.value = currentRPM.value * 0.65 + rpm * 0.35;

      lateralOffset.value = lateral.clamp(0.0, 1.0).toDouble();
      if (detectedPoseCount.value > 0 &&
          hipY > 0 &&
          lateralOffset.value >= 0.18 &&
          lateralOffset.value <= 0.82) {
        correctPostureFrames.value++;
      }

      if (squat) {
        _squatFrames++;
        _standFrames = 0;
      } else {
        _standFrames++;
        _squatFrames = 0;
      }

      final stableSquat = _squatFrames >= 3;
      final stableStand = _standFrames >= 4;

      isSquatting.value = stableSquat;
      squatPower.value = (stableSquat
              ? 100.0
              : stableStand
                  ? 0.0
                  : 45.0)
          .toDouble();

      if (stableSquat) {
        _hasReachedSquatDepth = true;
      }

      final attackReady = now.difference(_lastAttackAt).inMilliseconds >= 650;
      final shouldAttack = detectedPoseCount.value > 0 &&
          stableStand &&
          _hasReachedSquatDepth &&
          attackReady;

      if (shouldAttack) {
        _lastAttackAt = now;
        _hasReachedSquatDepth = false;
        attackTick.value++;
        squatCount.value++;
        raceProgress.value = (squatCount.value / targetSquatCount.value)
            .clamp(0.0, 1.0)
            .toDouble();
        boosterGauge.value =
            (boosterGauge.value + 0.10).clamp(0.0, 1.0).toDouble();
        monsterHp.value = (monsterHp.value - (1.0 / targetSquatCount.value))
            .clamp(0.0, 1.0)
            .toDouble();
        feedbackText.value = '스쿼트 1회 완료! 다시 앉으면 다음 공격 준비';
      } else if (detectedPoseCount.value > 0) {
        if (_hasReachedSquatDepth) {
          feedbackText.value = '좋아요! 끝까지 일어나면 스쿼트가 기록돼요';
        } else if (stableSquat) {
          feedbackText.value = '스쿼트 자세 유지 중';
        } else {
          feedbackText.value = '앉았다 일어나며 스쿼트를 해주세요';
        }
      } else {
        feedbackText.value = '전신이 보이도록 카메라에 맞춰 주세요';
      }

      totalCalories.value +=
          (currentRPM.value * 0.00035) + (shouldAttack ? 0.03 : 0.003);
    });
  }

  void useBooster() {
    _updateSafely(() {
      if (boosterGauge.value < 1.0) return;

      boosterGauge.value = 0.0;
      attackTick.value++;
      monsterHp.value = (monsterHp.value - 0.16).clamp(0.0, 1.0).toDouble();
      feedbackText.value = '부스터 젤 공격 발사!';
    });
  }

  void saveCurrentResult() {
    _updateSafely(() {
      final hasResult = squatCount.value > 0 ||
          totalCalories.value > 0 ||
          correctPostureFrames.value > 0;
      hasSavedRecord.value = hasResult || recordHistory.isNotEmpty;
      savedCalories.value = totalCalories.value;
      savedSquatCount.value = squatCount.value;
      savedHeartRate.value =
          (72 + currentRPM.value * 0.45).clamp(72.0, 145.0).round();
      savedCorrectPostureFrames.value = correctPostureFrames.value;

      if (!hasResult || _currentSquatResultSaved) return;
      _currentSquatResultSaved = true;
      recordHistory.insert(
        0,
        GameRecord(
          mode: '스쿼트',
          primaryLabel: '스쿼트',
          primaryValue: '${squatCount.value}회',
          secondaryLabel: '칼로리',
          secondaryValue: '${totalCalories.value.toStringAsFixed(1)} kcal',
          createdAt: DateTime.now(),
          completed: squatCount.value >= targetSquatCount.value,
          calories: totalCalories.value,
        ),
      );
      hasSavedRecord.value = true;
    });
  }

  void saveJumpRunResult({
    required int cactusCount,
    required int jumpCount,
    required int targetCount,
    required bool completed,
  }) {
    _updateSafely(() {
      final calories = cactusCount * 0.4 + jumpCount * 0.08;
      hasSavedRecord.value = true;
      savedSquatCount.value = cactusCount;
      savedCalories.value = calories;
      savedHeartRate.value = (82 + jumpCount * 3).clamp(82, 148).round();
      savedCorrectPostureFrames.value = jumpCount;
      recordHistory.insert(
        0,
        GameRecord(
          mode: '사막 달리기',
          primaryLabel: '선인장',
          primaryValue: '$cactusCount/$targetCount개',
          secondaryLabel: '점프',
          secondaryValue: '$jumpCount회',
          createdAt: DateTime.now(),
          completed: completed,
          calories: calories,
        ),
      );
    });
  }

  void tickWithoutPose() {
    _updateSafely(() {
      currentRPM.value *= 0.92;
      squatPower.value *= 0.86;
      totalCalories.value += 0.001;

      final now = DateTime.now();
      final monsterReady =
          now.difference(_lastMonsterAttackAt).inMilliseconds >= 1900;
      if (monsterReady && monsterHp.value > 0.04) {
        _lastMonsterAttackAt = now;
        monsterAttackTick.value++;
      }
    });
  }

  void resetGame() {
    _updateSafely(() {
      currentRPM.value = 0.0;
      squatPower.value = 0.0;
      isSquatting.value = false;
      lateralOffset.value = 0.5;
      boosterGauge.value = 0.0;
      totalCalories.value = 0.0;
      squatCount.value = 0;
      raceProgress.value = 0.0;
      monsterHp.value = 1.0;
      detectedPoseCount.value = 0;
      processedFrames.value = 0;
      correctPostureFrames.value = 0;
      attackTick.value = 0;
      monsterAttackTick.value = 0;
      _currentSquatResultSaved = false;

      feedbackText.value = '카메라에 전신을 맞추고 앉았다 일어나 주세요';

      _lastTick = DateTime.now();
      _lastAttackAt = DateTime.fromMillisecondsSinceEpoch(0);
      _lastMonsterAttackAt = DateTime.now();
      _lastMotionY = 0.0;
      _squatFrames = 0;
      _standFrames = 0;
      _hasReachedSquatDepth = false;
    });
  }

  void setTargetSquatCount(int count) {
    targetSquatCount.value = count.clamp(10, 100);
  }

  void setCharacter(GameCharacter character) {
    selectedCharacter.value = character;
  }
}
