/**
 * config.js - MEMORY HACK Mobile 設定ファイル
 */

window.APP_CONFIG = {
  // MEMORY HACK Master System の Google Apps Script Webhook URL
  defaultWebhookUrl: "https://script.google.com/macros/s/AKfycbzON4NqSVx_YOfqZgsU3fdpwSaEB9eAWb9dmv8_OT6o-Dafa0P09hxKHAl6HW2lnfHrtA/exec",
  // 起動時の自動クラウド更新チェック
  autoSyncEnabled: true,
  // 音声の初期読み上げ速度 (0.9 = やや聞き取りやすい自然な速度)
  speechRate: 0.9,
  // アプリバージョン
  version: "v2.2.0"
};

// 10言語メタデータレジストリ (PC Master System 完全互換)
window.SUPPORTED_LANGUAGES = {
  'en-US': { name: '英語 (アメリカ)', short: '英', flag: '🇺🇸', voiceLang: 'en-US' },
  'en-GB': { name: '英語 (イギリス)', short: '英', flag: '🇬🇧', voiceLang: 'en-GB' },
  'es-ES': { name: 'スペイン語', short: '西', flag: '🇪🇸', voiceLang: 'es-ES' },
  'zh-CN': { name: '中国語 (簡体字)', short: '中', flag: '🇨🇳', voiceLang: 'zh-CN' },
  'zh-HK': { name: '広東語 (香港)', short: '粤', flag: '🇭🇰', voiceLang: 'zh-HK' },
  'zh-TW': { name: '台湾華語 (繁体字)', short: '台', flag: '🇹🇼', voiceLang: 'zh-TW' },
  'ko-KR': { name: '韓国語', short: '韓', flag: '🇰🇷', voiceLang: 'ko-KR' },
  'fr-FR': { name: 'フランス語', short: '仏', flag: '🇫🇷', voiceLang: 'fr-FR' },
  'it-IT': { name: 'イタリア語', short: '伊', flag: '🇮🇹', voiceLang: 'it-IT' },
  'de-DE': { name: 'ドイツ語', short: '独', flag: '🇩🇪', voiceLang: 'de-DE' }
};