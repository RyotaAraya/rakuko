<template>
  <div>
    <h2>シフト希望提出 {{ monthYear }}</h2>

    <!-- 注意事項 -->
    <div class="section">
      <div class="section-title">⚠️ 労働時間制限について</div>
      <div class="warning">
        ・週の合計時間（弊社+掛け持ち）が40時間を超えないよう入力してください<br>
        ・弊社での労働時間は週20時間以内に制限されています<br>
        ・日次で自社と掛け持ちの時間を個別に入力してください<br>
        ・月跨ぎの週は自動的に判定され、該当月の提出対象となります
      </div>
    </div>

    <!-- 月間シフト入力 -->
    <div class="section">
      <div class="section-title">{{ monthYear }} 月間シフト希望</div>
      <div style="margin-bottom: 15px;">
        <button type="button" class="btn" @click="bulkInput">一括入力</button>
        <button type="button" class="btn" @click="clearAll">クリア</button>
        <button type="button" class="btn" @click="saveShifts">下書き保存</button>
        <button type="button" class="btn btn-primary" @click="submitShifts" :disabled="!canSubmit">提出</button>
      </div>

      <!-- 各週のシフト入力 -->
      <WeekShiftInput
        v-for="week in weeks"
        :key="week.id"
        :weekTitle="week.title"
        :weekDays="week.days"
        :shifts="week.shifts"
        :isCrossMonth="week.isCrossMonth"
        :daysInMonth="week.daysInMonth"
        @update-shift="updateWeekShift(week.id, $event)"
      />
    </div>

    <!-- 労働時間制限チェック結果 -->
    <div class="section">
      <div class="section-title">労働時間制限チェック結果（{{ monthYear }}）</div>
      <table>
        <tr>
          <th>週</th>
          <th>弊社時間</th>
          <th>掛け持ち時間</th>
          <th>合計時間</th>
          <th>弊社制限</th>
          <th>総労働制限</th>
        </tr>
        <tr v-for="week in weeks" :key="`summary-${week.id}`" :class="{ 'violation-row': week.hasViolations }">
          <td>{{ week.title }}</td>
          <td>{{ week.companyHours }}h</td>
          <td>{{ week.sidejobHours }}h</td>
          <td>{{ week.totalHours }}h</td>
          <td>{{ week.companyHours <= 20 ? '✓ 制限内' : '⚠️ 超過' }}</td>
          <td>{{ week.totalHours <= 40 ? '✓ 制限内' : '⚠️ 超過' }}</td>
        </tr>
      </table>

      <div class="success" v-if="allWeeksValid">
        ✅ 全ての週で制限内です（労働基準法遵守）
      </div>
      <div class="error" v-else>
        ⚠️ 制限を超過している週があります
      </div>
    </div>

    <!-- 提出ボタン -->
    <div class="section">
      <button type="submit" class="btn btn-primary" @click="submitForm" :disabled="!canSubmit">最終提出</button>
      <button type="button" class="btn" @click="saveDraft">下書き保存</button>
    </div>
  </div>
</template>

<script>
import { computed, onMounted, ref } from 'vue'
import WeekShiftInput from './WeekShiftInput.vue'

export default {
  components: {
    WeekShiftInput,
  },
  props: {
    targetYear: {
      type: Number,
      default: () => new Date().getFullYear(),
    },
    targetMonth: {
      type: Number,
      default: () => new Date().getMonth() + 1,
    },
    weeksData: {
      type: Array,
      default: () => [],
    },
    initialData: {
      type: Object,
      default: () => null,
    },
  },
  setup(props) {
    // リアクティブデータ
    const weeks = ref([])
    const monthYear = computed(() => `${props.targetYear}年${props.targetMonth}月`)

    // 週データの初期化
    const initializeWeeks = () => {
      // Railsサーバーから渡されたweeksDataを使用
      if (props.weeksData && props.weeksData.length > 0) {
        weeks.value = props.weeksData.map(week => ({
          ...week,
          // バックエンドからのデータ構造を正規化
          companyHours: 0,
          sidejobHours: 0,
          totalHours: 0,
          hasViolations: false
        }))
        console.log('週データをバックエンドから取得しました:', weeks.value.length, '週')
      } else {
        console.warn('週データが提供されていません。空の配列で初期化します。')
        weeks.value = []
      }
    }

    // 労働時間計算
    const calculateWorkingHours = (startTime, endTime) => {
      if (!startTime || !endTime) return 0

      const [startHour, startMin] = startTime.split(':').map(Number)
      const [endHour, endMin] = endTime.split(':').map(Number)

      const startMinutes = startHour * 60 + startMin
      const endMinutes = endHour * 60 + endMin

      let workingMinutes = endMinutes - startMinutes
      if (workingMinutes < 0) workingMinutes += 24 * 60 // 日跨ぎ対応

      const workingHours = workingMinutes / 60

      // 6時間以上は1時間休憩
      return workingHours >= 6 ? workingHours - 1 : workingHours
    }

    // 週ごとの計算されたプロパティ
    const computedWeeks = computed(() => {
      return weeks.value.map((week) => {
        let companyHours = 0
        let sidejobHours = 0

        // 対象月の日のみを計算対象とする
        week.days.forEach((day) => {
          if (!day.inTargetMonth) return

          // 弊社時間
          const companyStart = week.shifts.company.start[day.key]
          const companyEnd = week.shifts.company.end[day.key]
          companyHours += calculateWorkingHours(companyStart, companyEnd)

          // 掛け持ち時間
          const sidejobStart = week.shifts.sidejob.start[day.key]
          const sidejobEnd = week.shifts.sidejob.end[day.key]
          sidejobHours += calculateWorkingHours(sidejobStart, sidejobEnd)
        })

        const totalHours = companyHours + sidejobHours
        const hasViolations = companyHours > 20 || totalHours > 40

        return {
          ...week,
          companyHours: Math.round(companyHours * 100) / 100,
          sidejobHours: Math.round(sidejobHours * 100) / 100,
          totalHours: Math.round(totalHours * 100) / 100,
          hasViolations,
        }
      })
    })

    // 全体の制限チェック
    const allWeeksValid = computed(() => {
      return computedWeeks.value.every((week) => !week.hasViolations)
    })

    const canSubmit = computed(() => {
      return (
        allWeeksValid.value &&
        computedWeeks.value.some((week) => week.companyHours > 0 || week.sidejobHours > 0)
      )
    })

    // イベントハンドラー
    const updateWeekShift = (weekId, shiftData) => {
      const weekIndex = weeks.value.findIndex((w) => w.id === weekId)
      if (weekIndex !== -1) {
        weeks.value[weekIndex].shifts = { ...shiftData }
      }
    }

    const bulkInput = () => {
      const companyStart = prompt('弊社開始時間を入力してください (例: 09:00)')
      const companyEnd = prompt('弊社終了時間を入力してください (例: 16:00)')

      if (companyStart && companyEnd) {
        weeks.value.forEach((week) => {
          ;['mon', 'tue', 'wed', 'thu', 'fri'].forEach((day) => {
            week.shifts.company.start[day] = companyStart
            week.shifts.company.end[day] = companyEnd
          })
        })
      }
    }

    const clearAll = () => {
      if (confirm('全てのシフト入力をクリアしますか？')) {
        weeks.value.forEach((week) => {
          Object.keys(week.shifts.company.start).forEach((day) => {
            week.shifts.company.start[day] = ''
            week.shifts.company.end[day] = ''
            week.shifts.sidejob.start[day] = ''
            week.shifts.sidejob.end[day] = ''
          })
        })
      }
    }

    const saveShifts = async () => {
      try {
        console.log('下書き保存中...', computedWeeks.value)

        const formData = buildFormData('draft')
        const response = await fetch('/shift_requests', {
          method: 'POST',
          headers: {
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
          },
          body: formData
        })

        const result = await response.json()
        if (result.success) {
          alert('下書きを保存しました')
        } else {
          console.error('保存エラー:', result.errors)
          alert('保存に失敗しました: ' + (result.errors || []).join(', '))
        }
      } catch (error) {
        console.error('Save failed:', error)
        alert('保存に失敗しました')
      }
    }

    const submitShifts = async () => {
      if (!canSubmit.value) {
        alert('制限違反があるため提出できません')
        return
      }

      try {
        console.log('シフト提出中...', computedWeeks.value)

        const formData = buildFormData('submit')
        const response = await fetch('/shift_requests', {
          method: 'POST',
          headers: {
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
          },
          body: formData
        })

        const result = await response.json()
        if (result.success) {
          alert('シフトを提出しました')
          // 提出後はリダイレクトなどを行う
          window.location.href = '/shift_requests'
        } else {
          console.error('提出エラー:', result.errors)
          alert('提出に失敗しました: ' + (result.errors || []).join(', '))
        }
      } catch (error) {
        console.error('Submit failed:', error)
        alert('提出に失敗しました')
      }
    }

    // フォームデータを構築する関数
    const buildFormData = (submitType) => {
      const formData = new FormData()
      formData.append('authenticity_token', document.querySelector('meta[name="csrf-token"]').content)
      formData.append('submit_type', submitType)
      formData.append('year', props.targetYear.toString())
      formData.append('month', props.targetMonth.toString())

      // 週データを送信形式に変換
      const weeksData = weeks.value.map(week => ({
        id: week.id,
        days: week.days.map(day => ({
          key: day.key,
          date: day.date
        })),
        shifts: week.shifts
      }))

      formData.append('weeks_data', JSON.stringify(weeksData))
      return formData
    }

    const submitForm = submitShifts
    const saveDraft = saveShifts

    // ライフサイクル
    onMounted(() => {
      initializeWeeks()

      // 初期データがある場合は設定
      if (props.initialData) {
        console.log('初期データが提供されました:', props.initialData)
        // バックエンドからの初期データを処理
        if (props.initialData.monthlySum && props.initialData.monthlySum.user_weekly_shifts_for_month) {
          console.log('既存のシフトデータを復元します')
          // 既存シフトデータの復元処理は既にbuild_week_shifts_dataで行われているため、
          // 追加の処理は不要
        }
      }

      console.log('Vue.jsコンポーネントの初期化完了:', {
        targetYear: props.targetYear,
        targetMonth: props.targetMonth,
        weeksCount: weeks.value.length
      })
    })

    // setup()で作成したリアクティブデータや関数を返す
    return {
      weeks: computedWeeks,
      monthYear,
      allWeeksValid,
      canSubmit,
      updateWeekShift,
      bulkInput,
      clearAll,
      saveShifts,
      submitShifts,
      submitForm,
      saveDraft,
    }
  },
}
</script>

<style scoped>
.section {
  background-color: #f9f9f9;
  border: 1px solid #ddd;
  border-radius: 8px;
  padding: 15px;
  margin-bottom: 20px;
}

.section-title {
  font-weight: bold;
  margin-bottom: 10px;
  font-size: 16px;
  color: #333;
}

.warning {
  background-color: #fff3cd;
  border: 1px solid #ffeaa7;
  border-radius: 4px;
  padding: 10px;
  color: #856404;
  font-size: 14px;
  line-height: 1.5;
}

.success {
  background-color: #d4edda;
  border: 1px solid #c3e6cb;
  border-radius: 4px;
  padding: 10px;
  color: #155724;
  margin-top: 10px;
}

.error {
  background-color: #f8d7da;
  border: 1px solid #f5c6cb;
  border-radius: 4px;
  padding: 10px;
  color: #721c24;
  margin-top: 10px;
}

.btn {
  background-color: #6c757d;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 4px;
  cursor: pointer;
  margin-right: 10px;
  font-size: 14px;
}

.btn:hover {
  background-color: #5a6268;
}

.btn:disabled {
  background-color: #6c757d;
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-primary {
  background-color: #007bff;
}

.btn-primary:hover {
  background-color: #0056b3;
}

table {
  width: 100%;
  border-collapse: collapse;
  margin-top: 10px;
}

th, td {
  border: 1px solid #ddd;
  padding: 8px;
  text-align: center;
  font-size: 14px;
}

th {
  background-color: #f8f9fa;
  font-weight: bold;
}

.violation-row {
  background-color: #f8d7da;
}
</style>