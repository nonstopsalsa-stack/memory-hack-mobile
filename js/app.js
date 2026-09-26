/**
 * app.js - MEMORY HACK Mobile アプリケーション統括コントローラー
 */

const App = {
  deferredPrompt: null,

  async init() {
    console.log('[App] MEMORY HACK Mobile v1.3.2 Initializing...');

    // 0. テーマ初期化
    try {
      const savedTheme = localStorage.getItem('anki_mobile_theme') || 'bloxfruits';
      this.applyTheme(savedTheme, false);
    } catch (e) {
      console.warn('[App] Theme init error:', e);
    }

    // 1. 各マネージャーの初期化
    try {
      if (typeof AudioManager !== 'undefined') AudioManager.init();
      if (typeof SyncManager !== 'undefined') await SyncManager.init();
      if (typeof StudyManager !== 'undefined') await StudyManager.init();
    } catch (e) {
      console.error('[App] Manager init error:', e);
    }

    // 起動トースト表示
    this.showToast('🚀 MEMORY HACK Mobile v1.3.2 準備完了', 'info');

    // 2. イベントリスナー登録
    this.bindEvents();

    // 3. PWA Service Worker 登録
    this.registerServiceWorker();

    // 4. PWA インストールバナー検知
    window.addEventListener('beforeinstallprompt', (e) => {
      e.preventDefault();
      this.deferredPrompt = e;
      const banner = document.getElementById('pwa-install-banner');
      if (banner) banner.classList.remove('hidden');
    });
  },

  bindEvents() {
    // 単語/文章フィルターボタン
    const filterBtns = document.querySelectorAll('.type-filter-btn');
    filterBtns.forEach(btn => {
      btn.addEventListener('click', async () => {
        filterBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        const filterType = btn.dataset.type;
        StudyManager.itemTypeFilter = filterType;
        await Storage.saveSetting('study_item_type_filter', filterType);
        await StudyManager.buildQueue();
        StudyManager.showNextCard();
      });
    });

    // 出題パターンチェックボックス変更
    const patternCheckboxes = document.querySelectorAll('input[name="pattern_checkbox"]');
    patternCheckboxes.forEach(cb => {
      cb.addEventListener('change', async () => {
        const checked = Array.from(document.querySelectorAll('input[name="pattern_checkbox"]:checked')).map(c => c.value);
        if (checked.length === 0) {
          cb.checked = true;
          this.showToast('⚠️ 最低1つの出題パターンを選択してください', 'warn');
          return;
        }
        StudyManager.activePatterns = checked;
        await Storage.saveSetting('study_active_patterns', checked);
        StudyManager.renderPatternSelector();
      });
    });

    // キーボードショートカット（PCブラウザ検証・外部キーボード操作用）
    document.addEventListener('keydown', (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.tagName === 'SELECT') return;

      if (e.code === 'Space') {
        e.preventDefault();
        StudyManager.flipCard();
      } else if (e.code === 'ArrowLeft' || e.key === '1') {
        if (StudyManager.isFlipped) StudyManager.recordAnswer(false);
      } else if (e.code === 'ArrowRight' || e.key === '2') {
        if (StudyManager.isFlipped) StudyManager.recordAnswer(true);
      } else if (e.code === 'ArrowUp' || e.key === '[') {
        e.preventDefault();
        StudyManager.goToPrevCardWithoutGrading();
      } else if (e.code === 'ArrowDown' || e.key === ']') {
        e.preventDefault();
        StudyManager.goToNextCardWithoutGrading();
      } else if (e.key === 'r' || e.key === 'R') {
        StudyManager.playCardAudio();
      }
    });
  },

  // デッキツリー階層選択ボトムシートのオープン
  openHierarchyModal() {
    const container = document.getElementById('hierarchy-tree-container');
    if (container && typeof Hierarchy !== 'undefined') {
      Hierarchy.renderTreeSheet(
        container,
        StudyManager.cards,
        StudyManager.selectedFilter,
        async (filter) => {
          await StudyManager.setHierarchyFilter(filter);
          this.closeModal('modal-hierarchy');
          this.showToast(`📚 「${Hierarchy.formatBreadcrumb(filter)}」を選択しました`, 'info');
        }
      );
    }
    this.openModal('modal-hierarchy');
  },

  // モーダル操作
  openModal(id) {
    const modal = document.getElementById(id);
    if (modal) {
      modal.classList.remove('hidden');
      document.body.classList.add('modal-open');
    }
  },

  closeModal(id) {
    const modal = document.getElementById(id);
    if (modal) {
      modal.classList.add('hidden');
      document.body.classList.remove('modal-open');
    }
  },

  // 出題パターン全選択/解除
  toggleAllPatterns(selectAll) {
    const checkboxes = document.querySelectorAll('input[name="pattern_checkbox"]');
    checkboxes.forEach(cb => cb.checked = selectAll);
    if (!selectAll) {
      const def = document.querySelector('input[name="pattern_checkbox"][value="en_to_ja"]');
      if (def) def.checked = true;
    }
    const checked = Array.from(document.querySelectorAll('input[name="pattern_checkbox"]:checked')).map(c => c.value);
    StudyManager.activePatterns = checked;
    Storage.saveSetting('study_active_patterns', checked);
    StudyManager.renderPatternSelector();
  },

  // テーマ適用 (bloxfruits / light / dark)
  applyTheme(theme, save = true) {
    if (!theme) theme = 'bloxfruits';
    document.documentElement.setAttribute('data-theme', theme);
    if (save) {
      localStorage.setItem('anki_mobile_theme', theme);
    }
    const themeSelect = document.getElementById('setting-mobile-theme');
    if (themeSelect && themeSelect.value !== theme) {
      themeSelect.value = theme;
    }
    // PWA テーマカラーの動的変更
    const metaTheme = document.querySelector('meta[name="theme-color"]');
    if (metaTheme) {
      if (theme === 'light') {
        metaTheme.setAttribute('content', '#ffffff');
      } else if (theme === 'dark') {
        metaTheme.setAttribute('content', '#0f172a');
      } else if (theme === 'muichiro') {
        metaTheme.setAttribute('content', '#070d12');
      } else if (theme === 'highsense') {
        metaTheme.setAttribute('content', '#f8fafc');
      } else {
        metaTheme.setAttribute('content', '#0a0e17');
      }
    }
  },

  // 設定の保存
  async saveSettings() {
    const urlInput = document.getElementById('setting-webhook-url');
    if (urlInput) {
      const url = urlInput.value.trim();
      await Storage.saveSetting('webhookUrl', url);
      SyncManager.syncUrl = url;
    }

    const autoAudioCb = document.getElementById('setting-auto-audio');
    if (autoAudioCb) {
      StudyManager.autoPlayAudio = autoAudioCb.checked;
      await Storage.saveSetting('study_auto_play_audio', autoAudioCb.checked);
    }

    const themeSelect = document.getElementById('setting-mobile-theme');
    if (themeSelect) {
      this.applyTheme(themeSelect.value, true);
    }
    this.closeModal('modal-settings');
    this.showToast('✅ 設定を保存しました', 'success');
  },

  // 設定モーダルを開く際の現在の設定値流し込み
  async openSettingsModal() {
    const urlInput = document.getElementById('setting-webhook-url');
    if (urlInput) {
      urlInput.value = SyncManager.syncUrl || '';
    }
    const autoAudioCb = document.getElementById('setting-auto-audio');
    if (autoAudioCb) {
      autoAudioCb.checked = StudyManager.autoPlayAudio;
    }
    const themeSelect = document.getElementById('setting-mobile-theme');
    if (themeSelect) {
      themeSelect.value = localStorage.getItem('anki_mobile_theme') || 'bloxfruits';
    }
    this.openModal('modal-settings');
  },

  // PWA インストールプロンプト実行
  async installPwa() {
    if (this.deferredPrompt) {
      this.deferredPrompt.prompt();
      const { outcome } = await this.deferredPrompt.userChoice;
      console.log(`[PWA] Install prompt outcome: ${outcome}`);
      this.deferredPrompt = null;
      const banner = document.getElementById('pwa-install-banner');
      if (banner) banner.classList.add('hidden');
    }
  },

  // トーストメッセージ表示
  showToast(message, type = 'info') {
    const toast = document.getElementById('app-toast');
    if (!toast) return;

    toast.innerText = message;
    toast.className = `toast show ${type}`;

    setTimeout(() => {
      toast.classList.remove('show');
    }, 3200);
  },

  registerServiceWorker() {
    if ('serviceWorker' in navigator && window.location.protocol.startsWith('http')) {
      navigator.serviceWorker.register('./service-worker.js').then((reg) => {
        console.log('[SW] Registered successfully:', reg.scope);
      }).catch((err) => {
        console.warn('[SW] Registration failed:', err);
      });
    }
  },

  // キャッシュを完全に全削除して最新版を再取得
  async forceRefresh() {
    if (confirm('すべてのオフラインキャッシュを消去して最新版を取得しますか？')) {
      if ('caches' in window) {
        const keys = await caches.keys();
        await Promise.all(keys.map(k => caches.delete(k)));
      }
      if ('serviceWorker' in navigator) {
        const regs = await navigator.serviceWorker.getRegistrations();
        for (const r of regs) {
          await r.unregister();
        }
      }
      const cleanUrl = window.location.origin + window.location.pathname + '?reload=' + Date.now();
      window.location.href = cleanUrl;
    }
  }
};

window.addEventListener('DOMContentLoaded', () => {
  App.init();
});
