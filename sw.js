// 門診時段交叉查詢與醫師代碼查詢系統 - PWA Service Worker (v0.9.9)
const CACHE_NAME = 'opd-pwa-v0.9.9';
const ASSETS_TO_CACHE = [
  './',
  './index.html',
  './manifest.json',
  './apple-touch-icon.png',
  './icon-192.png',
  './icon-512.png'
];

// 安裝事件：預先載入核心資源
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(ASSETS_TO_CACHE);
    }).then(() => self.skipWaiting())
  );
});

// 啟動事件：清除舊版快取並接管頁面
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((name) => {
          if (name !== CACHE_NAME) {
            return caches.delete(name);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// 擷取事件：Stale-While-Revalidate 策略（優先快取秒開，背景檢查更新）
self.addEventListener('fetch', (event) => {
  // 只處理 GET 請求
  if (event.request.method !== 'GET') return;

  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      const fetchPromise = fetch(event.request)
        .then((networkResponse) => {
          // 確保回應有效且為同源或可快取資源
          if (networkResponse && networkResponse.status === 200) {
            const responseClone = networkResponse.clone();
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(event.request, responseClone);
            });
          }
          return networkResponse;
        })
        .catch(() => {
          // 網路離線時保持安靜，已由 cachedResponse 承接
        });

      // 若有快取立即回傳；若無快取則等待網路回傳
      return cachedResponse || fetchPromise;
    })
  );
});
