/**
 * service-worker.js - MEMORY HACK Mobile PWA オフラインキャッシュ
 */

const CACHE_NAME = 'memory-hack-mobile-v1.1.0';
const ASSETS_TO_CACHE = [
  './',
  './index.html',
  './manifest.json',
  './css/mobile.css',
  './js/config.js',
  './js/storage.js',
  './js/srs.js',
  './js/hierarchy.js',
  './js/sync.js',
  './js/audio.js',
  './js/study.js',
  './js/app.js',
  './assets/icon.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(ASSETS_TO_CACHE);
    }).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME) {
            return caches.delete(key);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  // GAS API通信や外部リクエストはキャッシュしない（常にネットワーク優先）
  if (event.request.url.includes('script.google.com') || event.request.method !== 'GET') {
    return;
  }

  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      if (cachedResponse) {
        // キャッシュがあれば即返しつつ、バックグラウンドで最新を取得（Stale-While-Revalidate）
        fetch(event.request).then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(event.request, networkResponse);
            });
          }
        }).catch(() => {});
        return cachedResponse;
      }
      return fetch(event.request);
    })
  );
});
