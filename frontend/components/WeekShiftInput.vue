<template>
  <div class="border border-gray-300 mb-4">
    <div class="bg-gray-100 p-2.5 font-bold border-b border-gray-300">{{ weekTitle }}</div>
    <div class="p-4">
      <table class="w-full border-collapse mt-4">
        <tr>
          <th class="border border-gray-300 p-2 text-center bg-gray-100 font-bold">日付</th>
          <th v-for="day in weekDays" :key="day.key" class="border border-gray-300 p-2 text-center bg-gray-100 font-bold">{{ day.label }}</th>
        </tr>
        <tr>
          <td class="border border-gray-300 p-2 text-center">🏢弊社開始</td>
          <td v-for="day in weekDays" :key="`company-start-${day.key}`" class="border border-gray-300 p-2 text-center">
            <select
              class="w-20 p-1 border border-gray-300 text-sm"
              :class="{ 'bg-gray-100 cursor-not-allowed': isWeekend(day.key) || isOutOfTargetMonth(day.key) }"
              :value="shifts.company.start[day.key]"
              :disabled="isWeekend(day.key) || isOutOfTargetMonth(day.key)"
              @change="updateShift('company', 'start', day.key, $event.target.value)"
            >
              <option value="">--</option>
              <option v-for="time in timeOptionsCompany" :key="time" :value="time">{{ time }}</option>
            </select>
          </td>
        </tr>
        <tr>
          <td class="border border-gray-300 p-2 text-center">🏢弊社終了</td>
          <td v-for="day in weekDays" :key="`company-end-${day.key}`" class="border border-gray-300 p-2 text-center">
            <select
              class="w-20 p-1 border border-gray-300 text-sm"
              :class="{ 'bg-gray-100 cursor-not-allowed': isWeekend(day.key) || isOutOfTargetMonth(day.key) }"
              :value="shifts.company.end[day.key]"
              :disabled="isWeekend(day.key) || isOutOfTargetMonth(day.key)"
              @change="updateShift('company', 'end', day.key, $event.target.value)"
            >
              <option value="">--</option>
              <option v-for="time in timeOptionsCompany" :key="time" :value="time">{{ time }}</option>
            </select>
          </td>
        </tr>
        <tr>
          <td class="border border-gray-300 p-2 text-center">📱掛け持ち開始</td>
          <td v-for="day in weekDays" :key="`sidejob-start-${day.key}`" class="border border-gray-300 p-2 text-center">
            <select
              class="w-20 p-1 border border-gray-300 text-sm"
              :class="{ 'bg-gray-100 cursor-not-allowed': isOutOfTargetMonth(day.key) }"
              :value="shifts.sidejob.start[day.key]"
              :disabled="isOutOfTargetMonth(day.key)"
              @change="updateShift('sidejob', 'start', day.key, $event.target.value)"
            >
              <option value="">--</option>
              <option v-for="time in timeOptionsSidejob" :key="time" :value="time">{{ time }}</option>
            </select>
          </td>
        </tr>
        <tr>
          <td class="border border-gray-300 p-2 text-center">📱掛け持ち終了</td>
          <td v-for="day in weekDays" :key="`sidejob-end-${day.key}`" class="border border-gray-300 p-2 text-center">
            <select
              class="w-20 p-1 border border-gray-300 text-sm"
              :class="{ 'bg-gray-100 cursor-not-allowed': isOutOfTargetMonth(day.key) }"
              :value="shifts.sidejob.end[day.key]"
              :disabled="isOutOfTargetMonth(day.key)"
              @change="updateShift('sidejob', 'end', day.key, $event.target.value)"
            >
              <option value="">--</option>
              <option v-for="time in timeOptionsSidejob" :key="time" :value="time">{{ time }}</option>
            </select>
          </td>
        </tr>
      </table>
      <div class="flex justify-between items-center p-2.5 bg-gray-50 border border-gray-300 mt-2.5" :class="{ 'bg-red-50': hasViolations }">
        <div class="flex gap-2 items-center">
          <span>弊社: {{ companyHours }}h</span>
          <span class="text-sm text-gray-600" :class="{ 'text-red-600 font-bold': companyExceeded }">
            (制限: 20h) {{ companyExceeded ? '⚠️ 超過' : '✓' }}
          </span>
          <span class="text-gray-400">|</span>
          <span>掛け持ち: {{ sidejobHours }}h</span>
        </div>
        <div :class="{ 'text-red-600 font-bold': totalExceeded }">
          <strong>合計: {{ totalHours }}h / 40h {{ totalExceeded ? '⚠️ 超過' : '✓' }}</strong>
        </div>
      </div>
      <div v-if="hasViolations || hasTimeOverlap" class="mt-2.5 p-2.5 bg-red-50 border border-red-200">
        <div v-if="companyExceeded" class="text-red-700 my-1">
          ⚠️ 弊社勤務時間が週20時間制限を{{ (companyHours - 20).toFixed(1) }}時間超過しています
        </div>
        <div v-if="totalExceeded" class="text-red-700 my-1">
          ⚠️ 総勤務時間が週40時間制限を{{ (totalHours - 40).toFixed(1) }}時間超過しています
        </div>
        <div v-if="hasTimeOverlap" class="text-red-700 my-1">
          ⚠️ 弊社と掛け持ちの勤務時間が重複しています: {{ timeOverlapDays.join(', ') }}
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  weekTitle: String,
  weekDays: Array,
  shifts: Object,
})

const emit = defineEmits(['update-shift'])

// 弊社用: 15分刻みの時間オプション（09:00〜18:00）
const timeOptionsCompany = (() => {
  const options = []
  for (let hour = 9; hour < 18; hour++) {
    for (let minute = 0; minute < 60; minute += 15) {
      const h = String(hour).padStart(2, '0')
      const m = String(minute).padStart(2, '0')
      options.push(`${h}:${m}`)
    }
  }
  // 18:00を追加
  options.push('18:00')
  return options
})()

// 掛け持ち用: 15分刻みの時間オプション（00:00〜23:45）
const timeOptionsSidejob = (() => {
  const options = []
  for (let hour = 0; hour < 24; hour++) {
    for (let minute = 0; minute < 60; minute += 15) {
      const h = String(hour).padStart(2, '0')
      const m = String(minute).padStart(2, '0')
      options.push(`${h}:${m}`)
    }
  }
  return options
})()

// 土日判定
const isWeekend = (dayKey) => {
  return dayKey === 'sat' || dayKey === 'sun'
}

// 対象月外の日付判定
const isOutOfTargetMonth = (dayKey) => {
  const day = props.weekDays.find(d => d.key === dayKey)
  return day ? !day.inTargetMonth : true
}

const updateShift = (type, timeType, day, value) => {
  emit('update-shift', { type, timeType, day, roundedValue: value })
}

// 時間重複チェック
const checkTimeOverlap = (companyStart, companyEnd, sidejobStart, sidejobEnd) => {
  if (!companyStart || !companyEnd || !sidejobStart || !sidejobEnd) return false

  const cs = new Date(`2000-01-01T${companyStart}:00`)
  const ce = new Date(`2000-01-01T${companyEnd}:00`)
  const ss = new Date(`2000-01-01T${sidejobStart}:00`)
  const se = new Date(`2000-01-01T${sidejobEnd}:00`)

  // 時間が重複しているかチェック
  return cs < se && ce > ss
}

const timeOverlapDays = computed(() => {
  const overlaps = []

  for (const day of props.weekDays) {
    const companyStart = props.shifts.company.start[day.key]
    const companyEnd = props.shifts.company.end[day.key]
    const sidejobStart = props.shifts.sidejob.start[day.key]
    const sidejobEnd = props.shifts.sidejob.end[day.key]

    if (checkTimeOverlap(companyStart, companyEnd, sidejobStart, sidejobEnd)) {
      overlaps.push(day.label)
    }
  }

  return overlaps
})

const hasTimeOverlap = computed(() => {
  return timeOverlapDays.value.length > 0
})

// 時間計算のヘルパー関数（休憩時間を考慮）
const calculateHours = (startTimes, endTimes) => {
  let totalHours = 0

  for (const day of props.weekDays) {
    const startTime = startTimes[day.key]
    const endTime = endTimes[day.key]

    if (startTime && endTime) {
      const start = new Date(`2000-01-01T${startTime}:00`)
      const end = new Date(`2000-01-01T${endTime}:00`)

      if (end > start) {
        const workingMinutes = (end - start) / (1000 * 60)
        const workingHours = workingMinutes / 60

        // 6時間以上の場合は1時間の休憩を差し引く（仕様書2.1）
        const actualHours = workingHours >= 6 ? workingHours - 1 : workingHours
        totalHours += actualHours
      }
    }
  }

  return Math.round(totalHours * 10) / 10 // 小数第1位まで
}

const companyHours = computed(() => {
  return calculateHours(props.shifts.company.start, props.shifts.company.end)
})

const sidejobHours = computed(() => {
  return calculateHours(props.shifts.sidejob.start, props.shifts.sidejob.end)
})

const totalHours = computed(() => {
  return companyHours.value + sidejobHours.value
})

// 制限チェック
const companyExceeded = computed(() => {
  return companyHours.value > 20
})

const totalExceeded = computed(() => {
  return totalHours.value > 40
})

const hasViolations = computed(() => {
  return companyExceeded.value || totalExceeded.value
})
</script>

<style scoped>
</style>
