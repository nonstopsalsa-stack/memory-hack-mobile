/**
 * study.js - MEMORY HACK Mobile 学習マネージャー
 * 出題パターン6種完全対応 & モバイル特有の片手操作・快適フリップ学習
 */

const StudyManager = {
  cards: [],
  queue: [],
  currentIndex: 0,
  currentCard: null,
  currentPattern: 'en_to_ja',
  isFlipped: false,
  showAdvice: false,

  // 学習設定
  activePatterns: ['en_to_ja', 'ja_to_en', 'audio_to_ja', 'audio_to_en', 'ja_to_audio', 'en_to_audio'],
  selectedDeck: 'all',
  itemTypeFilter: 'all', // 'all' | 'word' | 'sentence'
  filterMode: 'all_random', // 'all_random' | 'due' | 'weak'
  autoPlayAudio: true,

  // セッション統計
  stats: {
    totalAnswered: 0,
    correctCount: 0,
    wrongCount: 0,
    sessionStartTime: null
  },

  async init() {
    this.cards = await Storage.getAllCards();
    
    // 設定復元
    const savedPatterns = await Storage.getSetting('study_active_patterns', null);
    if (savedPatterns && Array.isArray(savedPatterns) && savedPatterns.length > 0) {
      this.activePatterns = savedPatterns;
    }
    this.selectedDeck = await Storage.getSetting('study_selected_deck', 'all');
    this.itemTypeFilter = await Storage.getSetting('study_item_type_filter', 'all');
    this.filterMode = await Storage.getSetting('study_filter_mode', 'all_random');
    this.autoPlayAudio = await Storage.getSetting('study_auto_play_audio', true);

    this.renderDeckSelector();
    this.renderPatternSelector();
    this.buildQueue();
    this.showNextCard();
  },

  async onDeckLoaded(newCards) {
    this.cards = newCards;
    this.renderDeckSelector();
    this.buildQueue();
    this.showNextCard();
  },

  /**
   * デッキ選択ドロップダウンの描画
   */
  renderDeckSelector() {
    const select = document.getElementById('deck-select');
    if (!select) return;

    const decks = new Set();
    this.cards.forEach(c => {
      const d = c.deck || c.category1 || '未分類';
      decks.add(d);
    });

    let html = `<option value="all">📚 すべてのデッキ (${this.cards.length}枚)</option>`;
    decks.forEach(d => {
      const count = this.cards.filter(c => (c.deck || c.category1 || '未分類') === d).length;
      html += `<option value="${escapeHtml(d)}">${escapeHtml(d)} (${count}枚)</option>`;
    });

    select.innerHTML = html;
    select.value = this.selectedDeck;
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
   * 出題キューの生成（フィルター & シャッフル）
   */
  buildQueue() {
    let filtered = [...this.cards];

    // デッキフィルター
    if (this.selectedDeck !== 'all') {
      filtered = filtered.filter(c => (c.deck || c.category1 || '未分類') === this.selectedDeck);
    }

    // 単語/文章フィルター
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

    // 抽出モード
    if (this.filterMode === 'weak') {
      filtered.sort((a, b) => (a.repetitionLevel || 0) - (b.repetitionLevel || 0));
    } else if (this.filterMode === 'all_random') {
      for (let i = filtered.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [filtered[i], filtered[j]] = [filtered[j], filtered[i]];
      }
    }

    this.queue = filtered;
    this.currentIndex = 0;
    this.stats = { totalAnswered: 0, correctCount: 0, wrongCount: 0, sessionStartTime: Date.now() };
    this.updateStatsUI();
  },

  /**
   * 次のカードを表示
   */
  showNextCard() {
    if (this.queue.length === 0) {
      this.renderEmptyState();
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

    // 裏面めくり時の自動発音（英語が答えの場合や確認）
    if (this.autoPlayAudio && (this.currentPattern === 'ja_to_en' || this.currentPattern === 'ja_to_audio' || this.currentPattern === 'en_to_audio')) {
      setTimeout(() => {
        this.playCardAudio();
      }, 200);
    }
  },

  /**
   * 回答ボタン処理（⭕ 正解 / ❌ 不正解）
   */
  async recordAnswer(isCorrect) {
    if (!this.currentCard) return;

    this.stats.totalAnswered++;
    if (isCorrect) {
      this.stats.correctCount++;
      this.currentCard.repetitionLevel = (this.currentCard.repetitionLevel || 0) + 1;
    } else {
      this.stats.wrongCount++;
      this.currentCard.repetitionLevel = 0;
      // 復習用にキューの少し後ろ（3〜5問後）に再挿入
      const insertIdx = Math.min(this.queue.length, this.currentIndex + 4);
      this.queue.splice(insertIdx, 0, this.currentCard);
    }

    this.currentCard.reviewCount = (this.currentCard.reviewCount || 0) + 1;
    this.currentCard.lastReviewedAt = new Date().toISOString();

    await Storage.updateCard(this.currentCard);

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

    // パターン情報
    const patternInfo = this.getPatternInfo(pattern);

    // 表裏に応じた表示コンテンツの組み立て
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

    container.innerHTML = `
      <div class="study-card ${this.isFlipped ? 'is-flipped' : ''}" onclick="StudyManager.flipCard();">
        <div class="card-top-info">
          <div class="quest-badge ${patternInfo.badgeClass}">
            ${patternInfo.badgeText}
          </div>
          <div class="deck-tag">${escapeHtml(card.deck || card.category1 || 'デッキ')}</div>
        </div>

        <div class="card-body">
          ${!this.isFlipped ? questionHtml : answerHtml}
        </div>

        <div class="card-flip-hint">
          ${!this.isFlipped ? '👉 カードまたは画面下のボタンをタップして答えを表示' : ''}
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

  renderEmptyState() {
    const container = document.getElementById('card-stage');
    if (!container) return;
    container.innerHTML = `
      <div class="empty-state-box">
        <div class="empty-icon">📭</div>
        <h3>カードがありません</h3>
        <p>上部の「同期」ボタンを押して、Master Systemから最新カードを読み込んでください。</p>
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

    container.innerHTML = `
      <div class="completed-box">
        <div class="completed-icon">🏆</div>
        <h2>QUEST COMPLETE!</h2>
        <p>すべてのカードを完了しました！</p>
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
        <button class="btn-restart" onclick="StudyManager.buildQueue(); StudyManager.showNextCard();">🔁 もう一度学習する</button>
      </div>
    `;
    const actionContainer = document.getElementById('bottom-action-bar');
    if (actionContainer) actionContainer.innerHTML = '';
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
