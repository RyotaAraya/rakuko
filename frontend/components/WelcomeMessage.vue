<script setup lang="ts">
import { ref } from 'vue'

const currentTime = ref<string>(new Date().toLocaleString('ja-JP'))

// 現在時刻を更新する関数
setInterval(() => {
  currentTime.value = new Date().toLocaleString('ja-JP')
}, 1000)
</script>

<template>
  <div class="w-full">
    <!-- タイトルセクション -->
    <div class="text-center mb-8">
      <h1 class="text-2xl font-bold text-gray-800 mb-2">ラクコ</h1>
      <p class="text-sm text-gray-600">学生アルバイト専用勤怠管理システム</p>
    </div>

    <!-- 現在時刻セクション -->
    <div class="border border-gray-300 p-5 mb-8 bg-white">
      <div class="font-bold text-base text-center">
        現在時刻: {{ currentTime }}
      </div>
    </div>

    <!-- メニューグリッド -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-8">
      <div class="border border-gray-300 p-5 bg-white cursor-pointer hover:bg-gray-50 transition-colors">
        <div class="font-bold mb-1">シフト希望提出</div>
        <div class="text-xs text-gray-600">月間予定を入力</div>
      </div>
      <div class="border border-gray-300 p-5 bg-white cursor-pointer hover:bg-gray-50 transition-colors">
        <div class="font-bold mb-1">勤怠登録</div>
        <div class="text-xs text-gray-600">出退勤を記録</div>
      </div>
      <div class="border border-gray-300 p-5 bg-white cursor-pointer hover:bg-gray-50 transition-colors">
        <div class="font-bold mb-1">各種申請</div>
        <div class="text-xs text-gray-600">欠勤・遅刻・早退</div>
      </div>
      <div class="border border-gray-300 p-5 bg-white cursor-pointer hover:bg-gray-50 transition-colors">
        <div class="font-bold mb-1">交通費申請</div>
        <div class="text-xs text-gray-600">月次申請</div>
      </div>
    </div>

    <!-- システム説明セクション -->
    <div class="border border-gray-300 p-5 bg-white">
      <div class="font-bold mb-4">システムについて</div>
      <div class="text-sm text-gray-600 leading-relaxed">
        ラクコは学生アルバイトの勤怠管理を簡単にするシステムです。<br>
        シフト提出から勤怠記録まで、すべての管理をスムーズに行えます。
      </div>
    </div>
  </div>
</template>