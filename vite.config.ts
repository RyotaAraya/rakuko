import { resolve } from 'node:path'
import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

export default defineConfig({
  plugins: [RubyPlugin(), vue()],
  resolve: {
    alias: {
      '@': resolve(__dirname, 'frontend'),
    },
  },
})
