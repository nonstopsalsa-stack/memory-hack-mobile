/**
 * service-worker.js - MEMORY HACK Mobile PWA オフラインキャッシュ
 */

const CACHE_NAME = 'memory-hack-mobile-v1.3.6';
const ASSETS_TO_CACHE = [
  './',
  './index.html',
  './manifest.json',
  './css/mobile.css?v=1.3.6',
  './js/config.js?v=1.3.6',
  './js/storage.js?v=1.3.6',
  './js/srs.js?v=1.3.6',
  './js/hierarchy.js?v=1.3.6',
  './js/audio.js?v=1.3.6',
  './js/sync.js?v=1.3.6',
  './js/study.js?v=1.3.6',
  './js/app.js?v=1.3.6',
  './assets/icon.png'
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then(async (cache) => {
      // ネットワークから強制最新取得してキャッシュ (cache: 'reload')
      for (const asset of ASSETS_TO_CACHE) {
        try {
          const resp = await fetch(asset, { cache: 'reload' });
          if (resp.ok) await cache.put(asset, resp);
        } catch (e) {
          console.warn('[SW] Cache preload skipped:', asset, e);
        }
      }
    })
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME) {
            console.log('[SW] Deleting old cache:', key);
            return caches.delete(key);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  // GAS API通信や非GETはキャッシュしない
  if (event.request.url.includes('script.google.com') || event.request.method !== 'GET') {
    return;
  }

  // ★ ネットワーク優先 (Network-First) 戦略
  // オンライン時は常にGitHubの最新ファイルを取得し、取得成功時にキャッシュを更新。
  // オフライン時のみキャッシュから返す。
  event.respondWith(
    fetch(event.request, { cache: 'no-cache' })
      .then((networkResponse) => {
        if (networkResponse && networkResponse.status === 200) {
          const responseClone = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseClone);
          });
        }
        return networkResponse;
      })
      .catch(() => {
        // オフライン時のフォールバック
        return caches.match(event.request).then((cachedResponse) => {
          if (cachedResponse) return cachedResponse;
          if (event.request.mode === 'navigate') return caches.match('./index.html');
          return new Response('Offline', { status: 503, statusText: 'Service Unavailable' });
        });
      })
  );
});
