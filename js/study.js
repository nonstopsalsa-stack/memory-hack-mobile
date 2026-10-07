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
  version: 'v2.0.0',
  cards: [],
  queue: [],
  currentIndex: 0,
  currentCard: null,
  currentPattern: 'front_to_back',
  currentKanjiQuestion: null,
  isFlipped: false,
  showAdvice: false,

  // 汎用フラッシュカード用2大出題パターン定義
  UNIVERSAL_PATTERNS: {
    front_to_back: { name: '表 ➔ 裏', desc: '表面 (問題・用語) ➔ 裏面 (解答)', badgeClass: 'badge-en-ja', hint: '基本出題' },
    back_to_front: { name: '裏 ➔ 表', desc: '裏面 (解答) ➔ 表面 (問題想起)', badgeClass: 'badge-ja-en', hint: '逆引き想起' }
  },

  // 漢字専用6大出題パターン定義
  KANJI_PATTERNS: {
    char_to_read: { name: '字 ➔ 読', desc: '漢字一文字 ➔ 代表的な読み方', badgeClass: 'badge-en-ja', hint: '読み・意味' },
    read_to_char: { name: '読 ➔ 字', desc: '読み方（音訓ランダム） ➔ 漢字を書く ✍️', badgeClass: 'badge-ja-en', hint: '漢字書き取り' },
    word_to_read: { name: '語 ➔ 読', desc: '熟語（候補ランダム） ➔ 熟語の読み方', badgeClass: 'badge-audio-ja', hint: '熟語の読み' },
    read_to_word: { name: '読 ➔ 語', desc: '熟語の読み ➔ 熟語を書く ✍️', badgeClass: 'badge-audio-en', hint: '熟語書き取り' },
    sentence_fill: { name: '文 ➔ 字', desc: '例文穴埋め（［ ］を空欄化） ➔ 漢字を書く ✍️', badgeClass: 'badge-ja-audio', hint: '実戦穴埋め' },
    sentence_read: { name: '文 ➔ 読', desc: '例文傍線（対象語句を強調） ➔ 読みを答える', badgeClass: 'badge-en-audio', hint: '例文の読み' }
  },

  // 英語専用6大出題パターン定義 (後方互換)
  EN_PATTERNS: {
    en_to_ja: { name: '英 ➔ 日', desc: '英語 ➔ 日本語 (意味想起)', badgeClass: 'badge-en-ja', hint: '意味想起' },
    ja_to_en: { name: '日 ➔ 英', desc: '日本語 ➔ 英語 (瞬間英作文)', badgeClass: 'badge-ja-en', hint: '瞬間英作文' },
    audio_to_ja: { name: '音 ➔ 日', desc: '音声 ➔ 日本語 (リスニング)', badgeClass: 'badge-audio-ja', hint: 'リスニング' },
    audio_to_en: { name: '音 ➔ 英', desc: '音声 ➔ 英語 (ディクテーション)', badgeClass: 'badge-audio-en', hint: 'ディクテーション' },
    ja_to_audio: { name: '日 ➔ 音', desc: '日本語 ➔ 音声 (発音想起)', badgeClass: 'badge-ja-audio', hint: '発音想起' },
    en_to_audio: { name: '英 ➔ 音', desc: '英語 ➔ 音声 (フォニックス)', badgeClass: 'badge-en-audio', hint: 'フォニックス' }
  },

  /**
   * カードの対象言語コードを自動判定
   */
  getCardLanguage(card) {
    if (!card) return 'en-US';
    if (card.targetLanguage) return card.targetLanguage;
    const cat = `${card.category1 || ''} ${card.category2 || ''} ${card.category3 || ''} ${card.deck || ''}`.toLowerCase();
    if (cat.includes('スペイン') || cat.includes('spanish')) return 'es-ES';
    if (cat.includes('広東') || cat.includes('cantonese')) return 'zh-HK';
    if (cat.includes('台湾') || cat.includes('taiwan')) return 'zh-TW';
    if (cat.includes('中国') || cat.includes('chinese')) return 'zh-CN';
    if (cat.includes('韓国') || cat.includes('korean')) return 'ko-KR';
    if (cat.includes('フランス') || cat.includes('french')) return 'fr-FR';
    if (cat.includes('イタリア') || cat.includes('italian')) return 'it-IT';
    if (cat.includes('ドイツ') || cat.includes('german')) return 'de-DE';
    if (cat.includes('イギリス') || cat.includes('british')) return 'en-GB';
    return 'en-US';
  },

  /**
   * 対象言語に応じた6大出題パターン定義の動的生成
   */
  getLanguagePatterns(targetLang = 'en-US') {
    const registry = window.SUPPORTED_LANGUAGES || {};
    const meta = registry[targetLang] || { name: '英語', short: '英', flag: '🇺🇸' };
    const short = meta.short;
    const name = meta.name;
    return {
      en_to_ja: { name: `${short} ➔ 日`, desc: `${name} ➔ 日本語 (意味想起)`, badgeClass: 'badge-en-ja', hint: '意味想起' },
      ja_to_en: { name: `日 ➔ ${short}`, desc: `日本語 ➔ ${name} (瞬間作文)`, badgeClass: 'badge-ja-en', hint: '瞬間作文' },
      audio_to_ja: { name: '音 ➔ 日', desc: `音声 ➔ 日本語 (リスニング)`, badgeClass: 'badge-audio-ja', hint: 'リスニング' },
      audio_to_en: { name: `音 ➔ ${short}`, desc: `音声 ➔ ${name} (ディクテーション)`, badgeClass: 'badge-audio-en', hint: 'ディクテーション' },
      ja_to_audio: { name: '日 ➔ 音', desc: `日本語 ➔ 音声 (発音想起)`, badgeClass: 'badge-ja-audio', hint: '発音想起' },
      en_to_audio: { name: `${short} ➔ 音`, desc: `${name} ➔ 音声 (発音練習)`, badgeClass: 'badge-en-audio', hint: '発音練習' }
    };
  },

  // 学習フィルター & モード
  selectedFilter: { level1: 'all', level2: 'all', level3: 'all' },
  filterMode: 'all_random', // 'due' | 'all_random' | 'weak' | 'mistakes_today' | 'sequence'
  itemTypeFilter: 'all',     // 'all' | 'word' | 'sentence'
  activePatterns: ['front_to_back', 'back_to_front'],
  activePatternsKanji: ['char_to_read', 'read_to_char', 'word_to_read', 'read_to_word', 'sentence_fill', 'sentence_read'],
  autoPlayAudio: true,

  /**
   * 文字数に応じた動的フォントスケールクラスを算出
   */
  getFontScaleClass(text) {
    if (!text) return 'text-hero';
    const len = String(text).trim().length;
    if (len <= 15) return 'text-hero';
    if (len <= 45) return 'text-large';
    if (len <= 120) return 'text-medium';
    return 'text-content';
  },

  /**
   * 汎用パターンのサニタイズ
   */
  sanitizeUniversalPatterns(patterns) {
    const validKeys = Object.keys(this.UNIVERSAL_PATTERNS || {});
    if (!Array.isArray(patterns) || patterns.length === 0) {
      return [...validKeys];
    }
    const filtered = patterns.filter(k => validKeys.includes(k));
    return filtered.length > 0 ? filtered : [...validKeys];
  },

  /**
   * 画像表示HTML生成
   */
  renderImageHtml(src, className = 'card-display-img') {
    if (!src) return '';
    return `
      <div class="card-image-display-box" onclick="StudyManager.openLightbox('${src}'); event.stopPropagation();" title="タップして拡大">
        <img class="${className}" src="${src}" alt="添付画像" />
        <span class="card-image-zoom-hint">🔍 タップで拡大</span>
      </div>
    `;
  },

  /**
   * ライトボックス表示
   */
  openLightbox(src) {
    if (!src) return;
    const modal = document.getElementById('image-lightbox-modal');
    const imgEl = document.getElementById('lightbox-img-el') || document.getElementById('lightbox-img');
    if (modal && imgEl) {
      imgEl.src = src;
      modal.classList.remove('hidden');
    }
  },

  /**
   * ライトボックス閉じる
   */
  closeLightbox() {
    const modal = document.getElementById('image-lightbox-modal');
    const imgEl = document.getElementById('lightbox-img-el') || document.getElementById('lightbox-img');
    if (modal) {
      modal.classList.add('hidden');
      if (imgEl) {
        imgEl.src = '';
        imgEl.removeAttribute('src');
      }
    }
  },

  /**
   * 現在のカードが漢字カードか判定
   */
  isKanjiCard(card) {
    if (!card) return false;
    if (card.type === 'kanji') return true;
    const cat = `${card.category1 || ''} ${card.category2 || ''} ${card.category3 || ''} ${card.deck || ''}`;
    if (cat.includes('漢字') || cat.includes('漢検')) return true;
    if (/^[\u4E00-\u9FAF]{1,4}$/.test((card.front || '').trim()) && /【?(音|訓|意味)】?/.test(card.back || '')) {
      return true;
    }
    return false;
  },

  /**
   * 現在のセッションまたはデッキが漢字モードか判定
   */
  isCurrentSessionKanji() {
    if (this.currentCard) {
      return this.isKanjiCard(this.currentCard);
    }
    const filter = this.selectedFilter || {};
    const filterStr = `${filter.level1 || ''} ${filter.level2 || ''} ${filter.level3 || ''}`;
    return filterStr.includes('漢字') || filterStr.includes('漢検');
  },

  /**
   * 漢字出題パターンのサニタイズ（無効キー・英語キーの混入を完全防除）
   */
  sanitizeKanjiPatterns(patterns) {
    const validKeys = Object.keys(this.KANJI_PATTERNS || {});
    if (!Array.isArray(patterns) || patterns.length === 0) {
      return validKeys.length > 0 ? [...validKeys] : ['char_to_read'];
    }
    const filtered = patterns.filter(k => validKeys.includes(k));
    return filtered.length > 0 ? filtered : (validKeys.length > 0 ? [...validKeys] : ['char_to_read']);
  },

  /**
   * 漢字カードの読み方（音読み・訓読み・意味）を安全パース
   */
  parseKanjiReadings(card) {
    if (!card) return { onReadings: [], kunReadings: [], allReadings: [], meaning: '' };
    const back = card.back || '';
    const lines = back.split(/\r?\n/).map(l => l.trim()).filter(Boolean);

    let onReadings = [];
    let kunReadings = [];
    let meaning = '';

    for (const line of lines) {
      if (/^【?音(?:読み)?】?[:：]?\s*/i.test(line)) {
        const val = line.replace(/^【?音(?:読み)?】?[:：]?\s*/i, '');
        const items = val.split(/[,、・\s]+/).map(s => s.trim()).filter(Boolean);
        onReadings.push(...items);
      } else if (/^【?訓(?:読み)?】?[:：]?\s*/i.test(line)) {
        const val = line.replace(/^【?訓(?:読み)?】?[:：]?\s*/i, '');
        const items = val.split(/[,、・\s]+/).map(s => s.trim()).filter(Boolean);
        kunReadings.push(...items);
      } else if (/^【?意味】?[:：]?\s*/i.test(line)) {
        meaning = line.replace(/^【?意味】?[:：]?\s*/i, '').trim();
      } else if (!meaning && !/^【/.test(line)) {
        meaning = line;
      }
    }

    if (onReadings.length === 0 && kunReadings.length === 0) {
      const katakanaMatches = back.match(/[\u30A1-\u30F6ー]+/g);
      if (katakanaMatches) onReadings.push(...katakanaMatches);
      const hiraganaMatches = back.match(/[\u3041-\u3096]+(?:-[\u3041-\u3096]+)?/g);
      if (hiraganaMatches) kunReadings.push(...hiraganaMatches);
    }

    onReadings = [...new Set(onReadings)];
    kunReadings = [...new Set(kunReadings)];

    const allReadings = [
      ...onReadings.map(r => ({ type: 'on', reading: r, label: '音読み' })),
      ...kunReadings.map(r => ({ type: 'kun', reading: r, label: '訓読み' }))
    ];

    return { onReadings, kunReadings, allReadings, meaning: meaning || back };
  },

  /**
   * 漢字カードの代表熟語（exampleフィールド）を安全パース
   */
  parseKanjiCompounds(card) {
    if (!card || !card.example) return [];
    const lines = card.example.split(/\r?\n/).map(l => l.trim()).filter(Boolean);
    const compounds = [];

    for (const line of lines) {
      const m = line.match(/^([^\(（:：\s-]+)[（\(]([^\)）]+)[）\)][:：\s-]*(.*)$/);
      if (m) {
        compounds.push({ word: m[1].trim(), reading: m[2].trim(), meaning: (m[3] || '').trim() });
        continue;
      }
      const parts = line.split(/[:：\s-]+/).map(p => p.trim()).filter(Boolean);
      if (parts.length >= 2) {
        compounds.push({ word: parts[0], reading: parts[1], meaning: parts.slice(2).join(' ') });
      }
    }

    return compounds;
  },

  /**
   * 漢字カードの例文を安全パース
   */
  parseKanjiSentence(card) {
    const rawSent = (card && (card.exampleTranslation || card.example)) ? (card.exampleTranslation || card.example) : '';
    if (!rawSent) return null;

    const bracketMatch = rawSent.match(/\[([^\]]+)\]|［([^］]+)］/);
    let target = '';
    const sentence = rawSent;

    if (bracketMatch) {
      target = bracketMatch[1] || bracketMatch[2] || '';
    } else if (card.front && rawSent.includes(card.front)) {
      target = card.front;
    }

    return {
      rawSentence: sentence,
      target: target || card.front || '',
      blankSentence: this.formatSentenceTarget(sentence, target, 'fill'),
      highlightSentence: this.formatSentenceTarget(sentence, target, 'highlight')
    };
  },

  /**
   * 例文内の [ターゲット] を穴埋めまたはハイライトに変換
   */
  formatSentenceTarget(sentence, targetWord, mode = 'fill') {
    if (!sentence) return '';
    const text = sentence;
    const bracketRegex = /\[([^\]]+)\]|［([^］]+)］/g;
    
    if (bracketRegex.test(text)) {
      if (mode === 'fill') {
        return text.replace(bracketRegex, '<span class="kanji-blank-box" style="display:inline-block;border:2px dashed #38bdf8;border-radius:6px;padding:2px 8px;background:rgba(56,189,248,0.15);color:#38bdf8;font-weight:bold;">［　　］</span>');
      } else {
        return text.replace(bracketRegex, (match, p1, p2) => {
          const word = p1 || p2;
          return `<span class="kanji-highlight-box" style="display:inline-block;border-bottom:3px solid #f59e0b;padding:0 4px;font-weight:bold;color:#f59e0b;">${escapeHtml(word)}</span>`;
        });
      }
    }
    
    if (targetWord && text.includes(targetWord)) {
      if (mode === 'fill') {
        return text.split(targetWord).join('<span class="kanji-blank-box" style="display:inline-block;border:2px dashed #38bdf8;border-radius:6px;padding:2px 8px;background:rgba(56,189,248,0.15);color:#38bdf8;font-weight:bold;">［　　］</span>');
      } else {
        return text.split(targetWord).join(`<span class="kanji-highlight-box" style="display:inline-block;border-bottom:3px solid #f59e0b;padding:0 4px;font-weight:bold;color:#f59e0b;">${escapeHtml(targetWord)}</span>`);
      }
    }
    return escapeHtml(text);
  },

  /**
   * 動的ランダム候補抽出 & 安全フォールバック
   */
  pickKanjiQuestion(card, requestedPattern) {
    const readings = this.parseKanjiReadings(card);
    const compounds = this.parseKanjiCompounds(card);
    const sentData = this.parseKanjiSentence(card);

    let pattern = requestedPattern || 'char_to_read';
    if (!this.KANJI_PATTERNS || !this.KANJI_PATTERNS[pattern]) {
      pattern = 'char_to_read';
    }

    // 守り: 安全フォールバック
    if ((pattern === 'word_to_read' || pattern === 'read_to_word') && compounds.length === 0) {
      pattern = 'char_to_read';
    }
    if ((pattern === 'sentence_fill' || pattern === 'sentence_read') && (!sentData || !sentData.rawSentence)) {
      pattern = compounds.length > 0 ? 'word_to_read' : 'char_to_read';
    }
    if (pattern === 'read_to_char' && readings.allReadings.length === 0) {
      pattern = 'char_to_read';
    }

    const q = {
      pattern,
      requestedPattern,
      card,
      readings,
      compounds,
      sentData,
      targetWord: card.front,
      displayPrompt: '',
      guideText: '',
      guideClass: 'guide-ja',
      answerMain: '',
      answerSub: '',
      fullReadingsHtml: ''
    };

    const onStr = readings.onReadings.join('、') || '—';
    const kunStr = readings.kunReadings.join('、') || '—';
    q.fullReadingsHtml = `
      <div class="kanji-readings-grid" style="display: grid; grid-template-columns: auto 1fr; gap: 4px 10px; background: rgba(15, 23, 42, 0.4); padding: 10px 14px; border-radius: 8px; border: 1px solid rgba(255, 255, 255, 0.08); font-size: 0.9rem; text-align: left; margin: 8px 0;">
        <span style="color: #f59e0b; font-weight: bold;">【音】</span><span>${escapeHtml(onStr)}</span>
        <span style="color: #38bdf8; font-weight: bold;">【訓】</span><span>${escapeHtml(kunStr)}</span>
        ${readings.meaning ? `<span style="color: #10b981; font-weight: bold;">【意】</span><span>${escapeHtml(readings.meaning)}</span>` : ''}
      </div>
    `;

    switch (pattern) {
      case 'char_to_read': {
        q.targetWord = card.front;
        q.displayPrompt = `<span class="target-kanji-huge" style="font-size: 4rem; font-weight: 800; color: #f8fafc;">${escapeHtml(card.front)}</span>`;
        q.guideText = '🇯🇵 読み・意味を想起';
        q.answerMain = `
          <div style="font-size: 1.5rem; font-weight: bold; color: #38bdf8; margin-bottom: 6px;">
            ${escapeHtml(readings.allReadings.map(r => `${r.label}: ${r.reading}`).join('　') || card.back)}
          </div>
        `;
        q.answerSub = q.fullReadingsHtml;
        break;
      }
      case 'read_to_char': {
        const selected = readings.allReadings.length > 0
          ? readings.allReadings[Math.floor(Math.random() * readings.allReadings.length)]
          : null;
        const promptReading = selected ? `${selected.label}: ${selected.reading}` : (card.back || '—');
        q.targetWord = card.front;
        q.displayPrompt = `
          <div style="font-size: 1.6rem; font-weight: bold; color: #38bdf8; text-align: center; padding: 8px 0;">
            ${escapeHtml(promptReading)}
          </div>
          ${readings.meaning ? `<div style="font-size: 0.95rem; color: #94a3b8; text-align: center; margin-top: 2px;">（${escapeHtml(readings.meaning)}）</div>` : ''}
        `;
        q.guideText = '✍️ 漢字一文字を書く';
        q.answerMain = `<span class="target-kanji-huge" style="font-size: 4rem; font-weight: 800; color: #f8fafc;">${escapeHtml(card.front)}</span>`;
        q.answerSub = q.fullReadingsHtml;
        break;
      }
      case 'word_to_read': {
        const comp = compounds[Math.floor(Math.random() * compounds.length)];
        q.targetWord = comp.word;
        q.selectedCompound = comp;
        q.displayPrompt = `
          <div style="font-size: 2rem; font-weight: bold; color: #f8fafc; letter-spacing: 0.1em; text-align: center; padding: 10px 0;">
            ${escapeHtml(comp.word)}
          </div>
        `;
        q.guideText = '🇯🇵 熟語の読みを答える';
        q.answerMain = `
          <div style="font-size: 1.8rem; font-weight: bold; color: #38bdf8; text-align: center;">
            ${escapeHtml(comp.reading)}
          </div>
          ${comp.meaning ? `<div style="font-size: 1rem; color: #cbd5e1; margin-top: 6px; text-align: center;">意味: ${escapeHtml(comp.meaning)}</div>` : ''}
        `;
        q.answerSub = `
          <div style="font-size: 1rem; color: #94a3b8; margin-top: 8px; text-align: center;">
            対象漢字: <strong style="font-size: 1.3rem; color: #f59e0b;">${escapeHtml(card.front)}</strong>
          </div>
        `;
        break;
      }
      case 'read_to_word': {
        const comp = compounds[Math.floor(Math.random() * compounds.length)];
        q.targetWord = comp.word;
        q.selectedCompound = comp;
        q.displayPrompt = `
          <div style="font-size: 1.8rem; font-weight: bold; color: #38bdf8; text-align: center; padding: 8px 0;">
            ${escapeHtml(comp.reading)}
          </div>
          ${comp.meaning ? `<div style="font-size: 0.95rem; color: #94a3b8; margin-top: 4px; text-align: center;">（意味: ${escapeHtml(comp.meaning)}）</div>` : ''}
        `;
        q.guideText = '✍️ 熟語を書く';
        q.answerMain = `
          <div style="font-size: 2.2rem; font-weight: bold; color: #f8fafc; letter-spacing: 0.1em; text-align: center;">
            ${escapeHtml(comp.word)}
          </div>
        `;
        q.answerSub = `
          <div style="font-size: 1rem; color: #94a3b8; margin-top: 8px; text-align: center;">
            読み: <strong style="color: #38bdf8;">${escapeHtml(comp.reading)}</strong>
            ${comp.meaning ? ` ｜ 意味: ${escapeHtml(comp.meaning)}` : ''}
          </div>
        `;
        break;
      }
      case 'sentence_fill': {
        q.targetWord = sentData ? sentData.target : card.front;
        q.displayPrompt = `
          <div style="font-size: 1.2rem; line-height: 1.7; text-align: left; padding: 12px 16px; background: rgba(15, 23, 42, 0.6); border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 10px;">
            ${sentData ? sentData.blankSentence : ''}
          </div>
        `;
        q.guideText = '✍️ ［ ］に入る漢字を書く';
        q.answerMain = `
          <span class="target-kanji-huge" style="font-size: 3rem; font-weight: 800; color: #f8fafc;">${escapeHtml(q.targetWord)}</span>
        `;
        q.answerSub = `
          <div style="margin-top: 10px; font-size: 1rem; line-height: 1.6; text-align: left;">
            ${sentData ? sentData.highlightSentence : ''}
          </div>
          ${q.fullReadingsHtml}
        `;
        break;
      }
      case 'sentence_read': {
        q.targetWord = sentData ? sentData.target : card.front;
        q.displayPrompt = `
          <div style="font-size: 1.2rem; line-height: 1.7; text-align: left; padding: 12px 16px; background: rgba(15, 23, 42, 0.6); border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 10px;">
            ${sentData ? sentData.highlightSentence : ''}
          </div>
        `;
        q.guideText = '🇯🇵 傍線（強調部）の読みを答える';

        let matchedReading = '';
        const comp = compounds.find(c => c.word === q.targetWord);
        if (comp) {
          matchedReading = comp.reading;
        } else if (readings.allReadings.length > 0) {
          matchedReading = readings.allReadings.map(r => r.reading).join(' / ');
        } else {
          matchedReading = card.back;
        }

        q.answerMain = `
          <div style="font-size: 1.8rem; font-weight: bold; color: #38bdf8; text-align: center;">
            ${escapeHtml(matchedReading)}
          </div>
          <div style="font-size: 1.1rem; color: #f8fafc; margin-top: 4px; text-align: center;">
            （${escapeHtml(q.targetWord)}）
          </div>
        `;
        q.answerSub = `
          <div style="margin-top: 10px; font-size: 1rem; line-height: 1.6; text-align: left;">
            ${sentData ? sentData.highlightSentence : ''}
          </div>
          ${q.fullReadingsHtml}
        `;
        break;
      }
      default: {
        q.targetWord = card.front;
        q.displayPrompt = `<span class="target-kanji-huge" style="font-size: 4rem; font-weight: 800; color: #f8fafc;">${escapeHtml(card.front)}</span>`;
        q.guideText = '🇯🇵 読み・意味を想起';
        q.answerMain = `
          <div style="font-size: 1.5rem; font-weight: bold; color: #38bdf8; margin-bottom: 6px;">
            ${escapeHtml(readings.allReadings.map(r => `${r.label}: ${r.reading}`).join('　') || card.back)}
          </div>
        `;
        q.answerSub = q.fullReadingsHtml;
        break;
      }
    }

    return q;
  },

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
    const savedUniversalPatterns = await Storage.getSetting('study_active_patterns_universal', null);
    if (savedUniversalPatterns && Array.isArray(savedUniversalPatterns) && savedUniversalPatterns.length > 0) {
      this.activePatterns = this.sanitizeUniversalPatterns(savedUniversalPatterns);
    } else {
      this.activePatterns = ['front_to_back', 'back_to_front'];
    }
    const savedKanjiPatterns = await Storage.getSetting('study_active_patterns_kanji', null);
    this.activePatternsKanji = this.sanitizeKanjiPatterns(savedKanjiPatterns);

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
    this.renderPatternSelector();
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
    this.renderPatternSelector();
    await this.buildQueue();
    this.showNextCard();
  },

  /**
   * 出題パターン設定ボタン・モーダルの表示更新（漢字/英語動的切り替え）
   */
  renderPatternSelector() {
    this.activePatternsKanji = this.sanitizeKanjiPatterns(this.activePatternsKanji);
    this.activePatterns = this.sanitizeUniversalPatterns(this.activePatterns);
    const isKanji = this.isCurrentSessionKanji();
    const activeList = isKanji ? this.activePatternsKanji : this.activePatterns;
    const totalCount = isKanji ? 6 : 2;
    const btn = document.getElementById('pattern-btn-count');
    if (btn) {
      btn.innerText = `${activeList.length}/${totalCount}`;
    }

    const modalTitle = document.querySelector('#modal-patterns .modal-title');
    if (modalTitle) {
      modalTitle.innerText = isKanji ? '🎯 漢字 6大出題パターン' : '🎯 出題パターンの選択 (全2種)';
    }

    const patternGrid = document.querySelector('#modal-patterns .pattern-grid');
    if (patternGrid) {
      const patternDict = isKanji ? this.KANJI_PATTERNS : this.UNIVERSAL_PATTERNS;
      const set = new Set(activeList);
      let html = '';
      for (const [key, p] of Object.entries(patternDict)) {
        html += `
          <label class="pattern-item">
            <input type="checkbox" name="pattern_checkbox" value="${key}" ${set.has(key) ? 'checked' : ''} onchange="App.onPatternChange()">
            <span class="pattern-label">${p.name}: ${p.desc}</span>
          </label>
        `;
      }
      patternGrid.innerHTML = html;
    }

    const deselectBtn = document.getElementById('btn-pattern-deselect-all');
    if (deselectBtn) {
      deselectBtn.innerText = isKanji ? '全解除 (字➔読のみ)' : '全解除 (表➔裏のみ)';
    }
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
    if (!this.currentCard) {
      this.currentPattern = 'front_to_back';
      this.currentKanjiQuestion = null;
      return;
    }
    const isKanji = this.isKanjiCard(this.currentCard);
    if (isKanji) {
      const patterns = this.sanitizeKanjiPatterns(this.activePatternsKanji);
      const idx = Math.floor(Math.random() * patterns.length);
      const rawPattern = patterns[idx];
      this.currentKanjiQuestion = this.pickKanjiQuestion(this.currentCard, rawPattern);
      this.currentPattern = this.currentKanjiQuestion.pattern;
    } else {
      const patterns = (this.activePatterns && this.activePatterns.length > 0)
        ? this.sanitizeUniversalPatterns(this.activePatterns)
        : ['front_to_back'];
      const idx = Math.floor(Math.random() * patterns.length);
      this.currentPattern = patterns[idx] || 'front_to_back';
      this.currentKanjiQuestion = null;
    }
  },

  /**
   * カードのめくり（表 ➔ 裏）
   */
  flipCard() {
    if (this.isFlipped) return;
    this.isFlipped = true;
    this.showAdvice = true;
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
   * 音声再生 (プロジェクト・カード言語に自動適応)
   */
  playCardAudio() {
    if (!this.currentCard) return;
    const textToSpeak = this.currentCard.front || '';
    const lang = this.getCardLanguage(this.currentCard);
    AudioManager.speak(textToSpeak, { lang });
  },

  /**
   * 例文の音声再生 (プロジェクト・カード言語に自動適応)
   */
  playExampleAudio() {
    if (!this.currentCard || !this.currentCard.example) return;
    const lang = this.getCardLanguage(this.currentCard);
    AudioManager.speak(this.currentCard.example, { lang });
  },

  /**
   * カードの描画
   */
  renderCard() {
    const container = document.getElementById('card-stage');
    if (!container || !this.currentCard) return;

    this.renderPatternSelector();

    const card = this.currentCard;
    const pattern = this.currentPattern;
    const patternInfo = this.getPatternInfo(pattern);

    let questionHtml = '';
    let answerHtml = '';

    const isKanji = this.isKanjiCard(card);
    if (isKanji) {
      const kq = this.currentKanjiQuestion || this.pickKanjiQuestion(card, pattern);
      this.currentKanjiQuestion = kq;
      if (!this.isFlipped) {
        questionHtml = `
          <div class="card-prompt-container" style="text-align: center; padding: 12px 4px;">
            <div class="card-prompt-target" style="margin: 10px 0;">
              ${kq.displayPrompt}
            </div>
            <div class="card-target-guide" style="color: #38bdf8; font-size: 1.05rem; font-weight: bold; margin-top: 12px;">
              ${kq.guideText}
            </div>
          </div>
        `;
      } else {
        answerHtml = `
          <div class="card-answer-block" style="text-align: center; padding: 10px 4px;">
            <div class="card-answer-badge" style="font-size: 0.85rem; color: #94a3b8; margin-bottom: 6px;">🎯 正解</div>
            <div class="card-answer-main" style="margin-bottom: 8px;">
              ${kq.answerMain}
            </div>
            ${kq.answerSub}
          </div>
          ${card.advice ? `
            <div class="advice-accordion expanded" style="margin-top: 12px; background: rgba(30, 41, 59, 0.7); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 8px; padding: 10px 14px; text-align: left;">
              <div class="advice-header" style="font-size: 0.9rem; font-weight: bold; color: #f59e0b; margin-bottom: 4px;">💡 攻略アドバイス・AI解説</div>
              <div class="advice-body" style="font-size: 0.85rem; line-height: 1.5; color: #e2e8f0; white-space: pre-wrap;">${escapeHtml(card.advice)}</div>
            </div>
          ` : ''}
        `;
      }
    } else {
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
        } else if (pattern === 'back_to_front') {
          // 逆引き出題: 答えを見て問題を想起
          const text = card.back || '';
          const fontClass = this.getFontScaleClass(text);
          const imgHtml = this.renderImageHtml(card.backImage);
          questionHtml = `
            <div class="card-prompt-container" style="text-align: center; padding: 12px 4px;">
              <div class="card-prompt-text ${fontClass}" style="margin: 10px 0;">${escapeHtml(text)}</div>
              ${imgHtml}
              <div class="card-target-guide guide-universal">
                ❓ 問題 (表) を想起
              </div>
            </div>
          `;
        } else if (pattern === 'ja_to_en' || pattern === 'ja_to_audio') {
          const text = card.back || '';
          const fontClass = this.getFontScaleClass(text);
          const imgHtml = this.renderImageHtml(card.backImage);
          questionHtml = `
            <div class="card-prompt-container" style="text-align: center; padding: 12px 4px;">
              <div class="card-prompt-text ja ${fontClass}">${escapeHtml(text)}</div>
              ${imgHtml}
            </div>
          `;
        } else {
          // 基本出題: 表 ➔ 裏 (問題・用語・算数文章題)
          const text = card.front || '';
          const fontClass = this.getFontScaleClass(text);
          const imgHtml = this.renderImageHtml(card.frontImage);
          const hasVoice = (card.voiceType && card.voiceType !== 'none') || pattern === 'en_to_ja';
          questionHtml = `
            <div class="card-prompt-container" style="text-align: center; padding: 12px 4px;">
              <div class="card-prompt-text ${fontClass}" style="margin: 10px 0;">
                <span>${escapeHtml(text)}</span>
                ${hasVoice ? `<button class="speaker-btn" style="margin-left: 8px; vertical-align: middle;" onclick="StudyManager.playCardAudio(); event.stopPropagation();" title="発音を聞く">🔊</button>` : ''}
              </div>
              ${imgHtml}
              <div class="card-target-guide guide-universal">
                🎯 解答 (裏) を想起
              </div>
            </div>
          `;
        }
      } else {
        // ===== 裏面（解答） =====
        if (pattern === 'back_to_front') {
          // 逆引き出題の解答: 表面テキスト
          const ansText = card.front || '';
          const fontClass = this.getFontScaleClass(ansText);
          const imgHtml = this.renderImageHtml(card.frontImage);
          const hasVoice = (card.voiceType && card.voiceType !== 'none');
          answerHtml = `
            <div class="card-answer-block" style="text-align: center; padding: 10px 4px;">
              <div class="card-answer-badge" style="font-size: 0.85rem; color: #94a3b8; margin-bottom: 6px;">🎯 解答 (問題)</div>
              <div class="card-answer-main ${fontClass}">
                <span>${escapeHtml(ansText)}</span>
                ${hasVoice ? `<button class="speaker-btn" style="margin-left: 8px; vertical-align: middle;" onclick="StudyManager.playCardAudio(); event.stopPropagation();" title="発音を聞く">🔊</button>` : ''}
              </div>
              ${imgHtml}
            </div>
            ${card.advice ? `
              <div class="advice-accordion expanded" style="margin-top: 12px; background: rgba(30, 41, 59, 0.7); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 8px; padding: 10px 14px; text-align: left;">
                <div class="advice-header" style="font-size: 0.9rem; font-weight: bold; color: #f59e0b; margin-bottom: 4px;">💡 解説・補足メモ</div>
                <div class="advice-body" style="font-size: 0.85rem; line-height: 1.5; color: #e2e8f0; white-space: pre-wrap;">${escapeHtml(card.advice)}</div>
              </div>
            ` : ''}
          `;
        } else if (pattern === 'ja_to_en') {
          const ansText = card.front || '';
          const fontClass = this.getFontScaleClass(ansText);
          const imgHtml = this.renderImageHtml(card.frontImage);
          answerHtml = `
            <div class="card-answer-block">
              <div class="card-answer-row">
                <div class="card-answer-main en ${fontClass}">
                  ${escapeHtml(ansText)}
                </div>
                <button class="speaker-btn" onclick="StudyManager.playCardAudio(); event.stopPropagation();" title="発音を聞く">
                  🔊
                </button>
              </div>
              <div class="card-answer-sub">
                ${escapeHtml(card.back)}
              </div>
              ${imgHtml}
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
              <div class="advice-accordion expanded">
                <div class="advice-header">
                  <span class="advice-title">💡 解説・補足メモ</span>
                  <span class="advice-arrow">▲</span>
                </div>
                <div class="advice-body">${escapeHtml(card.advice)}</div>
              </div>
            ` : ''}
          `;
        } else {
          // 基本: 表 ➔ 裏 (解答は back)
          const ansText = card.back || '';
          const fontClass = this.getFontScaleClass(ansText);
          const imgHtml = this.renderImageHtml(card.backImage);
          const hasVoice = (card.voiceType && card.voiceType !== 'none') || pattern === 'en_to_ja';
          answerHtml = `
            <div class="card-answer-block" style="text-align: center; padding: 10px 4px;">
              <div class="card-answer-badge" style="font-size: 0.85rem; color: #94a3b8; margin-bottom: 6px;">🎯 解答</div>
              <div class="card-answer-main ${fontClass}">
                ${escapeHtml(ansText)}
              </div>
              ${hasVoice ? `
                <div style="margin-top: 6px;">
                  <button class="speaker-btn" onclick="StudyManager.playCardAudio(); event.stopPropagation();" title="発音を聞く">🔊 発音を聞く</button>
                </div>
              ` : ''}
              ${imgHtml}
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
              <div class="advice-accordion expanded" style="margin-top: 12px; background: rgba(30, 41, 59, 0.7); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 8px; padding: 10px 14px; text-align: left;">
                <div class="advice-header" style="font-size: 0.9rem; font-weight: bold; color: #f59e0b; margin-bottom: 4px;">💡 解説・補足メモ</div>
                <div class="advice-body" style="font-size: 0.85rem; line-height: 1.5; color: #e2e8f0; white-space: pre-wrap;">${escapeHtml(card.advice)}</div>
              </div>
            ` : ''}
          `;
        }
      }
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
    const cardLang = this.getCardLanguage(this.currentCard);
    const langMeta = (window.SUPPORTED_LANGUAGES && window.SUPPORTED_LANGUAGES[cardLang]) || { name: '英語', short: '英' };
    const langName = langMeta.name;

    switch (pattern) {
      case 'front_to_back':
        return { badgeText: '🎯 QUEST: 答えを想起せよ！', badgeClass: 'badge-en-ja' };
      case 'back_to_front':
        return { badgeText: '❓ QUEST: 問題を想起せよ！', badgeClass: 'badge-ja-en' };
      case 'char_to_read':
        return { badgeText: '⚔️ QUEST: 漢字の読み・意味を想起せよ！', badgeClass: 'badge-en-ja' };
      case 'read_to_char':
        return { badgeText: '✍️ QUEST: 読みから漢字一文字を書け！', badgeClass: 'badge-ja-en' };
      case 'word_to_read':
        return { badgeText: '📖 QUEST: 熟語の読み方を答えよ！', badgeClass: 'badge-audio-ja' };
      case 'read_to_word':
        return { badgeText: '✍️ QUEST: 熟語の読みから熟語を書け！', badgeClass: 'badge-audio-en' };
      case 'sentence_fill':
        return { badgeText: '🎯 QUEST: ［ ］に入る漢字を書け！', badgeClass: 'badge-ja-audio' };
      case 'sentence_read':
        return { badgeText: '🇯🇵 QUEST: 傍線（強調部）の読みを答えよ！', badgeClass: 'badge-en-audio' };
      case 'en_to_ja':
        return { badgeText: '⚔️ QUEST: 日本語の意味を言え！', badgeClass: 'badge-en-ja' };
      case 'ja_to_en':
        return { badgeText: `🛡️ QUEST: ${langName}で発音・作文せよ！`, badgeClass: 'badge-ja-en' };
      case 'audio_to_ja':
        return { badgeText: '🎧 QUEST: 音声を聞いて意味を答えよ！', badgeClass: 'badge-audio-ja' };
      case 'audio_to_en':
        return { badgeText: `✍️ QUEST: 音声を聞いて${langName}を答えよ！`, badgeClass: 'badge-audio-en' };
      case 'ja_to_audio':
        return { badgeText: `🗣️ QUEST: 日本語から${langName}を発音せよ！`, badgeClass: 'badge-ja-audio' };
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

    // 学習履歴ログの送信処理（保護者見守りWebhookへの送信）
    if (typeof SyncManager !== 'undefined' && SyncManager.sendStudyReport) {
      const durationMin = this.stats.sessionStartTime
        ? Math.max(1, Math.round((Date.now() - this.stats.sessionStartTime) / 60000))
        : 1;
      SyncManager.sendStudyReport({
        answered: answered,
        correct: correct,
        wrong: this.stats.wrongCount,
        accuracy: acc,
        durationMinutes: durationMin,
        startTimeStr: this.stats.sessionStartTime ? new Date(this.stats.sessionStartTime).toLocaleTimeString() : ''
      }).catch(e => console.warn('Study report send skipped:', e));
    }
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
