/**
 * audio.js - MEMORY HACK Mobile 音声エンジン (Web Speech API / TTS)
 * Android Chrome および iOS Safari に対応したタッチアンロック＆発音再生
 */

const AudioManager = {
  synth: window.speechSynthesis || null,
  isUnlocked: false,
  rate: 0.9,
  pitch: 1.0,
  voices: [],

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
    // Google TTS (Android Chrome標準) または en-US の音声を優先検索
    const voice = this.voices.find(v => v.lang.replace('_', '-').startsWith(lang) && (v.name.includes('Google') || v.name.includes('Natural')))
      || this.voices.find(v => v.lang.replace('_', '-').startsWith(lang))
      || null;
    return voice;
  },

  /**
   * 英語テキストの発話
   */
  speak(text, options = {}) {
    if (!this.synth || !text) return;

    this.synth.cancel(); // 前の音声を停止

    const cleanText = text.replace(/<[^>]+>/g, '').trim();
    if (!cleanText) return;

    const utter = new SpeechSynthesisUtterance(cleanText);
    utter.lang = options.lang || 'en-US';
    utter.rate = options.rate || this.rate;
    utter.pitch = options.pitch || this.pitch;

    const voice = this.getVoice(utter.lang);
    if (voice) {
      utter.voice = voice;
    }

    if (options.onEnd) {
      utter.onend = options.onEnd;
    }
    if (options.onError) {
      utter.onerror = options.onError;
    }

    // Android Chrome特有のロングテキストフリーズ防止
    const resumeTimer = setInterval(() => {
      if (!this.synth.speaking) {
        clearInterval(resumeTimer);
      } else {
        this.synth.pause();
        this.synth.resume();
      }
    }, 5000);

    utter.onend = () => {
      clearInterval(resumeTimer);
      if (options.onEnd) options.onEnd();
    };

    this.synth.speak(utter);
  },

  stop() {
    if (this.synth) {
      this.synth.cancel();
    }
  }
};
