// To see this message, add the following to the `<head>` section in your
// views/layouts/application.html.erb
//
//    <%= vite_client_tag %>
//    <%= vite_javascript_tag 'application' %>

import '../styles/application.css'
import { createApp } from 'vue'
import WelcomeMessage from '../components/WelcomeMessage.vue'

document.addEventListener('DOMContentLoaded', () => {
  const el = document.getElementById('vue-app')
  if (el) {
    createApp(WelcomeMessage).mount(el)
  }
})
