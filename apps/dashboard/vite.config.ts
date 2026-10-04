/// <reference types="vitest/config" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 5173,
    // Dev: proxy /api to the NestJS server so the dashboard and API share an origin.
    proxy: { '/api': { target: process.env.VITE_API_PROXY ?? 'http://localhost:3000', rewrite: (p) => p.replace(/^\/api/, ''), ws: true } },
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test-setup.ts'],
    include: ['src/**/*.test.{ts,tsx}'],
    globals: true,
    css: false,
  },
});
