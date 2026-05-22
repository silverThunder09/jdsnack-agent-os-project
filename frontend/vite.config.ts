import react from '@vitejs/plugin-react'
import { defineConfig } from 'vitest/config'

const apiProxyTarget = process.env.VITE_API_PROXY_TARGET ?? 'http://localhost:8080'

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': {
        target: apiProxyTarget,
        changeOrigin: true,
      },
    },
  },
  test: {
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
    css: true,
  },
})
