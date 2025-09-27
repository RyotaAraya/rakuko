<script setup lang="ts">
import { ref } from 'vue'

const message = ref<string>("こんにちは！Vue + Rails + Vite + TypeScript")
const count = ref<number>(0)

const updateMessage = (): void => {
  count.value++
  message.value = `Vue.js + TypeScript動作中！クリック数: ${count.value}`
}
</script>

<template>
  <div>
    <h2>{{ message }}</h2>
    <p>カウント: {{ count }}</p>
    <button @click="updateMessage">TypeScript動作テスト</button>
  </div>
</template>

<style>
h2 {
  color: blue;
}
</style>