/**
 * hierarchy.js - MEMORY HACK Mobile ジャンル3階層管理モジュール
 * 
 * 仕様:
 * - 第1階層 (category1): 例「1年教科書」「映画」「日常英会話」
 * - 第2階層 (category2): 例「Unit 1」「スター・ウォーズ」
 * - 第3階層 (category3): 例「単語」「名セリフ」
 * - フィルター形式: { level1: string, level2: string, level3: string }
 *   例: { level1: '1年教科書', level2: 'all', level3: 'all' } ➔ 第1階層すべて
 *   例: { level1: '1年教科書', level2: 'Unit 1', level3: 'all' } ➔ 第2階層すべて
 *   例: { level1: '1年教科書', level2: 'Unit 1', level3: '単語' } ➔ 個別デッキ
 */

const Hierarchy = {
  PRESET_ICONS: {
    'all': '📚',
    '1年教科書': '🏫',
    '2年教科書': '🏫',
    '3年教科書': '🏫',
    '学校': '🏫',
    'J-PREP': '🎓',
    '問題集': '📖',
    '洋書': '📚',
    '映画': '🎬',
    '日常英会話': '💬',
    'ビジネス': '💼',
    'TOEIC': '🎯',
    '英検': '🏅'
  },

  getIcon(cat1) {
    if (!cat1 || cat1 === 'all') return '📚';
    return this.PRESET_ICONS[cat1] || '📁';
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

  /**
   * カードの階層属性を正規化
   */
  normalizeCard(card) {
    if (!card) return card;

    let c1 = (card.category1 || '').trim();
    let c2 = (card.category2 || '').trim();
    let c3 = (card.category3 || '').trim();

    // category1が未設定でdeckがある場合、区切り文字（> または /）から復元
    if (!c1 && card.deck) {
      const parts = card.deck.split(/\s*>\s*|\s*\/\s*/).map(p => p.trim()).filter(Boolean);
      c1 = parts[0] || '一般';
      c2 = parts[1] || '';
      c3 = parts[2] || '';
    }

    if (!c1) c1 = '一般';

    card.category1 = c1;
    card.category2 = c2;
    card.category3 = c3;

    const parts = [c1];
    if (c2) parts.push(c2);
    if (c3) parts.push(c3);
    card.deck = parts.join(' > ');

    return card;
  },

  /**
   * 全カードから階層ツリー構造を構築
   */
  buildTree(cards) {
    const tree = {
      total: cards.length,
      categories: {}
    };

    cards.forEach(c => {
      this.normalizeCard(c);
      const c1 = c.category1;
      const c2 = c.category2;
      const c3 = c.category3;

      if (!tree.categories[c1]) {
        tree.categories[c1] = {
          count: 0,
          icon: this.getIcon(c1),
          sub: {} // cat2
        };
      }
      tree.categories[c1].count += 1;

      if (c2) {
        if (!tree.categories[c1].sub[c2]) {
          tree.categories[c1].sub[c2] = {
            count: 0,
            sub: {} // cat3
          };
        }
        tree.categories[c1].sub[c2].count += 1;

        if (c3) {
          if (!tree.categories[c1].sub[c2].sub[c3]) {
            tree.categories[c1].sub[c2].sub[c3] = 0;
          }
          tree.categories[c1].sub[c2].sub[c3] += 1;
        }
      }
    });

    return tree;
  },

  /**
   * カードが指定のフィルターに合致するか判定
   */
  matchesFilter(card, filter) {
    if (!filter || filter.level1 === 'all' || !filter.level1) return true;
    this.normalizeCard(card);

    if (card.category1 !== filter.level1) return false;
    if (filter.level2 === 'all' || !filter.level2) return true;

    if (card.category2 !== filter.level2) return false;
    if (filter.level3 === 'all' || !filter.level3) return true;

    return card.category3 === filter.level3;
  },

  matches(card, filter) {
    return this.matchesFilter(card, filter);
  },

  /**
   * パンくず表示文字列の生成
   */
  formatBreadcrumb(filter) {
    if (!filter || filter.level1 === 'all' || !filter.level1) {
      return '📚 すべてのデッキ';
    }
    const icon = this.getIcon(filter.level1);

    if (!filter.level2 || filter.level2 === 'all') {
      return `${icon} ${filter.level1} (すべて)`;
    }

    if (!filter.level3 || filter.level3 === 'all') {
      return `${icon} ${filter.level1} › ${filter.level2}`;
    }

    return `${icon} ${filter.level1} › ${filter.level2} › ${filter.level3}`;
  },

  /**
   * フィルターが一致しているか判定
   */
  isFilterEqual(a, b) {
    if (!a && !b) return true;
    if (!a || !b) return false;
    const a1 = a.level1 || 'all';
    const a2 = a.level2 || 'all';
    const a3 = a.level3 || 'all';
    const b1 = b.level1 || 'all';
    const b2 = b.level2 || 'all';
    const b3 = b.level3 || 'all';
    return a1 === b1 && a2 === b2 && a3 === b3;
  },

  /**
   * ボトムシート用のアコーディオンツリーHTMLを描画しイベントを結線
   * @param {HTMLElement} container - ボトムシート内のツリー描画コンテナ
   * @param {Array} cards - 全カード配列
   * @param {Object} currentFilter - 現在選択中のフィルター { level1, level2, level3 }
   * @param {Function} onSelect - 選択決定時コールバック (filter) => void
   */
  renderTreeSheet(container, cards, currentFilter, onSelect) {
    if (!container) return;
    const tree = this.buildTree(cards || []);
    const filter = currentFilter || { level1: 'all', level2: 'all', level3: 'all' };

    const isAllActive = !filter.level1 || filter.level1 === 'all';

    let html = `
      <!-- 最上位: すべてのカード (ALL) -->
      <div class="hierarchy-tree-item all-item ${isAllActive ? 'active' : ''}" data-l1="all" data-l2="all" data-l3="all">
        <div class="hierarchy-item-left">
          <span class="hierarchy-icon">📚</span>
          <div class="hierarchy-item-info">
            <span class="hierarchy-item-name">すべてのカード (ALL)</span>
            <span class="hierarchy-item-sub">全デッキ対象</span>
          </div>
        </div>
        <div class="hierarchy-item-right">
          <span class="hierarchy-count-badge">${tree.total}枚</span>
          <button class="btn-tree-select ${isAllActive ? 'selected' : ''}">選択</button>
        </div>
      </div>

      <div class="hierarchy-tree-separator"><span>ジャンル別階層ツリー</span></div>
      <div class="hierarchy-tree-list">
    `;

    const cat1Keys = Object.keys(tree.categories).sort((a, b) => a.localeCompare(b, 'ja'));

    cat1Keys.forEach((c1, idx) => {
      const cat1Data = tree.categories[c1];
      const isC1Active = filter.level1 === c1 && (filter.level2 === 'all' || !filter.level2);
      const isC1InScope = filter.level1 === c1;
      const c2Keys = Object.keys(cat1Data.sub || {}).sort((a, b) => a.localeCompare(b, 'ja'));
      const hasC2 = c2Keys.length > 0;
      const icon = cat1Data.icon || '📁';

      // 該当階層が選択されている場合は最初からアコーディオンを開いておく
      const c1Expanded = isC1InScope;

      html += `
        <div class="hierarchy-tier1-group ${c1Expanded ? 'open' : ''}" id="tier1-group-${idx}">
          <!-- 第1階層ヘッダー -->
          <div class="hierarchy-tier1-header ${isC1Active ? 'active' : ''}">
            <div class="hierarchy-tier-title" onclick="Hierarchy.toggleAccordion('tier1-group-${idx}')">
              ${hasC2 ? `<span class="accordion-arrow">${c1Expanded ? '▼' : '▶'}</span>` : '<span class="accordion-arrow empty">•</span>'}
              <span class="hierarchy-icon">${icon}</span>
              <span class="hierarchy-name">${this.escapeHtml(c1)}</span>
            </div>

            <div class="hierarchy-actions">
              <span class="hierarchy-count-badge">${cat1Data.count}枚</span>
              <!-- 第1階層すべて選択ボタン -->
              <button class="btn-tier-select ${isC1Active ? 'selected' : ''}" 
                data-l1="${this.escapeHtml(c1)}" data-l2="all" data-l3="all"
                title="${this.escapeHtml(c1)} すべてを選択">
                ${isC1Active ? '✓ 選択中' : '第1階層すべて'}
              </button>
            </div>
          </div>

          <!-- 第2階層コンテナ -->
          ${hasC2 ? `
            <div class="hierarchy-tier2-container ${c1Expanded ? '' : 'hidden'}">
              ${c2Keys.map((c2, c2Idx) => {
                const cat2Data = cat1Data.sub[c2];
                const isC2Active = filter.level1 === c1 && filter.level2 === c2 && (filter.level3 === 'all' || !filter.level3);
                const isC2InScope = filter.level1 === c1 && filter.level2 === c2;
                const c3Keys = Object.keys(cat2Data.sub || {}).sort((a, b) => a.localeCompare(b, 'ja'));
                const hasC3 = c3Keys.length > 0;
                const c2Expanded = isC2InScope;
                const c2GroupId = `tier2-group-${idx}-${c2Idx}`;

                return `
                  <div class="hierarchy-tier2-group ${c2Expanded ? 'open' : ''}" id="${c2GroupId}">
                    <div class="hierarchy-tier2-header ${isC2Active ? 'active' : ''}">
                      <div class="hierarchy-tier-title" onclick="Hierarchy.toggleAccordion('${c2GroupId}')">
                        ${hasC3 ? `<span class="accordion-arrow">${c2Expanded ? '▼' : '▶'}</span>` : '<span class="accordion-arrow empty">└</span>'}
                        <span class="hierarchy-icon">📁</span>
                        <span class="hierarchy-name">${this.escapeHtml(c2)}</span>
                      </div>

                      <div class="hierarchy-actions">
                        <span class="hierarchy-count-badge tier2">${cat2Data.count}枚</span>
                        <!-- 第2階層すべて選択ボタン -->
                        <button class="btn-tier-select tier2 ${isC2Active ? 'selected' : ''}"
                          data-l1="${this.escapeHtml(c1)}" data-l2="${this.escapeHtml(c2)}" data-l3="all"
                          title="${this.escapeHtml(c2)} すべてを選択">
                          ${isC2Active ? '✓ 選択中' : '第2階層すべて'}
                        </button>
                      </div>
                    </div>

                    <!-- 第3階層（個別デッキ）コンテナ -->
                    ${hasC3 ? `
                      <div class="hierarchy-tier3-container ${c2Expanded ? '' : 'hidden'}">
                        ${c3Keys.map(c3 => {
                          const c3Count = cat2Data.sub[c3];
                          const isC3Active = filter.level1 === c1 && filter.level2 === c2 && filter.level3 === c3;

                          return `
                            <div class="hierarchy-tier3-item ${isC3Active ? 'active' : ''}">
                              <div class="hierarchy-tier-title">
                                <span class="accordion-arrow empty">└─</span>
                                <span class="hierarchy-icon">📄</span>
                                <span class="hierarchy-name">${this.escapeHtml(c3)}</span>
                              </div>

                              <div class="hierarchy-actions">
                                <span class="hierarchy-count-badge tier3">${c3Count}枚</span>
                                <button class="btn-tier-select tier3 ${isC3Active ? 'selected' : ''}"
                                  data-l1="${this.escapeHtml(c1)}" data-l2="${this.escapeHtml(c2)}" data-l3="${this.escapeHtml(c3)}"
                                  title="個別デッキ「${this.escapeHtml(c3)}」を選択">
                                  ${isC3Active ? '✓ 選択中' : '個別選択'}
                                </button>
                              </div>
                            </div>
                          `;
                        }).join('')}
                      </div>
                    ` : ''}
                  </div>
                `;
              }).join('')}
            </div>
          ` : ''}
        </div>
      `;
    });

    html += `</div>`;
    container.innerHTML = html;

    // クリックイベントの結線
    container.querySelectorAll('button[data-l1], .hierarchy-tree-item[data-l1]').forEach(elem => {
      elem.addEventListener('click', (e) => {
        e.stopPropagation();
        const l1 = elem.getAttribute('data-l1') || 'all';
        const l2 = elem.getAttribute('data-l2') || 'all';
        const l3 = elem.getAttribute('data-l3') || 'all';

        const selectedFilter = { level1: l1, level2: l2, level3: l3 };
        if (typeof onSelect === 'function') {
          onSelect(selectedFilter);
        }
      });
    });
  },

  /**
   * アコーディオンの開閉トグル
   */
  toggleAccordion(groupId) {
    const group = document.getElementById(groupId);
    if (!group) return;

    const isOpen = group.classList.contains('open');
    if (isOpen) {
      group.classList.remove('open');
      const arrow = group.querySelector(':scope > div .accordion-arrow');
      if (arrow && arrow.innerText !== '•' && arrow.innerText !== '└') arrow.innerText = '▶';
      const container = group.querySelector(':scope > div:last-child');
      if (container && container !== group.firstElementChild) container.classList.add('hidden');
    } else {
      group.classList.add('open');
      const arrow = group.querySelector(':scope > div .accordion-arrow');
      if (arrow && arrow.innerText !== '•' && arrow.innerText !== '└') arrow.innerText = '▼';
      const container = group.querySelector(':scope > div:last-child');
      if (container && container !== group.firstElementChild) container.classList.remove('hidden');
    }
  }
};

if (typeof window !== 'undefined') {
  window.Hierarchy = Hierarchy;
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = Hierarchy;
}
