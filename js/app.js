/**
 * app.js - MEMORY HACK Mobile アプリケーション統括コントローラー
 */

const App = {
  deferredPrompt: null,

  async init() {
    console.log('[App] MEMORY HACK Mobile v2.2.6 Initializing...');

    // 0. テーマ初期化 (デフォルトは正式な「ライト」)
    try {
      const savedTheme = localStorage.getItem('anki_mobile_theme');
      const initialTheme = (savedTheme === 'highsense' || !savedTheme) ? 'light' : savedTheme;
      this.applyTheme(initialTheme, false);
    } catch (e) {
      console.warn('[App] Theme init error:', e);
    }

    // 1. 各マネージャーの初期化
    try {
      if (typeof AudioManager !== 'undefined') AudioManager.init();
      if (typeof SyncManager !== 'undefined') await SyncManager.init();
      if (typeof StudyManager !== 'undefined') await StudyManager.init();
      await this.updateProjectPill();
    } catch (e) {
      console.error('[App] Manager init error:', e);
    }

    // 起動トースト表示
    this.showToast('🚀 MEMORY HACK Mobile v2.2.6 準備完了', 'info');

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

    // 出題パターンチェックボックス変更イベント委譲
    const modalPatterns = document.getElementById('modal-patterns');
    if (modalPatterns) {
      modalPatterns.addEventListener('change', (e) => {
        if (e.target && e.target.name === 'pattern_checkbox') {
          this.onPatternChange();
        }
      });
    }

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

  // 第0階層（プロジェクト選択）およびデッキトリガーの表示更新
  async updateProjectPill() {
    try {
      const activeProj = (typeof Storage !== 'undefined' && Storage.getActiveProject)
        ? await Storage.getActiveProject()
        : { name: '哲生英語', icon: '🇬🇧' };

      const iconEl = document.getElementById('project-icon');
      const nameEl = document.getElementById('project-name');
      if (iconEl) iconEl.innerText = activeProj.icon || '📁';
      if (nameEl) nameEl.innerText = activeProj.name || '教科';

      // v2.2.1: パンくず統合デッキ選択ボタンの表示も同期更新
      if (typeof StudyManager !== 'undefined' && StudyManager.updateDeckTriggerButton) {
        StudyManager.updateDeckTriggerButton();
      }
    } catch (e) {
      console.warn('[App] updateProjectPill failed:', e);
    }
  },

  // 第0階層プロジェクト選択ボトムシートのオープン（統合階層モーダルへ統一）
  async openProjectModal() {
    await this.openHierarchyModal();
  },

  // プロジェクト一覧ボトムシートの動的レンダリング
  async renderProjectList() {
    const container = document.getElementById('project-list-container');
    if (!container || typeof Storage === 'undefined') return;

    const projects = await Storage.getProjects();
    const activeId = await Storage.getActiveProjectId();
    const allCards = await Storage.getAllCards();

    let html = '';
    projects.forEach(p => {
      const isActive = p.id === activeId;
      const count = (typeof StudyManager !== 'undefined' && StudyManager.filterCardsForProject)
        ? StudyManager.filterCardsForProject(allCards, p.id, projects).length
        : allCards.filter(c => (c.projectDeckId || 'deck_default') === p.id).length;

      const desc = p.description || (p.cardType === 'kanji' ? '漢字検定・書き取り特訓' : `${p.targetLanguage || '外国語'} 学習`);

      html += `
        <div class="project-item ${isActive ? 'active' : ''}" onclick="App.switchProject('${p.id}')">
          <div class="project-item-left">
            <span class="project-item-icon">${p.icon || '📁'}</span>
            <div class="project-item-info">
              <span class="project-item-name">${this.escapeHtml(p.name)}</span>
              <span class="project-item-desc">${this.escapeHtml(desc)}</span>
            </div>
          </div>
          <div class="project-item-right">
            <span class="project-card-badge">${count}枚</span>
            <button class="btn-project-select ${isActive ? 'selected' : ''}">
              ${isActive ? '✓ 選択中' : '選択'}
            </button>
          </div>
        </div>
      `;
    });

    container.innerHTML = html;
  },

  // 第0階層プロジェクト切り替え実行
  async switchProject(projectId) {
    if (!projectId) return;
    try {
      await Storage.setActiveProjectId(projectId);
      if (typeof StudyManager !== 'undefined' && StudyManager.switchProject) {
        await StudyManager.switchProject(projectId);
      }
      await this.updateProjectPill();
      this.closeModal('modal-project');

      const activeProj = await Storage.getActiveProject();
      const count = (typeof StudyManager !== 'undefined' && StudyManager.cards) ? StudyManager.cards.length : 0;
      this.showToast(`📁 「${activeProj.icon || ''} ${activeProj.name}」を選択しました (${count}枚)`, 'info');
    } catch (e) {
      console.error('[App] switchProject error:', e);
      this.showToast('❌ プロジェクトの切り替えに失敗しました', 'error');
    }
  },

  escapeHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  },

  // デッキツリー階層選択ボトムシートのオープン（第0階層統合型）
  async openHierarchyModal() {
    const container = document.getElementById('hierarchy-tree-container');
    if (container && typeof Hierarchy !== 'undefined') {
      const projects = (typeof Storage !== 'undefined') ? await Storage.getProjects() : [];
      const activeProjectId = (typeof Storage !== 'undefined') ? await Storage.getActiveProjectId() : 'deck_default';
      const allCards = (typeof Storage !== 'undefined') ? await Storage.getAllCards() : (StudyManager.allCards || []);

      Hierarchy.renderTreeSheet(
        container,
        StudyManager.cards,
        StudyManager.selectedFilter,
        async (filter) => {
          await StudyManager.setHierarchyFilter(filter);
          this.closeModal('modal-hierarchy');
          this.showToast(`📚 「${Hierarchy.formatBreadcrumb(filter)}」を選択しました`, 'info');
        },
        {
          projects,
          activeProjectId,
          allCards,
          onProjectSelect: async (projId) => {
            if (projId === activeProjectId) return;
            await Storage.setActiveProjectId(projId);
            if (typeof StudyManager !== 'undefined' && StudyManager.switchProject) {
              await StudyManager.switchProject(projId);
            }
            await this.updateProjectPill();
            const activeProj = projects.find(p => p.id === projId) || { name: '教科', icon: '📁' };
            const count = (StudyManager && StudyManager.cards) ? StudyManager.cards.length : 0;
            this.showToast(`📁 「${activeProj.icon || ''} ${activeProj.name}」を選択しました (${count}枚)`, 'info');
            // モーダルを開いたまま即時再描画
            await this.openHierarchyModal();
          }
        }
      );
    }
    this.openModal('modal-hierarchy');
  },

  // モーダル操作
  openModal(id) {
    if (id === 'modal-patterns' && typeof StudyManager !== 'undefined') {
      StudyManager.renderPatternSelector();
    }
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

  // 出題パターンチェック変更（語学・漢字・汎用 3大体系連動）
  async onPatternChange() {
    const cardType = (typeof StudyManager !== 'undefined' && StudyManager.getCurrentCardType)
      ? StudyManager.getCurrentCardType()
      : 'language';
    const defaultPattern = cardType === 'kanji' ? 'char_to_read' : (cardType === 'general' ? 'front_to_back' : 'en_to_ja');
    let checked = Array.from(document.querySelectorAll('input[name="pattern_checkbox"]:checked')).map(c => c.value);

    if (cardType === 'kanji') {
      checked = StudyManager.sanitizeKanjiPatterns(checked);
      StudyManager.activePatternsKanji = checked;
      await Storage.saveSetting('study_active_patterns_kanji', checked);
    } else if (cardType === 'language') {
      checked = StudyManager.sanitizeLanguagePatterns(checked);
      if (checked.length === 0) checked = [defaultPattern];
      StudyManager.activePatternsLanguage = checked;
      await Storage.saveSetting('study_active_patterns_language', checked);
    } else {
      checked = StudyManager.sanitizeUniversalPatterns(checked);
      if (checked.length === 0) checked = [defaultPattern];
      StudyManager.activePatternsUniversal = checked;
      StudyManager.activePatterns = checked;
      await Storage.saveSetting('study_active_patterns_universal', checked);
    }

    StudyManager.renderPatternSelector();

    if (StudyManager.currentCard && !StudyManager.isFlipped) {
      StudyManager.pickCurrentPattern();
      StudyManager.renderCard();
    }
  },

  // 出題パターン全選択/解除（語学・漢字・汎用 3大体系連動）
  async toggleAllPatterns(selectAll) {
    const cardType = (typeof StudyManager !== 'undefined' && StudyManager.getCurrentCardType)
      ? StudyManager.getCurrentCardType()
      : 'language';
    const defaultPattern = cardType === 'kanji' ? 'char_to_read' : (cardType === 'general' ? 'front_to_back' : 'en_to_ja');
    const checkboxes = document.querySelectorAll('input[name="pattern_checkbox"]');
    checkboxes.forEach(cb => cb.checked = selectAll);
    if (!selectAll) {
      const def = document.querySelector(`input[name="pattern_checkbox"][value="${defaultPattern}"]`);
      if (def) def.checked = true;
    }
    let checked = Array.from(document.querySelectorAll('input[name="pattern_checkbox"]:checked')).map(c => c.value);

    if (cardType === 'kanji') {
      checked = StudyManager.sanitizeKanjiPatterns(checked);
      StudyManager.activePatternsKanji = checked;
      await Storage.saveSetting('study_active_patterns_kanji', checked);
    } else if (cardType === 'language') {
      checked = StudyManager.sanitizeLanguagePatterns(checked);
      if (checked.length === 0) checked = [defaultPattern];
      StudyManager.activePatternsLanguage = checked;
      await Storage.saveSetting('study_active_patterns_language', checked);
    } else {
      checked = StudyManager.sanitizeUniversalPatterns(checked);
      if (checked.length === 0) checked = [defaultPattern];
      StudyManager.activePatternsUniversal = checked;
      StudyManager.activePatterns = checked;
      await Storage.saveSetting('study_active_patterns_universal', checked);
    }

    StudyManager.renderPatternSelector();

    if (StudyManager.currentCard && !StudyManager.isFlipped) {
      StudyManager.pickCurrentPattern();
      StudyManager.renderCard();
    }
  },

  // テーマ適用 (bloxfruits / light / dark)
  // テーマ適用 (light / dark / bloxfruits / muichiro)
  applyTheme(theme, save = true) {
    if (!theme || theme === 'highsense') theme = 'light';
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
        metaTheme.setAttribute('content', '#f8fafc');
      } else if (theme === 'dark') {
        metaTheme.setAttribute('content', '#0f172a');
      } else if (theme === 'muichiro') {
        metaTheme.setAttribute('content', '#a7f3d0');
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

    const profSelect = document.getElementById('setting-device-profile');
    if (profSelect) {
      await Storage.saveSetting('deviceProfile', profSelect.value);
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
    const profSelect = document.getElementById('setting-device-profile');
    if (profSelect) {
      profSelect.value = await Storage.getSetting('deviceProfile', 'all');
    }
    const themeSelect = document.getElementById('setting-mobile-theme');
    if (themeSelect) {
      const currentTheme = localStorage.getItem('anki_mobile_theme');
      themeSelect.value = (currentTheme === 'highsense' || !currentTheme) ? 'light' : currentTheme;
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
      navigator.serviceWorker.register('./service-worker.js?v=2.2.3', { updateViaCache: 'none' }).then((reg) => {
        console.log('[SW] Registered successfully:', reg.scope);
        // 起動時に毎回バックグラウンドで最新SWの存在を即時チェック
        reg.update().catch(() => {});
        reg.onupdatefound = () => {
          const installingWorker = reg.installing;
          if (installingWorker) {
            installingWorker.onstatechange = () => {
              if (installingWorker.state === 'installed' && navigator.serviceWorker.controller) {
                console.log('[SW] New version installed, reloading page for seamless update...');
                window.location.reload();
              }
            };
          }
        };
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
