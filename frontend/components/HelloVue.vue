<script setup lang="ts">
import { ref } from 'vue'

const message = ref("こんにちは！Vue + Rails + Vite")
</script>

<template>
  <div>
    <h2>{{ message }}</h2>
    <button @click="message = 'クリックされました！'">クリック</button>
  </div>
</template>

<style>
h2 {
  color: blue;
}
</style>