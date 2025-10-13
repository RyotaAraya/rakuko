<template>
  <div>
    <h2 class="text-xl font-bold mb-4">今日の勤怠 {{ dateDisplay }}</h2>

    <!-- 打刻ボタン -->
    <div class="bg-white border border-gray-300 rounded-lg p-6 mb-5">
      <div class="font-bold mb-4 text-base text-gray-800">打刻</div>
      <div class="grid grid-cols-2 gap-4 md:grid-cols-4">
        <button
          type="button"
          class="px-6 py-4 rounded text-base font-bold transition-colors"
          :class="isClockInDisabled ? 'bg-gray-300 text-gray-500 cursor-not-allowed' : 'bg-blue-600 text-white hover:bg-blue-700'"
          :disabled="isClockInDisabled"
          @click="clockIn"
        >
          出勤
        </button>
        <button
          type="button"
          class="px-6 py-4 rounded text-base font-bold transition-colors"
          :class="isBreakStartDisabled ? 'bg-gray-300 text-gray-500 cursor-not-allowed' : 'bg-green-600 text-white hover:bg-green-700'"
          :disabled="isBreakStartDisabled"
          @click="breakStart"
        >
          休憩開始
        </button>
        <button
          type="button"
          class="px-6 py-4 rounded text-base font-bold transition-colors"
          :class="isBreakEndDisabled ? 'bg-gray-300 text-gray-500 cursor-not-allowed' : 'bg-yellow-600 text-white hover:bg-yellow-700'"
          :disabled="isBreakEndDisabled"
          @click="breakEnd"
        >
          休憩終了
        </button>
        <button
          type="button"
          class="px-6 py-4 rounded text-base font-bold transition-colors"
          :class="isClockOutDisabled ? 'bg-gray-300 text-gray-500 cursor-not-allowed' : 'bg-red-600 text-white hover:bg-red-700'"
          :disabled="isClockOutDisabled"
          @click="clockOut"
        >
          退勤
        </button>
      </div>
    </div>

    <!-- 今日の状況 -->
    <div class="bg-white border border-gray-300 rounded-lg p-6 mb-5">
      <div class="font-bold mb-4 text-base text-gray-800">今日の状況</div>
      <div class="grid grid-cols-2 gap-4 md:grid-cols-4">
        <div class="border border-gray-200 p-4 rounded">
          <div class="text-sm text-gray-600 mb-1">出勤時刻</div>
          <div class="text-2xl font-bold">{{ summary.clock_in_time || '--:--' }}</div>
        </div>
        <div class="border border-gray-200 p-4 rounded">
          <div class="text-sm text-gray-600 mb-1">退勤時刻</div>
          <div class="text-2xl font-bold">{{ summary.clock_out_time || '--:--' }}</div>
        </div>
        <div class="border border-gray-200 p-4 rounded">
          <div class="text-sm text-gray-600 mb-1">休憩時間</div>
          <div class="text-2xl font-bold">{{ formatMinutes(summary.break_minutes) }}</div>
        </div>
        <div class="border border-gray-200 p-4 rounded">
          <div class="text-sm text-gray-600 mb-1">実労働時間</div>
          <div class="text-2xl font-bold">{{ summary.work_hours.toFixed(1) }}h</div>
        </div>
      </div>
      <div v-if="summary.is_working" class="mt-4 p-3 bg-blue-50 border border-blue-200 text-blue-800 rounded">
        ⏰ 勤務中
      </div>
    </div>

    <!-- 打刻履歴 -->
    <div class="bg-white border border-gray-300 rounded-lg p-6 mb-5">
      <div class="font-bold mb-4 text-base text-gray-800">打刻履歴</div>
      <table class="w-full border-collapse">
        <tr>
          <th class="border border-gray-300 p-2 text-left bg-gray-100 font-bold">時刻</th>
          <th class="border border-gray-300 p-2 text-left bg-gray-100 font-bold">種類</th>
        </tr>
        <tr v-for="record in records" :key="record.id">
          <td class="border border-gray-300 p-2">{{ record.time_display }}</td>
          <td class="border border-gray-300 p-2">{{ record.record_type_display }}</td>
        </tr>
        <tr v-if="records.length === 0">
          <td colspan="2" class="border border-gray-300 p-4 text-center text-gray-500">
            打刻記録がありません
          </td>
        </tr>
      </table>
    </div>

    <!-- ナビゲーション -->
    <div class="bg-white border border-gray-300 rounded-lg p-6 mb-5">
      <div class="font-bold mb-4 text-base text-gray-800">勤怠履歴</div>
      <div class="flex gap-4">
        <a href="/attendances/weekly" class="px-4 py-2 border border-gray-300 rounded hover:bg-gray-50 text-center">
          📅 週間勤怠一覧
        </a>
        <a href="/attendances" class="px-4 py-2 border border-gray-300 rounded hover:bg-gray-50 text-center">
          📊 月別勤怠一覧
        </a>
      </div>
    </div>

    <!-- 今週の予測 -->
    <div class="bg-white border border-gray-300 rounded-lg p-6">
      <div class="font-bold mb-4 text-base text-gray-800">今週の労働時間</div>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
        <div class="border border-gray-200 p-4 rounded">
          <div class="text-sm text-gray-600 mb-1">実績</div>
          <div class="text-2xl font-bold">{{ safeActualHours.toFixed(1) }}h</div>
        </div>
        <div class="border border-gray-200 p-4 rounded">
          <div class="text-sm text-gray-600 mb-1">残り予定</div>
          <div class="text-2xl font-bold">{{ safeRemainingHours.toFixed(1) }}h</div>
        </div>
        <div class="border border-gray-200 p-4 rounded">
          <div class="text-sm text-gray-600 mb-1">予測合計</div>
          <div class="text-2xl font-bold" :class="{ 'text-red-600': weekSummary.over_limit }">
            {{ safePredictedHours.toFixed(1) }}h / {{ weekSummary.week_limit }}h
          </div>
        </div>
      </div>
      <div v-if="weekSummary.over_limit" class="p-3 bg-red-50 border border-red-200 text-red-800 rounded">
        ⚠️ 今週の労働時間が制限（20時間）を超過する予測です
      </div>
      <div v-else class="p-3 bg-green-50 border border-green-200 text-green-800 rounded">
        ✓ 今週の労働時間は制限内です
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'

const props = defineProps({
  date: String,
})

const isLoading = ref(true)
const records = ref([])
const summary = ref({
  clock_in_time: null,
  clock_out_time: null,
  work_hours: 0,
  break_minutes: 0,
  is_working: false,
})

const weekSummary = ref({
  actual_hours: 0.0,
  remaining_scheduled_hours: 0.0,
  predicted_total_hours: 0.0,
  week_limit: 20,
  over_limit: false,
})

const dateDisplay = computed(() => {
  if (!props.date) return ''
  const date = new Date(props.date)
  return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日`
})

// 週間サマリーの安全な数値変換
const safeActualHours = computed(() => {
  return Number(weekSummary.value.actual_hours) || 0
})

const safeRemainingHours = computed(() => {
  return Number(weekSummary.value.remaining_scheduled_hours) || 0
})

const safePredictedHours = computed(() => {
  return Number(weekSummary.value.predicted_total_hours) || 0
})

// 打刻ボタンの有効/無効制御
const hasClockIn = computed(() => records.value.some((r) => r.record_type === 'clock_in'))
const hasClockOut = computed(() => records.value.some((r) => r.record_type === 'clock_out'))
const isOnBreak = computed(() => {
  const breakStarts = records.value.filter((r) => r.record_type === 'break_start')
  const breakEnds = records.value.filter((r) => r.record_type === 'break_end')
  return breakStarts.length > breakEnds.length
})

const isClockInDisabled = computed(() => isLoading.value || hasClockIn.value)
const isBreakStartDisabled = computed(
  () => isLoading.value || !hasClockIn.value || hasClockOut.value || isOnBreak.value
)
const isBreakEndDisabled = computed(() => isLoading.value || !isOnBreak.value)
const isClockOutDisabled = computed(
  () => isLoading.value || !hasClockIn.value || hasClockOut.value || isOnBreak.value
)

const formatMinutes = (minutes) => {
  if (!minutes) return '0分'
  const hours = Math.floor(minutes / 60)
  const mins = minutes % 60
  if (hours > 0) {
    return `${hours}時間${mins}分`
  }
  return `${mins}分`
}

const fetchTodayData = async () => {
  try {
    isLoading.value = true
    const response = await fetch('/time_records/today', {
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
      },
    })

    const data = await response.json()
    records.value = data.records
    summary.value = data.summary

    // 週間サマリーの取得
    const weekResponse = await fetch('/attendances/today.json', {
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
      },
    })

    const weekData = await weekResponse.json()
    if (weekData.week_summary) {
      weekSummary.value = {
        actual_hours: weekData.week_summary.actual_hours || 0.0,
        remaining_scheduled_hours: weekData.week_summary.remaining_scheduled_hours || 0.0,
        predicted_total_hours: weekData.week_summary.predicted_total_hours || 0.0,
        week_limit: weekData.week_summary.week_limit || 20,
        over_limit: weekData.week_summary.over_limit || false,
      }
    }
  } catch (error) {
    console.error('Failed to fetch today data:', error)
    alert('データの取得に失敗しました')
  } finally {
    isLoading.value = false
  }
}

const clockIn = async () => {
  try {
    const response = await fetch('/time_records/clock_in', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
      },
    })

    const result = await response.json()
    if (result.success) {
      await fetchTodayData()
    } else {
      alert(`エラー: ${result.errors.join(', ')}`)
    }
  } catch (error) {
    console.error('Clock in failed:', error)
    alert('出勤打刻に失敗しました')
  }
}

const clockOut = async () => {
  try {
    const response = await fetch('/time_records/clock_out', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
      },
    })

    const result = await response.json()
    if (result.success) {
      await fetchTodayData()
      alert('退勤しました。お疲れ様でした！')
    } else {
      alert(`エラー: ${result.errors.join(', ')}`)
    }
  } catch (error) {
    console.error('Clock out failed:', error)
    alert('退勤打刻に失敗しました')
  }
}

const breakStart = async () => {
  try {
    const response = await fetch('/time_records/break_start', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
      },
    })

    const result = await response.json()
    if (result.success) {
      await fetchTodayData()
    } else {
      alert(`エラー: ${result.errors.join(', ')}`)
    }
  } catch (error) {
    console.error('Break start failed:', error)
    alert('休憩開始打刻に失敗しました')
  }
}

const breakEnd = async () => {
  try {
    const response = await fetch('/time_records/break_end', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
      },
    })

    const result = await response.json()
    if (result.success) {
      await fetchTodayData()
    } else {
      alert(`エラー: ${result.errors.join(', ')}`)
    }
  } catch (error) {
    console.error('Break end failed:', error)
    alert('休憩終了打刻に失敗しました')
  }
}

onMounted(() => {
  fetchTodayData()
})
</script>

<style scoped>
</style>
