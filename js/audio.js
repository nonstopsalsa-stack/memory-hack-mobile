/**
 * audio.js - MEMORY HACK Mobile 音声エンジン (Web Speech API / TTS)
 * Android Chrome および iOS Safari に対応したタッチアンロック＆堅牢化発音再生
 */

const AudioManager = {
  synth: window.speechSynthesis || null,
  isUnlocked: false,
  rate: 0.9,
  pitch: 1.0,
  voices: [],
  activeUtterances: [], // V8 GC回収防止のための強参照配列
  safetyTimer: null,
  currentPlayId: 0,
  _playCounter: 0,

  init() {
    if (!this.synth) {
      console.warn('Web Speech API is not supported in this browser.');
      return;
    }

    this.loadVoices();
    if (this.synth.onvoiceschanged !== undefined) {
      this.synth.onvoiceschanged = () => this.loadVoices();
    }

    // 初回ユーザーインタラクション（タップ・クリック）で音声をアンロック
    const unlockHandler = () => {
      this.unlock();
      document.removeEventListener('touchstart', unlockHandler);
      document.removeEventListener('click', unlockHandler);
    };
    document.addEventListener('touchstart', unlockHandler, { once: true, passive: true });
    document.addEventListener('click', unlockHandler, { once: true });
  },

  loadVoices() {
    if (!this.synth) return;
    this.voices = this.synth.getVoices() || [];
  },

  unlock() {
    if (this.isUnlocked || !this.synth) return;
    try {
      const dummy = new SpeechSynthesisUtterance('');
      dummy.volume = 0;
      this.synth.speak(dummy);
      this.isUnlocked = true;
      console.log('[Audio] Speech synthesis unlocked.');
    } catch (e) {
      console.warn('[Audio] Unlock failed:', e);
    }
  },

  getVoice(lang = 'en-US') {
    if (!this.voices || this.voices.length === 0) {
      this.loadVoices();
    }
    const target = (lang || 'en-US').toLowerCase();
    const short = target.split('-')[0];

    // 1. 完全一致 + Natural/Google/Premium
    let voice = this.voices.find(v => {
      const vLang = (v.lang || '').replace('_', '-').toLowerCase();
      return vLang === target && (v.name.includes('Natural') || v.name.includes('Google') || v.name.includes('Premium'));
    });
    // 2. 完全一致
    if (!voice) {
      voice = this.voices.find(v => (v.lang || '').replace('_', '-').toLowerCase() === target);
    }
    // 3. 前方一致 (例: es, zh, ko, fr, it, de)
    if (!voice) {
      voice = this.voices.find(v => (v.lang || '').replace('_', '-').toLowerCase().startsWith(short));
    }
    return voice || null;
  },

  /**
   * テキストを句読点（. , ? ! 改行 および 全角句読点）で文単位に分割 (Sentence Chunking)
   */
  splitIntoChunks(text) {
    if (!text) return [];
    const clean = String(text).replace(/<[^>]+>/g, ' ').trim();
    if (!clean) return [];

    // デリミタで分割し、デリミタを直前の文末に結合する方式
    const parts = clean.split(/([.,?!\n。、！？]+)/);
    const chunks = [];
    let current = '';

    for (let i = 0; i < parts.length; i++) {
      const part = parts[i];
      if (!part) continue;
      if (/^[.,?!\n。、！？]+$/.test(part)) {
        current += part;
        if (current.trim()) {
          chunks.push(current.trim());
        }
        current = '';
      } else {
        if (current.trim()) {
          chunks.push(current.trim());
        }
        current = part;
      }
    }
    if (current.trim()) {
      chunks.push(current.trim());
    }

    return chunks.length > 0 ? chunks : [clean];
  },

  /**
   * 音声の発話 (Sentence Chunking 順次キューイング & GC保護 & 自己治癒タイマー内蔵)
   */
  speak(text, options = {}) {
    if (!this.synth || !text) {
      if (options.onEnd) options.onEnd();
      return;
    }

    // 既存の安全タイマーを解除
    if (this.safetyTimer) {
      clearTimeout(this.safetyTimer);
      this.safetyTimer = null;
    }

    // サスペンド状態なら復帰
    if (this.synth.paused) {
      try { this.synth.resume(); } catch (e) {}
    }

    const chunks = this.splitIntoChunks(text);
    if (chunks.length === 0) {
      if (options.onEnd) options.onEnd();
      return;
    }

    // 新しい再生IDを発行（先行する順次再生を安全に無効化）
    const playId = ++this._playCounter;
    this.currentPlayId = playId;

    const doSpeak = () => {
      if (this.currentPlayId !== playId) return;

      // V8エンジンのガベージコレクション（GC）による発話中断を防止するため強参照配列を初期化
      this.activeUtterances = [];

      const lang = options.lang || 'en-US';
      const rate = options.rate || this.rate;
      const pitch = options.pitch || this.pitch;
      const voice = this.getVoice(lang);

      // 全チャンクの Utterance インスタンスを生成して activeUtterances 配列に保持
      for (let i = 0; i < chunks.length; i++) {
        const utter = new SpeechSynthesisUtterance(chunks[i]);
        utter.lang = lang;
        utter.rate = options.rate || this.rate;
        utter.pitch = pitch;
        if (voice) {
          utter.voice = voice;
        }
        this.activeUtterances.push(utter);
      }

      let currentIndex = 0;

      const cleanup = () => {
        if (this.safetyTimer) {
          clearTimeout(this.safetyTimer);
          this.safetyTimer = null;
        }
        this.activeUtterances = [];
      };

      const playNextChunk = () => {
        if (this.currentPlayId !== playId) {
          cleanup();
          return;
        }

        if (currentIndex >= this.activeUtterances.length) {
          cleanup();
          if (options.onEnd) options.onEnd();
          return;
        }

        const utter = this.activeUtterances[currentIndex];
        const chunkText = chunks[currentIndex] || '';
        let chunkFinished = false;

        const finishChunk = (fromTimeout = false) => {
          if (chunkFinished) return;
          chunkFinished = true;

          if (this.safetyTimer) {
            clearTimeout(this.safetyTimer);
            this.safetyTimer = null;
          }

          if (this.currentPlayId !== playId) {
            cleanup();
            return;
          }

          currentIndex++;
          if (currentIndex < this.activeUtterances.length) {
            playNextChunk();
          } else {
            cleanup();
            if (options.onEnd) options.onEnd();
          }
        };

        utter.onend = () => {
          finishChunk(false);
        };

        utter.onerror = (e) => {
          console.warn('[Audio] Utterance error on chunk:', currentIndex, e.error || e);
          if (options.onError) {
            try { options.onError(e); } catch (err) {}
          }
          finishChunk(false);
        };

        // 自己治癒タイマー（Chrome/Safariが何らかの理由でonendを発火しなかった場合の保険）
        const estimatedDurationMs = Math.max(4000, Math.round((chunkText.length * 180) / rate) + 3000);
        this.safetyTimer = setTimeout(() => {
          if (!chunkFinished) {
            console.warn('[Audio] Safety timeout reached for chunk:', currentIndex, '. Resuming synthesis.');
            try { this.synth.resume(); } catch (e) {}
            finishChunk(true);
          }
        }, estimatedDurationMs);

        try {
          if (this.synth.paused) {
            try { this.synth.resume(); } catch (e) {}
          }
          this.synth.speak(utter);
        } catch (err) {
          console.warn('[Audio] speak() call failed for chunk:', currentIndex, err);
          finishChunk(false);
        }
      };

      playNextChunk();
    };

    // Chromiumバグ対策: cancel()直後の同期speak()は新キューを破壊するため、
    // 先行発話がある場合はcancel()を発行した上で35msのディレイキューを設ける
    if (this.synth.speaking || this.synth.pending || this.activeUtterances.length > 0) {
      try { this.synth.cancel(); } catch (e) {}
      setTimeout(doSpeak, 35);
    } else {
      doSpeak();
    }
  },

  stop() {
    this.currentPlayId = ++this._playCounter;
    if (this.safetyTimer) {
      clearTimeout(this.safetyTimer);
      this.safetyTimer = null;
    }
    this.activeUtterances = [];
    if (this.synth) {
      try { this.synth.cancel(); } catch (e) {}
    }
  }
};

window.AudioManager = AudioManager;
