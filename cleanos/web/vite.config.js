import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';
export default defineConfig({
    plugins: [
        react(),
        VitePWA({
            registerType: 'autoUpdate',
            devOptions: { enabled: true },
            workbox: {
                globPatterns: ['**/*.{js,css,html,ico,svg,png,woff2}'],
                // Dados de API (OS, clientes) NÃO são cacheados: risco LGPD + "endereço some".
                // O SW cobre apenas os assets estáticos listados em globPatterns.
                skipWaiting: true,
                clientsClaim: true,
                cleanupOutdatedCaches: true,
            },
            manifest: {
                name: 'CleanOS — Cleanox',
                short_name: 'CleanOS',
                description: 'Sistema de gestão interno da Cleanox',
                theme_color: '#0F4C5C',
                background_color: '#FFFFFF',
                display: 'standalone',
                orientation: 'portrait',
                start_url: '/',
                scope: '/',
                lang: 'pt-BR',
                icons: [
                    {
                        src: 'icon.svg',
                        sizes: 'any',
                        type: 'image/svg+xml',
                        purpose: 'any',
                    },
                    {
                        src: 'icon-maskable.svg',
                        sizes: 'any',
                        type: 'image/svg+xml',
                        purpose: 'maskable',
                    },
                ],
            },
        }),
    ],
});
