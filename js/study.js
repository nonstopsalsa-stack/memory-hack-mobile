/**
 * study.js - MEMORY HACK Mobile 学習マネージャー
 * 
 * 主要機能:
 * 1. 3階層ジャンルフィルター連動 (Hierarchy.matchesFilter)
 * 2. PCアプリ完全準拠の5大出題モード (due, all_random, weak, mistakes_today, sequence)
 * 3. 解答なし前後移動（左右タッチスワイプ ＆ 前へ/次へナビゲーションボタン）
 * 4. 忘却曲線 (SRS / SM-2) 計算と自動インターバル設定
 * 5. 誤答完全クリア特訓 (サバイバルループ)
 */

const StudyManager = {
  cards: [],
  queue: [],
  currentIndex: 0,
  currentCard: null,
  currentPattern: 'en_to_ja',
  isFlipped: false,
  showAdvice: false,

  // 学習フィルター & モード
  selectedFilter: { level1: 'all', level2: 'all', level3: 'all' },
  filterMode: 'all_random', // 'due' | 'all_random' | 'weak' | 'mistakes_today' | 'sequence'
  itemTypeFilter: 'all',     // 'all' | 'word' | 'sentence'
  activePatterns: ['en_to_ja', 'ja_to_en', 'audio_to_ja', 'audio_to_en', 'ja_to_audio', 'en_to_audio'],
  autoPlayAudio: true,

  // 誤答完全クリア特訓用状態
  isDrillMode: false,
  drillRemainingIds: new Set(),
  drillInitialTotal: 0,

  // セッション統計
  stats: {
    totalAnswered: 0,
    correctCount: 0,
    wrongCount: 0,
    sessionStartTime: null
  },

  // スワイプ操作用座標追跡
  touchState: {
    startX: 0,
    startY: 0,
    currentX: 0,
    isSwiping: false,
    startTime: 0
  },

  async init() {
    this.cards = await Storage.getAllCards();

    // 1. 設定の復元
    const savedPatterns = await Storage.getSetting('study_active_patterns', null);
    if (savedPatterns && Array.isArray(savedPatterns) && savedPatterns.length > 0) {
      this.activePatterns = savedPatterns;
    }

    this.selectedFilter = await Storage.getFilterState();
    this.filterMode = await Storage.getSetting('study_filter_mode', 'all_random');
    this.itemTypeFilter = await Storage.getSetting('study_item_type_filter', 'all');
    this.autoPlayAudio = await Storage.getSetting('study_auto_play_audio', true);

    // 2. UI同期
    this.updateDeckTriggerButton();
    this.syncFilterModeUI();
    this.renderPatternSelector();

    // 3. 出題キュー構築 & 開始
    await this.buildQueue();
    this.showNextCard();

    // 4. スワイプイベントリスナーの登録
    this.initSwipeListeners();
  },

  async onDeckLoaded(newCards) {
    this.cards = newCards;
    this.updateDeckTriggerButton();
    await this.buildQueue();
    this.showNextCard();
  },

  /**
   * デッキ選択トリガーボタンの表示更新
   */
  updateDeckTriggerButton() {
    const labelEl = document.getElementById('deck-select-label');
    if (labelEl) {
      labelEl.innerText = Hierarchy.formatBreadcrumb(this.selectedFilter);
    }
  },

  /**
   * 出題モードセレクターのUI同期
   */
  syncFilterModeUI() {
    const select = document.getElementById('study-filter-mode');
    if (select) {
      select.value = this.filterMode;
    }
  },

  /**
   * 出題モード変更
   */
  async setFilterMode(mode) {
    this.filterMode = mode;
    await Storage.saveSetting('study_filter_mode', mode);
    this.syncFilterModeUI();
    await this.buildQueue();
    this.showNextCard();
  },

  /**
   * 階層フィルター変更
   */
  async setHierarchyFilter(filter) {
    this.selectedFilter = filter;
    await Storage.saveFilterState(filter);
    this.updateDeckTriggerButton();
    await this.buildQueue();
    this.showNextCard();
  },

  /**
   * 出題パターン設定ボタンの表示更新
   */
  renderPatternSelector() {
    const btn = document.getElementById('pattern-btn-count');
    if (btn) {
      btn.innerText = `${this.activePatterns.length}/6`;
    }

    const checkboxes = document.querySelectorAll('input[name="pattern_checkbox"]');
    const set = new Set(this.activePatterns);
    checkboxes.forEach(cb => {
      cb.checked = set.has(cb.value);
    });
  },

  /**
   * 出題キューの生成（5大モード完全対応）
   */
  async buildQueue() {
    // 1. 3階層ジャンルフィルター適用
    let filtered = this.cards.filter(c => Hierarchy.matchesFilter(c, this.selectedFilter));

    // 2. 単語 / 文章フィルター適用
    if (this.itemTypeFilter === 'word') {
      filtered = filtered.filter(c => {
        const type = (c.itemType || '').toLowerCase();
        if (type === 'word' || type === 'phrase') return true;
        const front = (c.front || '').trim();
        return !front.endsWith('.') && !front.endsWith('?') && !front.endsWith('!') && front.split(/\s+/).length <= 4;
      });
    } else if (this.itemTypeFilter === 'sentence') {
      filtered = filtered.filter(c => {
        const type = (c.itemType || '').toLowerCase();
        if (type === 'sentence') return true;
        const front = (c.front || '').trim();
        return front.endsWith('.') || front.endsWith('?') || front.endsWith('!') || front.split(/\s+/).length > 4;
      });
    }

    // 3. 5大出題モード別のキュー選定
    if (this.filterMode === 'mistakes_today') {
      // 4. 誤答完全クリア特訓 (mistakes_today)
      const mistakeItems = await Storage.getTodayMistakes();
      if (mistakeItems.length === 0) {
        this.isDrillMode = false;
        this.queue = [];
        this.currentIndex = 0;
        this.renderEmptyState('🎉 素晴らしい！ 本日の誤答カードはありません。<br><small style="color:var(--color-text-sub); display:block; margin-top:0.4rem;">（通常学習で間違えたカードが出ると自動でここにストックされ、完全クリア特訓ができます）</small>');
        return;
      }

      // 該当階層に絞り込み
      let mistakeCards = mistakeItems.map(m => m.card || m);
      if (this.selectedFilter && this.selectedFilter.level1 && this.selectedFilter.level1 !== 'all') {
        mistakeCards = mistakeCards.filter(c => Hierarchy.matchesFilter(c, this.selectedFilter));
      }

      if (mistakeCards.length === 0) {
        this.isDrillMode = false;
        this.queue = [];
        this.currentIndex = 0;
        this.renderEmptyState(`🎉 選択中のデッキ（${Hierarchy.formatBreadcrumb(this.selectedFilter)}）には本日の誤答カードはありません！`);
        return;
      }

      this.isDrillMode = true;
      this.drillInitialTotal = mistakeCards.length;
      this.drillRemainingIds = new Set(mistakeCards.map(c => c.id || `${c.front}_${c.back}`));
      this.queue = this.shuffle([...mistakeCards]);

    } else {
      this.isDrillMode = false;
      this.drillRemainingIds.clear();

      if (filtered.length === 0) {
        this.queue = [];
        this.currentIndex = 0;
        this.renderEmptyState(`📭 「${Hierarchy.formatBreadcrumb(this.selectedFilter)}」にはカードがありません。`);
        return;
      }

      if (this.filterMode === 'due') {
        // 1. 忘却曲線の期日順 (due)
        const dueCards = filtered.filter(c => (typeof SRS !== 'undefined' ? SRS.isDue(c) : true));
        if (dueCards.length === 0) {
          // 期日到来カードがない場合、全問ランダムで学習を開始
          if (typeof App !== 'undefined' && App.showToast) {
            App.showToast('ℹ️ 本日復習期日のカードはありません。全問ランダムで開始します。', 'info');
          }
          this.queue = this.shuffle([...filtered]);
        } else {
          this.queue = this.shuffle([...dueCards]);
        }

      } else if (this.filterMode === 'weak') {
        // 3. 苦手カード優先 (weak)
        this.queue = [...filtered].sort((a, b) => {
          const accA = typeof SRS !== 'undefined' ? SRS.getAccuracy(a) : 0;
          const accB = typeof SRS !== 'undefined' ? SRS.getAccuracy(b) : 0;
          if (accA !== accB) return accA - accB;
          const streakA = (a.streak !== undefined ? a.streak : a.repetitionLevel) || 0;
          const streakB = (b.streak !== undefined ? b.streak : b.repetitionLevel) || 0;
          return streakA - streakB;
        });

      } else if (this.filterMode === 'sequence') {
        // 5. シーケンス順出題 (sequence)
        this.queue = this.buildSequenceQueue(filtered);
        if (this.queue.length === 0) {
          this.queue = this.shuffle([...filtered]);
        }

      } else {
        // 2. 全問ランダム (all_random)
        this.queue = this.shuffle([...filtered]);
      }
    }

    this.currentIndex = 0;
    this.stats = { totalAnswered: 0, correctCount: 0, wrongCount: 0, sessionStartTime: Date.now() };
    this.updateStatsUI();
  },

  /**
   * シーケンスモード用の出題キューを構築（PCアプリ完全準拠）
   */
  buildSequenceQueue(cards) {
    if (!cards || cards.length === 0) return [];

    // 1. デッキごとにグループ化
    const deckMap = new Map();
    cards.forEach(c => {
      Hierarchy.normalizeCard(c);
      const dKey = c.deck || '一般';
      if (!deckMap.has(dKey)) {
        deckMap.set(dKey, []);
      }
      deckMap.get(dKey).push(c);
    });

    const sequenceSets = [];
    const blankCards = [];

    deckMap.forEach((deckCards) => {
      const seqItems = [];
      deckCards.forEach(c => {
        const rawSeq = c.sequenceNo;
        const num = (rawSeq !== undefined && rawSeq !== null && String(rawSeq).trim() !== '') ? Number(rawSeq) : null;
        if (Number.isFinite(num) && num > 0) {
          seqItems.push({ card: c, num });
        } else {
          blankCards.push(c);
        }
      });

      if (seqItems.length > 0) {
        seqItems.sort((a, b) => a.num - b.num);
        sequenceSets.push(seqItems.map(item => item.card));
      }
    });

    // シーケンスカードが1枚もない場合 ➔ 忘却曲線期日順 or シャッフル
    if (sequenceSets.length === 0) {
      const dueCards = cards.filter(c => (typeof SRS !== 'undefined' ? SRS.isDue(c) : true));
      return dueCards.length > 0 ? this.shuffle([...dueCards]) : this.shuffle([...cards]);
    }

    // 2. 複数セット存在する場合、セット単位でランダムシャッフル
    this.shuffle(sequenceSets);

    // 3. 各セットを1〜Nまで展開してキューに結合
    const finalQueue = [];
    sequenceSets.forEach(set => {
      finalQueue.push(...set);
    });

    // 4. 空欄カードがある場合、復習期日が到来しているものを末尾に追加
    const dueBlankCards = blankCards.filter(c => (typeof SRS !== 'undefined' ? SRS.isDue(c) : false));
    if (dueBlankCards.length > 0) {
      dueBlankCards.sort((a, b) => new Date(a.dueDate || 0) - new Date(b.dueDate || 0));
      finalQueue.push(...dueBlankCards);
    }

    return finalQueue;
  },

  shuffle(arr) {
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
  },

  /**
   * 次のカードを表示
   */
  showNextCard() {
    if (this.queue.length === 0) {
      return;
    }

    if (this.currentIndex >= this.queue.length) {
      this.renderCompletedState();
      return;
    }

    this.currentCard = this.queue[this.currentIndex];
    this.isFlipped = false;
    this.showAdvice = false;

    // 出題パターンを抽選
    this.pickCurrentPattern();

    // 画面描画
    this.renderCard();

    // 音声の自動再生処理
    if (this.autoPlayAudio && (this.currentPattern === 'audio_to_ja' || this.currentPattern === 'audio_to_en')) {
      setTimeout(() => {
        this.playCardAudio();
      }, 250);
    }
  },

  pickCurrentPattern() {
    const patterns = (this.activePatterns && this.activePatterns.length > 0)
      ? this.activePatterns
      : ['en_to_ja'];
    const idx = Math.floor(Math.random() * patterns.length);
    this.currentPattern = patterns[idx];
  },

  /**
   * カードのめくり（表 ➔ 裏）
   */
  flipCard() {
    if (this.isFlipped) return;
    this.isFlipped = true;
    this.renderCard();

    if (this.autoPlayAudio && (this.currentPattern === 'ja_to_en' || this.currentPattern === 'ja_to_audio' || this.currentPattern === 'en_to_audio')) {
      setTimeout(() => {
        this.playCardAudio();
      }, 200);
    }
  },

  // =========================================================================
  // 解答を選ばずに前後のカードへパラパラめくる機能（非破壊ナビゲーション）
  // =========================================================================

  /**
   * 解答なしで「次のカード」へ移動（スワイプまたは次へボタン）
   */
  goToNextCardWithoutGrading() {
    if (this.queue.length === 0) return;

    if (this.currentIndex < this.queue.length - 1) {
      this.currentIndex++;
      this.currentCard = this.queue[this.currentIndex];
      this.isFlipped = false;
      this.showAdvice = false;
      this.pickCurrentPattern();
      this.renderCard();
      this.updateStatsUI();

      if (this.autoPlayAudio && (this.currentPattern === 'audio_to_ja' || this.currentPattern === 'audio_to_en')) {
        setTimeout(() => { this.playCardAudio(); }, 250);
      }
    } else {
      if (typeof App !== 'undefined' && App.showToast) {
        App.showToast('ℹ️ これが最後のカードです', 'info');
      }
    }
  },

  /**
   * 解答なしで「前のカード」へ移動（スワイプまたは前へボタン）
   */
  goToPrevCardWithoutGrading() {
    if (this.queue.length === 0) return;

    if (this.currentIndex > 0) {
      this.currentIndex--;
      this.currentCard = this.queue[this.currentIndex];
      this.isFlipped = false;
      this.showAdvice = false;
      this.pickCurrentPattern();
      this.renderCard();
      this.updateStatsUI();

      if (this.autoPlayAudio && (this.currentPattern === 'audio_to_ja' || this.currentPattern === 'audio_to_en')) {
        setTimeout(() => { this.playCardAudio(); }, 250);
      }
    } else {
      if (typeof App !== 'undefined' && App.showToast) {
        App.showToast('ℹ️ 先頭のカードです', 'info');
      }
    }
  },

  /**
   * 回答ボタン処理（⭕ 正解 / ❌ 不正解）
   */
  async recordAnswer(isCorrect) {
    if (!this.currentCard) return;

    this.stats.totalAnswered++;
    const cardId = this.currentCard.id || `${this.currentCard.front}_${this.currentCard.back}`;

    // 1. SRS (忘却曲線) パラメータ更新
    if (typeof SRS !== 'undefined') {
      this.currentCard = SRS.processReview(this.currentCard, isCorrect);
    } else {
      if (isCorrect) {
        this.currentCard.repetitionLevel = (this.currentCard.repetitionLevel || 0) + 1;
      } else {
        this.currentCard.repetitionLevel = 0;
      }
    }

    // 2. 正解 / 不正解処理 & 誤答ストック同期
    if (isCorrect) {
      this.stats.correctCount++;

      // 特訓モード中なら残り誤答リストからクリア
      if (this.isDrillMode) {
        this.drillRemainingIds.delete(cardId);
        await Storage.removeTodayMistake(cardId);
      }
    } else {
      this.stats.wrongCount++;

      // 本日の誤答ストックへ保存
      await Storage.recordTodayMistake(this.currentCard, this.currentPattern);

      // 特訓モードまたは通常モードで再復習用にキューの少し後ろ（3〜4問後）に再挿入
      const insertIdx = Math.min(this.queue.length, this.currentIndex + 4);
      this.queue.splice(insertIdx, 0, this.currentCard);
    }

    // 3. カード情報の永続化
    await Storage.updateCard(this.currentCard);

    // 4. 次のカードへ進む
    this.currentIndex++;
    this.updateStatsUI();
    this.showNextCard();
  },

  /**
   * 音声再生
   */
  playCardAudio() {
    if (!this.currentCard) return;
    const textToSpeak = this.currentCard.front || '';
    AudioManager.speak(textToSpeak);
  },

  /**
   * 例文の音声再生
   */
  playExampleAudio() {
    if (!this.currentCard || !this.currentCard.example) return;
    AudioManager.speak(this.currentCard.example);
  },

  /**
   * カードの描画
   */
  renderCard() {
    const container = document.getElementById('card-stage');
    if (!container || !this.currentCard) return;

    const card = this.currentCard;
    const pattern = this.currentPattern;
    const patternInfo = this.getPatternInfo(pattern);

    let questionHtml = '';
    let answerHtml = '';

    const isAudioMode = (pattern === 'audio_to_ja' || pattern === 'audio_to_en');

    if (!this.isFlipped) {
      // ===== 表面（問題） =====
      if (isAudioMode) {
        questionHtml = `
          <div class="audio-prompt-box" onclick="StudyManager.playCardAudio(); event.stopPropagation();">
            <span class="audio-pulse-icon">🔊</span>
            <div class="audio-prompt-text">タップして発音を聞く</div>
          </div>
        `;
      } else if (pattern === 'ja_to_en' || pattern === 'ja_to_audio') {
        questionHtml = `<div class="card-prompt-text ja">${escapeHtml(card.back)}</div>`;
      } else {
        questionHtml = `<div class="card-prompt-text en">${escapeHtml(card.front)}</div>`;
      }
    } else {
      // ===== 裏面（解答） =====
      answerHtml = `
        <div class="card-answer-block">
          <div class="card-answer-row">
            <div class="card-answer-main ${pattern === 'ja_to_en' ? 'en' : 'ja'}">
              ${escapeHtml(pattern === 'ja_to_en' ? card.front : card.back)}
            </div>
            <button class="speaker-btn" onclick="StudyManager.playCardAudio(); event.stopPropagation();" title="発音を聞く">
              🔊
            </button>
          </div>
          <div class="card-answer-sub">
            ${escapeHtml(pattern === 'ja_to_en' ? card.back : card.front)}
          </div>
        </div>

        ${card.example ? `
          <div class="example-box">
            <div class="example-header">
              <span class="example-badge">例文</span>
              <button class="example-speaker-btn" onclick="StudyManager.playExampleAudio(); event.stopPropagation();">🔊</button>
            </div>
            <div class="example-en">${escapeHtml(card.example)}</div>
            ${card.exampleTranslation ? `<div class="example-ja">${escapeHtml(card.exampleTranslation)}</div>` : ''}
          </div>
        ` : ''}

        ${card.advice ? `
          <div class="advice-accordion ${this.showAdvice ? 'expanded' : ''}" onclick="StudyManager.toggleAdvice(); event.stopPropagation();">
            <div class="advice-header">
              <span class="advice-title">💡 攻略アドバイス・AI解説</span>
              <span class="advice-arrow">${this.showAdvice ? '▲' : '▼'}</span>
            </div>
            ${this.showAdvice ? `<div class="advice-body">${escapeHtml(card.advice)}</div>` : ''}
          </div>
        ` : ''}
      `;
    }

    const modeBadge = this.isDrillMode
      ? `<span class="drill-mode-badge">🎯 特訓中 (残り${this.drillRemainingIds.size}枚)</span>`
      : '';

    const canGoPrev = this.currentIndex > 0;
    const canGoNext = this.currentIndex < this.queue.length - 1;

    container.innerHTML = `
      <div class="study-card-wrapper" id="study-card-wrapper">
        <div class="study-card ${this.isFlipped ? 'is-flipped' : ''}" onclick="StudyManager.flipCard();">
          <div class="card-top-info">
            <div class="quest-badge ${patternInfo.badgeClass}">
              ${patternInfo.badgeText}
            </div>
            <div class="card-top-right">
              ${modeBadge}
              <div class="deck-tag">${escapeHtml(card.deck || card.category1 || 'デッキ')}</div>
            </div>
          </div>

          <div class="card-body">
            ${!this.isFlipped ? questionHtml : answerHtml}
          </div>

          <div class="card-flip-hint">
            ${!this.isFlipped ? '👉 カードまたは画面下のボタンをタップして答えを表示' : '👈👉 左右スワイプで前後のカードへ移動'}
          </div>
        </div>

        <!-- パラパラめくりナビゲーションバー（解答履歴を汚さずに移動） -->
        <div class="card-browse-nav">
          <button class="btn-browse-nav prev ${!canGoPrev ? 'disabled' : ''}" 
            onclick="StudyManager.goToPrevCardWithoutGrading(); event.stopPropagation();"
            ${!canGoPrev ? 'disabled' : ''} title="前のカード (記録なし)">
            ◀ 前へ
          </button>

          <span class="browse-counter">
            ${this.currentIndex + 1} / ${this.queue.length}
          </span>

          <button class="btn-browse-nav next ${!canGoNext ? 'disabled' : ''}" 
            onclick="StudyManager.goToNextCardWithoutGrading(); event.stopPropagation();"
            ${!canGoNext ? 'disabled' : ''} title="次のカード (記録なし)">
            次へ ▶
          </button>
        </div>
      </div>
    `;

    // 操作ボタンの更新
    this.updateBottomActionButtons();
  },

  toggleAdvice() {
    this.showAdvice = !this.showAdvice;
    this.renderCard();
  },

  updateBottomActionButtons() {
    const actionContainer = document.getElementById('bottom-action-bar');
    if (!actionContainer) return;

    if (!this.isFlipped) {
      // めくる前: 巨大な「答えを見る」ボタン
      actionContainer.innerHTML = `
        <button class="btn-action btn-flip" onclick="StudyManager.flipCard();">
          <span class="action-icon">👀</span> 答えを見る (FLIP)
        </button>
      `;
    } else {
      // めくった後: ❌ 不正解 と ⭕ 正解 ボタン
      actionContainer.innerHTML = `
        <button class="btn-action btn-wrong" onclick="StudyManager.recordAnswer(false);">
          <span class="action-icon">❌</span> もう一度
        </button>
        <button class="btn-action btn-correct" onclick="StudyManager.recordAnswer(true);">
          <span class="action-icon">⭕</span> 覚えた！
        </button>
      `;
    }
  },

  getPatternInfo(pattern) {
    switch (pattern) {
      case 'en_to_ja':
        return { badgeText: '⚔️ QUEST: 日本語の意味を言え！', badgeClass: 'badge-en-ja' };
      case 'ja_to_en':
        return { badgeText: '🛡️ QUEST: 英語で発音・英訳せよ！', badgeClass: 'badge-ja-en' };
      case 'audio_to_ja':
        return { badgeText: '🎧 QUEST: 音声を聞いて意味を答えよ！', badgeClass: 'badge-audio-ja' };
      case 'audio_to_en':
        return { badgeText: '✍️ QUEST: 音声を聞いて英語を答えよ！', badgeClass: 'badge-audio-en' };
      case 'ja_to_audio':
        return { badgeText: '🗣️ QUEST: 日本語から英語を発音せよ！', badgeClass: 'badge-ja-audio' };
      case 'en_to_audio':
        return { badgeText: '🔊 QUEST: 正しい発音をチェックせよ！', badgeClass: 'badge-en-audio' };
      default:
        return { badgeText: 'QUEST', badgeClass: 'badge-default' };
    }
  },

  updateStatsUI() {
    const progressEl = document.getElementById('session-progress-text');
    const progressBar = document.getElementById('session-progress-bar');
    const accuracyEl = document.getElementById('session-accuracy-text');

    const total = this.queue.length;
    const current = Math.min(this.currentIndex + 1, total);
    const pct = total > 0 ? Math.round((this.currentIndex / total) * 100) : 0;

    if (progressEl) progressEl.innerText = `${this.currentIndex} / ${total}`;
    if (progressBar) progressBar.style.width = `${pct}%`;

    const answered = this.stats.totalAnswered;
    const acc = answered > 0 ? Math.round((this.stats.correctCount / answered) * 100) : 100;
    if (accuracyEl) accuracyEl.innerText = `${acc}% 正解`;
  },

  renderEmptyState(message) {
    const container = document.getElementById('card-stage');
    if (!container) return;

    const defaultMsg = '上部の「同期」ボタンを押して、Master Systemから最新カードを読み込んでください。';
    const msg = message || defaultMsg;

    container.innerHTML = `
      <div class="empty-state-box">
        <div class="empty-icon">📭</div>
        <h3>カードがありません</h3>
        <p>${msg}</p>
        <button class="btn-sync-action" onclick="SyncManager.pullDeck();">🔄 クラウドから同期</button>
      </div>
    `;
    const actionContainer = document.getElementById('bottom-action-bar');
    if (actionContainer) actionContainer.innerHTML = '';
  },

  renderCompletedState() {
    const container = document.getElementById('card-stage');
    if (!container) return;

    const answered = this.stats.totalAnswered;
    const correct = this.stats.correctCount;
    const acc = answered > 0 ? Math.round((correct / answered) * 100) : 100;

    const titleText = this.isDrillMode ? '特訓クリア達成！' : 'QUEST COMPLETE!';
    const subText = this.isDrillMode ? '本日の誤答カードをすべて克服しました！' : 'すべてのカードを完了しました！';

    container.innerHTML = `
      <div class="completed-box">
        <div class="completed-icon">🏆</div>
        <h2>${titleText}</h2>
        <p>${subText}</p>
        <div class="completed-stats-grid">
          <div class="c-stat-box">
            <span class="c-stat-label">出題数</span>
            <span class="c-stat-val">${answered}</span>
          </div>
          <div class="c-stat-box">
            <span class="c-stat-label">正解数</span>
            <span class="c-stat-val text-correct">${correct}</span>
          </div>
          <div class="c-stat-box">
            <span class="c-stat-label">正答率</span>
            <span class="c-stat-val text-gold">${acc}%</span>
          </div>
        </div>
        <button class="btn-restart" onclick="StudyManager.buildQueue().then(() => StudyManager.showNextCard());">🔁 もう一度学習する</button>
      </div>
    `;
    const actionContainer = document.getElementById('bottom-action-bar');
    if (actionContainer) actionContainer.innerHTML = '';
  },

  // =========================================================================
  // スワイプジェスチャー処理 (タッチイベント)
  // =========================================================================

  initSwipeListeners() {
    const stage = document.getElementById('card-stage');
    if (!stage) return;

    stage.addEventListener('touchstart', (e) => {
      const touch = e.touches[0];
      this.touchState.startX = touch.clientX;
      this.touchState.startY = touch.clientY;
      this.touchState.currentX = touch.clientX;
      this.touchState.startTime = Date.now();
      this.touchState.isSwiping = false;
    }, { passive: true });

    stage.addEventListener('touchmove', (e) => {
      if (!this.touchState.startX) return;
      const touch = e.touches[0];
      const deltaX = touch.clientX - this.touchState.startX;
      const deltaY = touch.clientY - this.touchState.startY;

      // 水平方向のスワイプが垂直スクロールよりも優位な場合
      if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 15) {
        this.touchState.isSwiping = true;
        this.touchState.currentX = touch.clientX;

        // カードを指に追従して少し傾け・スライド
        const cardWrapper = document.getElementById('study-card-wrapper');
        if (cardWrapper) {
          const moveX = Math.min(80, Math.max(-80, deltaX * 0.4));
          const rotateDeg = moveX * 0.05;
          cardWrapper.style.transform = `translateX(${moveX}px) rotate(${rotateDeg}deg)`;
          cardWrapper.style.transition = 'none';
        }
      }
    }, { passive: true });

    stage.addEventListener('touchend', (e) => {
      const cardWrapper = document.getElementById('study-card-wrapper');
      if (cardWrapper) {
        cardWrapper.style.transform = '';
        cardWrapper.style.transition = 'transform 0.2s ease';
      }

      if (!this.touchState.isSwiping) return;

      const deltaX = this.touchState.currentX - this.touchState.startX;
      const duration = Date.now() - this.touchState.startTime;

      this.touchState.isSwiping = false;
      this.touchState.startX = 0;
      this.touchState.currentX = 0;

      // スワイプ閾値: 50px以上かつ短時間でのフリック
      if (Math.abs(deltaX) > 50 && duration < 600) {
        if (deltaX < 0) {
          // 左スワイプ ➔ 次のカード
          this.goToNextCardWithoutGrading();
        } else {
          // 右スワイプ ➔ 前のカード
          this.goToPrevCardWithoutGrading();
        }
      }
    }, { passive: true });
  }
};

function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

if (typeof window !== 'undefined') {
  window.StudyManager = StudyManager;
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = StudyManager;
}
