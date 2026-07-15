// Kill-switch de Service Workers legados (React PWA + Flutter SW desalinhado).
// Qualquer navegador que ainda aponte para /sw.js (frontend antigo) ou que
// tenha cache corrompido: limpa caches, desregistra e recarrega.
// v3 — 2026-07-15 (tela branca pós-login)
self.addEventListener('install', function () {
  self.skipWaiting();
});
self.addEventListener('activate', function (event) {
  event.waitUntil(
    (async function () {
      try {
        var keys = await caches.keys();
        await Promise.all(keys.map(function (k) { return caches.delete(k); }));
      } catch (_) {}
      try {
        await self.registration.unregister();
      } catch (_) {}
      try {
        var clients = await self.clients.matchAll({ type: 'window' });
        clients.forEach(function (client) {
          try { client.navigate(client.url); } catch (_) {}
        });
      } catch (_) {}
    })()
  );
});
