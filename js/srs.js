/**
 * srs.js - MEMORY HACK Mobile 忘却曲線（SM-2 / Spaced Repetition）計算モジュール
 * エビングハウスの忘却曲線に基づき、次回復習日・インターバル・習熟度を算出します。
 */

const SRS = {
  DEFAULT_EASE_FACTOR: 2.5,
  MIN_EASE_FACTOR: 1.3,

  /**
   * 新規カードのSRS初期データを生成
   */
  createInitialCardData() {
    const now = new Date().toISOString();
    return {
      repetitions: 0,       // 連続正解復習回数
      interval: 0,          // 次回復習までの日数
      easeFactor: this.DEFAULT_EASE_FACTOR, // 難易度係数 (EF)
      dueDate: now,         // 出題予定日時（ISO文字列）
      createdAt: now,       // 作成日
      lastReviewedAt: null, // 最終学習日
      totalReviews: 0,      // 総解答数
      correctReviews: 0,    // 正解数
      streak: 0,            // 現在の連続正解数
      maxStreak: 0,         // 過去最高連続正解数
      status: 'new',        // 'new' | 'learning' | 'reviewing' | 'mastered'
    };
  },

  /**
   * 回答結果（正解: isCorrect = true, 不正解: isCorrect = false）をもとに
   * カードのSRSパラメータと次回出題日を更新
   */
  processReview(card, isCorrect) {
    const updated = { ...card };
    const now = new Date();

    updated.totalReviews = (updated.totalReviews || 0) + 1;
    updated.lastReviewedAt = now.toISOString();

    let easeFactor = updated.easeFactor || this.DEFAULT_EASE_FACTOR;
    let repetitions = updated.repetitions || updated.repetitionLevel || 0;
    let interval = updated.interval || 0;
    let streak = updated.streak || 0;
    let maxStreak = updated.maxStreak || 0;

    if (isCorrect) {
      updated.correctReviews = (updated.correctReviews || 0) + 1;
      streak += 1;
      if (streak > maxStreak) {
        maxStreak = streak;
      }

      // SM-2 アルゴリズムのインターバル計算
      if (repetitions === 0) {
        interval = 1; // 初回正解時は翌日
      } else if (repetitions === 1) {
        interval = 3; // 2回目連続正解時は3日後
      } else {
        interval = Math.round(interval * easeFactor);
      }
      repetitions += 1;

      // 難易度係数の微調整 (正解時は少し易しく/間隔が広がりやすくなる)
      easeFactor = Math.max(this.MIN_EASE_FACTOR, easeFactor + 0.05);

    } else {
      // 不正解時は連続記録・反復回数をリセット
      streak = 0;
      repetitions = 0;
      interval = 1; // 明日（または再学習）すぐ出題

      // 難易度係数を下げる (より頻繁に出題されるように)
      easeFactor = Math.max(this.MIN_EASE_FACTOR, easeFactor - 0.2);
    }

    // 次回期日を計算 (今日 + interval 日)
    const nextDue = new Date(now.getTime() + interval * 24 * 60 * 60 * 1000);

    updated.repetitions = repetitions;
    updated.repetitionLevel = repetitions; // モバイル既存属性との互換性
    updated.interval = interval;
    updated.easeFactor = parseFloat(easeFactor.toFixed(2));
    updated.dueDate = nextDue.toISOString();
    updated.nextReviewDate = nextDue.toISOString(); // モバイル既存属性との互換性
    updated.streak = streak;
    updated.maxStreak = maxStreak;

    // 習熟度ステータスの判定
    updated.status = this.determineStatus(updated);

    return updated;
  },

  /**
   * 連続正解数や復習回数からステータスを判定
   */
  determineStatus(card) {
    if (!card.totalReviews || card.totalReviews === 0) {
      return 'new'; // 未学習
    }
    if (card.streak >= 6 && (card.interval || 0) >= 30) {
      return 'mastered'; // 完全定着 (1ヶ月以上記憶保持)
    }
    if (card.streak >= 3) {
      return 'reviewing'; // 定着中
    }
    return 'learning'; // 学習中
  },

  /**
   * カードが今日復習すべき対象（Due）かどうかを判定
   */
  isDue(card) {
    const dueStr = card.dueDate || card.nextReviewDate;
    if (!dueStr) return true;
    const now = new Date();
    const due = new Date(dueStr);
    return due <= now;
  },

  /**
   * 正答率 (%) を計算
   */
  getAccuracy(card) {
    if (!card.totalReviews || card.totalReviews === 0) return 0;
    return Math.round((card.correctReviews / card.totalReviews) * 100);
  },

  /**
   * 人間に読みやすい次回期日の表現を返す
   */
  formatDueDate(card) {
    const dueStr = card.dueDate || card.nextReviewDate;
    if (!dueStr) return '今すぐ';
    const now = new Date();
    const due = new Date(dueStr);
    const diffMs = due.getTime() - now.getTime();
    const diffHours = Math.round(diffMs / (1000 * 60 * 60));
    const diffDays = Math.round(diffMs / (1000 * 60 * 60 * 24));

    if (diffMs <= 0) return '今日（復習可能）';
    if (diffHours < 24) return `約${diffHours}時間後`;
    if (diffDays === 1) return '明日';
    return `${diffDays}日後 (${due.getMonth() + 1}/${due.getDate()})`;
  }
};

if (typeof window !== 'undefined') {
  window.SRS = SRS;
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = SRS;
}
