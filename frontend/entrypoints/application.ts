// To see this message, add the following to the `<head>` section in your
// views/layouts/application.html.erb
//
//    <%= vite_client_tag %>
//    <%= vite_javascript_tag 'application' %>

import '../styles/application.css'
import { createApp } from 'vue'
import ShiftRequestForm from '../components/ShiftRequestForm.vue'
import WelcomeMessage from '../components/WelcomeMessage.vue'

function initializeVueComponents() {
  // Welcome message component
  const welcomeEl = document.getElementById('vue-app') as HTMLElement & { _vueApp?: any }
  if (welcomeEl && !welcomeEl._vueApp) {
    welcomeEl._vueApp = createApp(WelcomeMessage).mount(welcomeEl)
  }

  // Shift request form component
  const shiftFormEl = document.getElementById('shift-request-form') as HTMLElement & {
    _vueApp?: any
  }

  if (shiftFormEl && !shiftFormEl._vueApp) {
    try {
      // ローディングメッセージを削除
      const loadingEl = document.getElementById('loading-message')
      if (loadingEl) {
        loadingEl.remove()
      }

      // データ属性からpropsを取得
      let weeksData = []
      let initialData = {}

      try {
        weeksData = shiftFormEl.dataset.weeks ? JSON.parse(shiftFormEl.dataset.weeks) : []
      } catch (_e) {
        weeksData = []
      }

      try {
        initialData = shiftFormEl.dataset.initial ? JSON.parse(shiftFormEl.dataset.initial) : {}
      } catch (_e) {
        initialData = {}
      }

      const targetYear = parseInt(shiftFormEl.dataset.year || '0', 10) || new Date().getFullYear()
      const targetMonth =
        parseInt(shiftFormEl.dataset.month || '0', 10) || new Date().getMonth() + 1

      const app = createApp(ShiftRequestForm, {
        weeksData,
        initialData,
        targetYear,
        targetMonth,
      })

      shiftFormEl._vueApp = app.mount(shiftFormEl)
    } catch (error) {
      console.error('Error mounting Vue app:', error)
    }
  }
}

function tryInitialize() {
  // シフトリクエストページかどうかを確認
  const isShiftRequestPage = window.location.pathname.includes('/shift_requests/new')

  if (!isShiftRequestPage) {
    return true // 初期化が必要ないページでは成功とみなす
  }

  // HTML要素が存在するかチェック
  const shiftFormEl = document.getElementById('shift-request-form')

  if (shiftFormEl) {
    initializeVueComponents()
    return true
  }
  return false
}

// 複数のタイミングで初期化を試行
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    setTimeout(tryInitialize, 50)
  })
} else {
  tryInitialize()
}

// フォールバック: windowのloadイベント
window.addEventListener('load', () => {
  if (!tryInitialize()) {
    setTimeout(() => {
      tryInitialize()
    }, 500)
  }
})

// フォールバック: 定期的にチェック（シフトリクエストページのみ）
const isShiftRequestPage = window.location.pathname.includes('/shift_requests/new')
if (isShiftRequestPage) {
  let attempts = 0
  const maxAttempts = 30
  const checkInterval = setInterval(() => {
    attempts++

    if (tryInitialize() || attempts >= maxAttempts) {
      clearInterval(checkInterval)
    }
  }, 100)
}
