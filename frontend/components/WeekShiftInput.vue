<template>
  <div class="week-section">
    <div class="week-header">{{ weekTitle }}</div>
    <div class="week-content">
      <table>
        <tr>
          <th>日付</th>
          <th v-for="day in weekDays" :key="day.key">{{ day.label }}</th>
        </tr>
        <tr>
          <td>🏢弊社開始</td>
          <td v-for="day in weekDays" :key="`company-start-${day.key}`">
            <input
              type="time"
              class="time-input"
              :value="shifts.company.start[day.key]"
              @input="updateShift('company', 'start', day.key, $event.target.value)"
            >
          </td>
        </tr>
        <tr>
          <td>🏢弊社終了</td>
          <td v-for="day in weekDays" :key="`company-end-${day.key}`">
            <input
              type="time"
              class="time-input"
              :value="shifts.company.end[day.key]"
              @input="updateShift('company', 'end', day.key, $event.target.value)"
            >
          </td>
        </tr>
        <tr>
          <td>📱掛け持ち開始</td>
          <td v-for="day in weekDays" :key="`sidejob-start-${day.key}`">
            <input
              type="time"
              class="time-input"
              :value="shifts.sidejob.start[day.key]"
              @input="updateShift('sidejob', 'start', day.key, $event.target.value)"
            >
          </td>
        </tr>
        <tr>
          <td>📱掛け持ち終了</td>
          <td v-for="day in weekDays" :key="`sidejob-end-${day.key}`">
            <input
              type="time"
              class="time-input"
              :value="shifts.sidejob.end[day.key]"
              @input="updateShift('sidejob', 'end', day.key, $event.target.value)"
            >
          </td>
        </tr>
      </table>
      <div class="summary-row">
        <div>弊社: {{ companyHours }}h | 掛け持ち: {{ sidejobHours }}h</div>
        <div>
          <strong>合計: {{ totalHours }}h/40h {{ totalHours <= 40 ? '✓' : '⚠️' }}</strong>
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

const updateShift = (type, timeType, day, value) => {
  emit('update-shift', { type, timeType, day, value })
}

// 時間計算のヘルパー関数
const calculateHours = (startTimes, endTimes) => {
  let totalMinutes = 0

  for (const day of props.weekDays) {
    const startTime = startTimes[day.key]
    const endTime = endTimes[day.key]

    if (startTime && endTime) {
      const start = new Date(`2000-01-01T${startTime}:00`)
      const end = new Date(`2000-01-01T${endTime}:00`)

      if (end > start) {
        totalMinutes += (end - start) / (1000 * 60)
      }
    }
  }

  return Math.round((totalMinutes / 60) * 10) / 10 // 小数第1位まで
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
</script>

<style scoped>
.week-section {
  border: 1px solid #ccc;
  margin-bottom: 15px;
}

.week-header {
  background: #f5f5f5;
  padding: 10px;
  font-weight: bold;
  border-bottom: 1px solid #ccc;
}

.week-content {
  padding: 15px;
}

.time-input {
  width: 80px;
  padding: 4px;
  border: 1px solid #ccc;
}

.summary-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px;
  background: #f9f9f9;
  border: 1px solid #ddd;
  margin-top: 10px;
}

table {
  width: 100%;
  border-collapse: collapse;
  margin-top: 15px;
}

th, td {
  border: 1px solid #ddd;
  padding: 8px;
  text-align: center;
}

th {
  background: #f5f5f5;
  font-weight: bold;
}
</style>