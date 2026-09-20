/**
 * sync.js - MEMORY HACK Mobile クラウド同期マネージャー
 * Master System が Google Drive (GAS) へ配信した最新カードとデッキ順序を取得
 */

const SyncManager = {
  syncUrl: '',
  isSyncing: false,
  lastSyncTime: null,
  lastRemoteUpdatedAt: null,

  async init() {
    const config = window.APP_CONFIG || {};
    let savedUrl = await Storage.getSetting('webhookUrl', null);
    if (!savedUrl || typeof savedUrl !== 'string' || !savedUrl.trim().startsWith('https://script.google.com/')) {
      savedUrl = config.defaultWebhookUrl || '';
      if (savedUrl) {
        await Storage.saveSetting('webhookUrl', savedUrl.trim());
      }
    }
    this.syncUrl = (savedUrl || '').trim();
    this.lastSyncTime = await Storage.getSetting('lastSyncTime', null);
    this.lastRemoteUpdatedAt = await Storage.getSetting('lastRemoteUpdatedAt', null);

    this.updateStatusBadge('ready');

    // 起動時に自動チェック
    if (this.syncUrl && (config.autoSyncEnabled !== false)) {
      setTimeout(() => {
        this.checkForUpdates({ autoPull: true, silent: true });
      }, 500);
    }
  },

  updateStatusBadge(status) {
    const badge = document.getElementById('sync-status-badge');
    const label = document.getElementById('sync-status-label');
    if (!badge || !label) return;

    badge.className = 'sync-badge ' + status;
    if (status === 'syncing') {
      label.innerText = '同期中...';
    } else if (status === 'success') {
      label.innerText = '最新';
    } else if (status === 'update-available') {
      label.innerText = '更新あり';
    } else if (status === 'error') {
      label.innerText = '同期エラー';
    } else {
      label.innerText = '同期';
    }
  },

  /**
   * GASからのデータ取得（CORS fetch ➔ 失敗時 JSONP フォールバック）
   */
  async fetchRemoteData(action) {
    let currentUrl = (this.syncUrl || '').trim();
    if (!currentUrl || !currentUrl.startsWith('https://script.google.com/')) {
      const config = window.APP_CONFIG || {};
      currentUrl = config.defaultWebhookUrl ? config.defaultWebhookUrl.trim() : '';
      this.syncUrl = currentUrl;
    }
    if (!currentUrl) {
      throw new Error('Webhook URL が設定されていません。');
    }

    const separator = currentUrl.includes('?') ? '&' : '?';
    const fetchUrl = `${currentUrl}${separator}action=${action}&t=${Date.now()}`;

    // 1. 通常の fetch を試行
    try {
      const resp = await fetch(fetchUrl);
      if (resp.ok) {
        return await resp.json();
      }
    } catch (err) {
      console.warn('Standard fetch failed, falling back to JSONP...', err);
    }

    // 2. JSONP フォールバック（モバイルブラウザのCORS回避に最も安定）
    return new Promise((resolve, reject) => {
      const callbackName = 'mobile_sync_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7);
      const jsonpUrl = `${currentUrl}${separator}action=${action}&callback=${callbackName}&t=${Date.now()}`;

      const script = document.createElement('script');
      script.src = jsonpUrl;
      script.async = true;

      const timer = setTimeout(() => {
        cleanup();
        reject(new Error('JSONP request timed out (15s)'));
      }, 15000);

      function cleanup() {
        clearTimeout(timer);
        delete window[callbackName];
        if (script.parentNode) {
          script.parentNode.removeChild(script);
        }
      }

      window[callbackName] = function(data) {
        cleanup();
        resolve(data);
      };

      script.onerror = function(err) {
        cleanup();
        reject(new Error('JSONP network error'));
      };

      document.body.appendChild(script);
    });
  },

  /**
   * クラウド更新チェック
   */
  async checkForUpdates(options = {}) {
    const { autoPull = false, silent = true } = options;
    if (!this.syncUrl || this.isSyncing) return;

    try {
      const data = await this.fetchRemoteData('check_update');
      if (data && data.updatedAt) {
        const remoteTime = new Date(data.updatedAt).getTime();
        const localTime = this.lastRemoteUpdatedAt ? new Date(this.lastRemoteUpdatedAt).getTime() : 0;
        const currentCards = await Storage.getAllCards();

        if (remoteTime > localTime || currentCards.length <= 3) {
          console.log('[Sync] Remote update detected. Pulling deck...');
          if (autoPull) {
            await this.pullDeck({ silent: true });
          } else {
            this.updateStatusBadge('update-available');
          }
        } else {
          this.updateStatusBadge('success');
        }
      }
    } catch (e) {
      console.warn('Check updates failed:', e);
      if (!silent) this.updateStatusBadge('error');
    }
  },

  /**
   * クラウドから最新カードとデッキ順序を取得
   */
  async pullDeck(options = {}) {
    const { silent = false } = options;
    if (this.isSyncing) return;
    this.isSyncing = true;
    this.updateStatusBadge('syncing');

    try {
      const data = await this.fetchRemoteData('pull_deck');
      if (!data || !data.cards || !Array.isArray(data.cards)) {
        throw new Error('クラウド上にカードデータが見つかりませんでした。');
      }

      const remoteCards = data.cards;
      const remoteUpdatedAt = data.updatedAt || new Date().toISOString();

      // ローカルの既存カードと学習履歴（repetitionLevel等）をマージ
      const localCards = await Storage.getAllCards();
      const localMap = new Map();
      localCards.forEach(c => {
        const key = (c.front || '').trim().toLowerCase();
        if (key) localMap.set(key, c);
      });

      const mergedCards = remoteCards.map(rc => {
        const key = (rc.front || '').trim().toLowerCase();
        const existing = localMap.get(key);
        if (existing) {
          return {
            ...rc,
            repetitionLevel: existing.repetitionLevel !== undefined ? existing.repetitionLevel : 0,
            reviewCount: existing.reviewCount || 0,
            lastReviewedAt: existing.lastReviewedAt || null,
            nextReviewDate: existing.nextReviewDate || null
          };
        }
        return {
          ...rc,
          repetitionLevel: 0,
          reviewCount: 0,
          lastReviewedAt: null,
          nextReviewDate: null
        };
      });

      await Storage.saveAllCards(mergedCards);

      // デッキ並び順
      if (data.deckOrder && typeof data.deckOrder === 'object') {
        await Storage.saveDeckOrder(data.deckOrder);
      }

      this.lastRemoteUpdatedAt = remoteUpdatedAt;
      this.lastSyncTime = new Date().toISOString();
      await Storage.saveSetting('lastRemoteUpdatedAt', this.lastRemoteUpdatedAt);
      await Storage.saveSetting('lastSyncTime', this.lastSyncTime);

      this.updateStatusBadge('success');

      // 学習マネージャーに反映
      if (typeof StudyManager !== 'undefined' && StudyManager.onDeckLoaded) {
        await StudyManager.onDeckLoaded(mergedCards);
      }

      if (!silent) {
        App.showToast(`✅ ${mergedCards.length}枚のカードを受信・同期しました！`, 'success');
      }
      return { success: true, count: mergedCards.length };

    } catch (err) {
      console.error('pullDeck failed:', err);
      this.updateStatusBadge('error');
      if (!silent) {
        App.showToast(`❌ 同期失敗: ${err.message}`, 'error');
      }
      return { success: false, error: err.message };
    } finally {
      this.isSyncing = false;
    }
  }
};
