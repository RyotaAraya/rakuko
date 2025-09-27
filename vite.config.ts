import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import vue from '@vitejs/plugin-vue'
import { resolve } from 'path'

export default defineConfig({
  plugins: [
    RubyPlugin(),
    vue(),
  ],
  resolve: {
    alias: {
      '@': resolve(__dirname, 'frontend')
    }
  }
})
