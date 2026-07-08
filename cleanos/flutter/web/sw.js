// Kill-switch do PWA React antigo (vite-plugin-pwa/workbox).
// Os navegadores que têm o sw.js antigo registrado fazem update-check desta URL;
// esta versão assume o controle, apaga TODOS os caches, desregistra o próprio
// service worker e recarrega as janelas abertas — que então baixam o app novo
// (Flutter) da rede. O Flutter registra o flutter_service_worker.js dele depois.
self.addEventListener('install', function () {
  self.skipWaiting();
});
self.addEventListener('activate', function (event) {
  event.waitUntil(
    (async function () {
      try {
        const keys = await caches.keys();
        await Promise.all(keys.map(function (k) { return caches.delete(k); }));
      } catch (_) {}
      try {
        await self.registration.unregister();
      } catch (_) {}
      const clients = await self.clients.matchAll({ type: 'window' });
      clients.forEach(function (client) {
        try { client.navigate(client.url); } catch (_) {}
      });
    })()
  );
});
