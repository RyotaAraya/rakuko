// To see this message, add the following to the `<head>` section in your
// views/layouts/application.html.erb
//
//    <%= vite_client_tag %>
//    <%= vite_javascript_tag 'application' %>

import '../styles/application.css'
import type { App } from 'vue'
import { createApp } from 'vue'
import AttendanceToday from '../components/AttendanceToday.vue'
import ShiftRequestForm from '../components/ShiftRequestForm.vue'
import WelcomeMessage from '../components/WelcomeMessage.vue'

interface VueAppElement extends HTMLElement {
  _vueApp?: App
}

function initializeVueComponents() {
  // Welcome message component
  const welcomeEl = document.getElementById('vue-app') as VueAppElement | null
  if (welcomeEl && !welcomeEl._vueApp) {
    welcomeEl._vueApp = createApp(WelcomeMessage).mount(welcomeEl) as App
  }

  // Shift request form component
  const shiftFormEl = document.getElementById('shift-request-form') as VueAppElement | null

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

  // Attendance today component
  const attendanceEl = document.getElementById('attendance-app') as VueAppElement | null
  if (attendanceEl && !attendanceEl._vueApp) {
    try {
      const loadingEl = document.getElementById('loading-message')
      if (loadingEl) {
        loadingEl.remove()
      }

      const date = attendanceEl.dataset.date || new Date().toISOString().split('T')[0]

      const app = createApp(AttendanceToday, { date })
      attendanceEl._vueApp = app.mount(attendanceEl) as App
    } catch (error) {
      console.error('Error mounting Attendance app:', error)
    }
  }

  // Home page attendance component
  const homeAttendanceEl = document.getElementById('home-attendance-app') as VueAppElement | null
  if (homeAttendanceEl && !homeAttendanceEl._vueApp) {
    try {
      const loadingEl = document.getElementById('home-loading-message')
      if (loadingEl) {
        loadingEl.remove()
      }

      const date = homeAttendanceEl.dataset.date || new Date().toISOString().split('T')[0]

      const app = createApp(AttendanceToday, { date })
      homeAttendanceEl._vueApp = app.mount(homeAttendanceEl) as App
    } catch (error) {
      console.error('Error mounting Home Attendance app:', error)
    }
  }
}

function tryInitialize() {
  // Vue.jsコンポーネントを使用するページかどうかを確認
  const isShiftRequestPage = window.location.pathname.includes('/shift_requests/new')
  const isAttendancePage = window.location.pathname.includes('/attendances/today')
  const isHomePage = window.location.pathname === '/' || window.location.pathname === '/home/index'

  if (!isShiftRequestPage && !isAttendancePage && !isHomePage) {
    return true // 初期化が必要ないページでは成功とみなす
  }

  // HTML要素が存在するかチェック
  const shiftFormEl = document.getElementById('shift-request-form')
  const attendanceEl = document.getElementById('attendance-app')
  const homeAttendanceEl = document.getElementById('home-attendance-app')

  if (shiftFormEl || attendanceEl || homeAttendanceEl) {
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

// フォールバック: 定期的にチェック（Vue.jsを使用するページのみ）
const isShiftRequestPage = window.location.pathname.includes('/shift_requests/new')
const isAttendancePage = window.location.pathname.includes('/attendances/today')
const isHomePage = window.location.pathname === '/' || window.location.pathname === '/home/index'
if (isShiftRequestPage || isAttendancePage || isHomePage) {
  let attempts = 0
  const maxAttempts = 30
  const checkInterval = setInterval(() => {
    attempts++

    if (tryInitialize() || attempts >= maxAttempts) {
      clearInterval(checkInterval)
    }
  }, 100)
}
