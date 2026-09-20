/**
 * storage.js - MEMORY HACK Mobile ローカルデータ永続化ストレージ
 */

const Storage = {
  KEYS: {
    CARDS: 'memory_hack_mobile_cards',
    SETTINGS: 'memory_hack_mobile_settings',
    DECK_ORDER: 'memory_hack_mobile_deck_order',
    LAST_SYNC: 'memory_hack_mobile_last_sync'
  },

  // 初期フォールバック用サンプルデータ
  DEFAULT_CARDS: [
    {
      id: "sample-1",
      front: "participate in",
      back: "〜に参加する",
      example: "All students are encouraged to participate in school events.",
      exampleTranslation: "すべての生徒が学校行事に参加することが推奨されている。",
      advice: "💡【重要文法】part（部分・役割）を取る ➔「参加する」。「take part in」と同義。joinは目的語を直接取るが、participateには前置詞「in」が必須！定期テスト頻出。",
      category1: "1年教科書",
      category2: "Unit 1",
      category3: "",
      deck: "1年教科書",
      itemType: "phrase",
      repetitionLevel: 0,
      nextReviewDate: new Date().toISOString()
    },
    {
      id: "sample-2",
      front: "look forward to",
      back: "〜を楽しみに待つ",
      example: "I am looking forward to seeing you next week.",
      exampleTranslation: "来週あなたに会えるのを楽しみにしています。",
      advice: "💡【最頻出文法】to は不定詞ではなく「前置詞」！後ろに動詞が来る場合は必ず動名詞（-ing）になる。「look forward to seeing you」は入試ひっかけ問題の定番中の定番。",
      category1: "1年教科書",
      category2: "Unit 1",
      category3: "",
      deck: "1年教科書",
      itemType: "phrase",
      repetitionLevel: 0,
      nextReviewDate: new Date().toISOString()
    },
    {
      id: "sample-3",
      front: "May the force be with you.",
      back: "フォースと共にあらんことを。",
      example: "Remember, kid, may the force be with you always.",
      exampleTranslation: "覚えておけ、フォースはいつでも共にある。",
      advice: "💡【名言文法】祈願文の「May + 主語 + 原形動詞」。神や大いなる力への祈り・祝福を込める定番表現。",
      category1: "映画",
      category2: "スター・ウォーズ",
      category3: "",
      deck: "映画",
      itemType: "sentence",
      repetitionLevel: 0,
      nextReviewDate: new Date().toISOString()
    }
  ],

  /**
   * 全カード取得
   */
  async getAllCards() {
    try {
      const data = localStorage.getItem(this.KEYS.CARDS);
      if (data) {
        const parsed = JSON.parse(data);
        if (Array.isArray(parsed) && parsed.length > 0) {
          return parsed;
        }
      }
    } catch (e) {
      console.warn('Storage.getAllCards failed:', e);
    }
    return [...this.DEFAULT_CARDS];
  },

  /**
   * 全カード保存
   */
  async saveAllCards(cards) {
    try {
      localStorage.setItem(this.KEYS.CARDS, JSON.stringify(cards));
      return true;
    } catch (e) {
      console.error('Storage.saveAllCards failed:', e);
      return false;
    }
  },

  /**
   * 1枚のカードを更新
   */
  async updateCard(card) {
    const cards = await this.getAllCards();
    const idx = cards.findIndex(c => c.id === card.id || (c.front === card.front && c.back === card.back));
    if (idx >= 0) {
      cards[idx] = { ...cards[idx], ...card };
    } else {
      cards.push(card);
    }
    await this.saveAllCards(cards);
  },

  /**
   * 設定値の取得
   */
  async getSetting(key, defaultValue = null) {
    try {
      const data = localStorage.getItem(this.KEYS.SETTINGS);
      if (data) {
        const parsed = JSON.parse(data);
        if (key in parsed) {
          return parsed[key];
        }
      }
    } catch (e) {
      console.warn('Storage.getSetting failed:', e);
    }
    return defaultValue;
  },

  /**
   * 設定値の保存
   */
  async saveSetting(key, value) {
    try {
      let current = {};
      const data = localStorage.getItem(this.KEYS.SETTINGS);
      if (data) {
        current = JSON.parse(data);
      }
      current[key] = value;
      localStorage.setItem(this.KEYS.SETTINGS, JSON.stringify(current));
      return true;
    } catch (e) {
      console.error('Storage.saveSetting failed:', e);
      return false;
    }
  },

  /**
   * デッキ並び順（deckOrder）の取得
   */
  async getDeckOrder() {
    try {
      const data = localStorage.getItem(this.KEYS.DECK_ORDER);
      if (data) return JSON.parse(data);
    } catch (e) {
      console.warn('Storage.getDeckOrder failed:', e);
    }
    return null;
  },

  /**
   * デッキ並び順（deckOrder）の保存
   */
  async saveDeckOrder(order) {
    try {
      localStorage.setItem(this.KEYS.DECK_ORDER, JSON.stringify(order));
      return true;
    } catch (e) {
      console.error('Storage.saveDeckOrder failed:', e);
      return false;
    }
  }
};
