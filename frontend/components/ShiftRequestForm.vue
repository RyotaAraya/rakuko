<template>
  <div>
    <h2 class="text-xl font-bold mb-4">シフト希望提出 {{ monthYear }}</h2>

    <!-- 注意事項 -->
    <div class="bg-gray-50 border border-gray-300 rounded-lg p-4 mb-5">
      <div class="font-bold mb-2 text-base text-gray-800">⚠️ 労働時間制限について</div>
      <div class="bg-yellow-50 border border-yellow-200 rounded p-2.5 text-yellow-800 text-sm leading-relaxed">
        ・週の合計時間（弊社+掛け持ち）が40時間を超えないよう入力してください<br>
        ・弊社での労働時間は週20時間以内に制限されています<br>
        ・日次で弊社と掛け持ちの時間を個別に入力してください<br>
        ・月跨ぎの週は自動的に判定され、該当月の提出対象となります
      </div>
    </div>

    <!-- 月間シフト入力 -->
    <div class="bg-gray-50 border border-gray-300 rounded-lg p-4 mb-5">
      <div class="font-bold mb-2 text-base text-gray-800">{{ monthYear }} 月間シフト希望</div>
      <div class="mb-4">
        <button type="button" class="bg-blue-600 text-white px-4 py-2 rounded mr-2 text-sm hover:bg-blue-700 disabled:opacity-60 disabled:cursor-not-allowed" @click="submitShifts" :disabled="!canSubmit || !canEdit">提出</button>
        <button type="button" class="bg-gray-600 text-white px-4 py-2 rounded mr-2 text-sm hover:bg-gray-700 disabled:opacity-60 disabled:cursor-not-allowed" @click="saveShifts" :disabled="!canEdit">下書き保存</button>
        <button type="button" class="bg-gray-600 text-white px-4 py-2 rounded mr-2 text-sm hover:bg-gray-700 disabled:opacity-60 disabled:cursor-not-allowed" @click="clearAll" :disabled="!canEdit">クリア</button>
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
        :canEdit="canEdit"
        @update-shift="updateWeekShift(week.id, $event)"
      />
    </div>

    <!-- 労働時間制限チェック結果 -->
    <div class="bg-gray-50 border border-gray-300 rounded-lg p-4 mb-5">
      <div class="font-bold mb-2 text-base text-gray-800">労働時間制限チェック結果（{{ monthYear }}）</div>
      <table class="w-full border-collapse mt-2.5">
        <tr>
          <th class="border border-gray-300 p-2 text-center text-sm bg-gray-100 font-bold">週</th>
          <th class="border border-gray-300 p-2 text-center text-sm bg-gray-100 font-bold">弊社時間</th>
          <th class="border border-gray-300 p-2 text-center text-sm bg-gray-100 font-bold">掛け持ち時間</th>
          <th class="border border-gray-300 p-2 text-center text-sm bg-gray-100 font-bold">合計時間</th>
          <th class="border border-gray-300 p-2 text-center text-sm bg-gray-100 font-bold">弊社制限</th>
          <th class="border border-gray-300 p-2 text-center text-sm bg-gray-100 font-bold">総労働制限</th>
          <th class="border border-gray-300 p-2 text-center text-sm bg-gray-100 font-bold">追加可能時間</th>
        </tr>
        <tr v-for="week in weeks" :key="`summary-${week.id}`" :class="{ 'bg-red-100': week.hasViolations }">
          <td class="border border-gray-300 p-2 text-center text-sm">{{ week.title }}</td>
          <td class="border border-gray-300 p-2 text-center text-sm">{{ week.companyHours }}h</td>
          <td class="border border-gray-300 p-2 text-center text-sm">{{ week.sidejobHours }}h</td>
          <td class="border border-gray-300 p-2 text-center text-sm">{{ week.totalHours }}h</td>
          <td class="border border-gray-300 p-2 text-center text-sm">{{ week.companyHours <= 20 ? '✓ 制限内' : '⚠️ 超過' }}</td>
          <td class="border border-gray-300 p-2 text-center text-sm">{{ week.totalHours <= 40 ? '✓ 制限内' : '⚠️ 超過' }}</td>
          <td class="border border-gray-300 p-2 text-center text-sm">
            <span v-if="!week.hasViolations" class="text-green-700 text-sm">
              弊社: +{{ (20 - week.companyHours).toFixed(1) }}h<br>
              合計: +{{ (40 - week.totalHours).toFixed(1) }}h
            </span>
            <span v-else class="exceeded-hours">-</span>
          </td>
        </tr>
      </table>

      <div class="bg-green-100 border border-green-300 rounded p-2.5 text-green-800 mt-2.5" v-if="allWeeksValid">
        ✅ 全ての週で制限内です（労働基準法遵守）
      </div>
      <div class="bg-red-100 border border-red-300 rounded p-2.5 text-red-800 mt-2.5" v-else>
        ⚠️ 制限を超過している週があります
      </div>
    </div>

    <!-- 提出ボタン -->
    <div class="bg-gray-50 border border-gray-300 rounded-lg p-4 mb-5">
      <button type="submit" class="bg-blue-600 text-white px-4 py-2 rounded mr-2 text-sm hover:bg-blue-700 disabled:opacity-60 disabled:cursor-not-allowed" @click="submitForm" :disabled="!canSubmit">提出</button>
      <button type="button" class="bg-gray-600 text-white px-4 py-2 rounded mr-2 text-sm hover:bg-gray-700" @click="saveDraft">下書き保存</button>
      <button type="button" class="bg-gray-600 text-white px-4 py-2 rounded mr-2 text-sm hover:bg-gray-700 disabled:opacity-60 disabled:cursor-not-allowed" @click="clearAll" :disabled="!canEdit">クリア</button>
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
    canEdit: {
      type: Boolean,
      default: true,
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
        weeks.value = props.weeksData.map((week) => ({
          ...week,
          // バックエンドからのデータ構造を正規化
          companyHours: 0,
          sidejobHours: 0,
          totalHours: 0,
          hasViolations: false,
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
        if (week.days && week.shifts) {
          week.days.forEach((day) => {
            if (!day.inTargetMonth) return

            // 弊社時間
            const companyStart = week.shifts?.company?.start?.[day.key]
            const companyEnd = week.shifts?.company?.end?.[day.key]
            companyHours += calculateWorkingHours(companyStart, companyEnd)

            // 掛け持ち時間
            const sidejobStart = week.shifts?.sidejob?.start?.[day.key]
            const sidejobEnd = week.shifts?.sidejob?.end?.[day.key]
            sidejobHours += calculateWorkingHours(sidejobStart, sidejobEnd)
          })
        }

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
    const updateWeekShift = (weekId, eventData) => {
      const weekIndex = weeks.value.findIndex((w) => w.id === weekId)
      if (weekIndex !== -1 && weeks.value[weekIndex].shifts) {
        const { type, timeType, day, roundedValue } = eventData
        weeks.value[weekIndex].shifts[type][timeType][day] = roundedValue
      }
    }

    const bulkInput = () => {
      const companyStart = prompt('弊社開始時間を入力してください', '09:00')
      const companyEnd = prompt('弊社終了時間を入力してください', '18:00')

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

    // ステータス表示を更新する関数
    const updateSubmissionStatus = (status, submittedAt) => {
      const statusElement = document.getElementById('submission-status')
      if (!statusElement) return

      if (status === 'submitted') {
        statusElement.innerHTML = `
          <span style="color: #2196f3; font-size: 14px; margin-left: 15px; font-weight: bold;">✅ 提出済み</span>
          ${submittedAt ? `<span style="color: #666; font-size: 12px; margin-left: 5px;">(${submittedAt}提出)</span>` : ''}
        `
      } else {
        statusElement.innerHTML = `
          <span style="color: #ff9800; font-size: 14px; margin-left: 15px;">📝 下書き中</span>
        `
      }
    }

    const saveShifts = async () => {
      try {
        console.log('下書き保存中...', computedWeeks.value)

        const formData = buildFormData('draft')
        const response = await fetch('/shift_requests', {
          method: 'POST',
          headers: {
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          },
          body: formData,
        })

        const result = await response.json()
        if (result.success) {
          // ステータス表示を更新
          if (result.status) {
            updateSubmissionStatus(result.status, result.submitted_at)
          }
          alert('下書きを保存しました')
        } else {
          console.error('保存エラー:', result.errors)
          alert(`保存に失敗しました: ${(result.errors || []).join(', ')}`)
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
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          },
          body: formData,
        })

        const result = await response.json()
        if (result.success) {
          // ステータス表示を更新
          if (result.status) {
            updateSubmissionStatus(result.status, result.submitted_at)
          }
          alert('シフトを提出しました')
          // 提出後はホームにリダイレクト
          window.location.href = '/'
        } else {
          console.error('提出エラー:', result.errors)
          alert(`提出に失敗しました: ${(result.errors || []).join(', ')}`)
        }
      } catch (error) {
        console.error('Submit failed:', error)
        alert('提出に失敗しました')
      }
    }

    // フォームデータを構築する関数
    const buildFormData = (submitType) => {
      const formData = new FormData()
      formData.append(
        'authenticity_token',
        document.querySelector('meta[name="csrf-token"]').content
      )
      formData.append('submit_type', submitType)
      formData.append('year', props.targetYear.toString())
      formData.append('month', props.targetMonth.toString())

      // 週データを送信形式に変換
      const weeksData = weeks.value.map((week) => ({
        id: week.id,
        days: week.days.map((day) => ({
          key: day.key,
          date: day.date,
        })),
        shifts: week.shifts,
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
        if (props.initialData.monthlySum?.user_weekly_shifts_for_month) {
          console.log('既存のシフトデータを復元します')
          // 既存シフトデータの復元処理は既にbuild_week_shifts_dataで行われているため、
          // 追加の処理は不要
        }
      }

      console.log('Vue.jsコンポーネントの初期化完了:', {
        targetYear: props.targetYear,
        targetMonth: props.targetMonth,
        weeksCount: weeks.value.length,
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
</style>