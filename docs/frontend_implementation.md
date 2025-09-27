# フロントエンド実装ドキュメント

## 概要
本プロジェクトはRails + Vue.js + Tailwind CSSで構築された学生アルバイト勤怠管理システム「ラクコ」のフロントエンド実装について説明します。

## 技術スタック

### フレームワーク・ライブラリ
- **Vue.js 3.5.22**: フロントエンドフレームワーク
- **Vite 5.4.20**: ビルドツール・開発サーバー
- **Tailwind CSS 3.4.17**: ユーティリティファーストCSSフレームワーク
- **TypeScript 5.9.2**: 型安全性を提供
- **Biome**: リンター・フォーマッター

### 開発ツール
- **PostCSS 8.5.6**: CSS後処理
- **Autoprefixer 10.4.21**: ブラウザプレフィックス自動付与
- **vite-plugin-ruby 5.1.1**: Rails + Vite統合

## プロジェクト構成

```
frontend/
├── components/           # Vue.jsコンポーネント
│   └── WelcomeMessage.vue
├── entrypoints/         # Viteエントリーポイント
│   └── application.ts
└── styles/              # スタイルシート
    └── application.css
```

## セットアップと設定

### Vite設定（vite.config.ts）
```typescript
import { resolve } from 'node:path'
import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

export default defineConfig({
  plugins: [RubyPlugin(), vue()],
  resolve: {
    alias: {
      '@': resolve(__dirname, 'frontend'),
    },
  },
})
```

### Tailwind CSS設定（tailwind.config.js）
```javascript
export default {
  content: ['./frontend/**/*.{vue,js,ts,jsx,tsx}', './app/views/**/*.html.erb'],
  theme: {
    extend: {},
  },
  plugins: [],
}
```

### PostCSS設定（postcss.config.js）
```javascript
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
```

## エントリーポイント設定

### application.ts
```typescript
import '../styles/application.css'
import { createApp } from 'vue'
import WelcomeMessage from '../components/WelcomeMessage.vue'

document.addEventListener('DOMContentLoaded', () => {
  const el = document.getElementById('vue-app')
  if (el) {
    createApp(WelcomeMessage).mount(el)
  }
})
```

### application.css
```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

## Rails側の設定

### レイアウトファイル（app/views/layouts/application.html.erb）
```erb
<%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
<%= javascript_importmap_tags %>
<%= vite_client_tag %>
<%= vite_typescript_tag 'application' %>

<!-- クリティカルCSS（FOUC対策） -->
<style>
  /* Critical CSS to prevent FOUC */
  /* Tailwindクラスのインライン定義 */
</style>
```

### ビュー（app/views/home/index.html.erb）
```erb
<header class="border-b border-gray-300 py-4 bg-white">
  <div class="max-w-screen-xl mx-auto flex justify-between items-center px-5">
    <h1><%= link_to "ラクコ", root_path, class: "text-lg font-bold no-underline text-inherit" %></h1>
  </div>
</header>

<main class="max-w-screen-xl mx-auto py-8 px-5">
  <div id="vue-app"></div>
</main>
```

## コンポーネント実装

### WelcomeMessage.vue
デザインシステムに準拠したメインコンポーネント：

```vue
<template>
  <div class="w-full">
    <div class="text-center mb-8">
      <h1 class="text-2xl font-bold text-gray-800 mb-2">ラクコ</h1>
      <p class="text-sm text-gray-600">学生アルバイト専用勤怠管理システム</p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-8">
      <!-- 機能メニュー -->
    </div>
  </div>
</template>
```

## スタイリング指針

### Tailwind CSSクラス
- **レスポンシブ**: `grid-cols-1 md:grid-cols-2`
- **スペーシング**: `mb-8`, `gap-4`, `px-5`, `py-4`
- **カラー**: `text-gray-800`, `bg-white`, `border-gray-300`
- **タイポグラフィ**: `text-2xl`, `font-bold`, `text-sm`

### クリティカルCSS（FOUC対策）
重要なTailwindクラスをインライン化してページ読み込み時のちらつきを防止：
```css
.w-full { width: 100%; }
.text-center { text-align: center; }
.mb-8 { margin-bottom: 2rem; }
/* その他必要なクラス */
```

## パフォーマンス最適化

### FOUC（Flash of Unstyled Content）対策
1. **クリティカルCSS**: 重要なスタイルをインライン化
2. **Vite統合**: CSSの効率的な読み込み
3. **CSS最適化**: PostCSS + Autoprefixerによる最適化

### 開発時パフォーマンス
- **HMR（Hot Module Replacement）**: 高速な開発サイクル
- **TypeScript**: 型チェックによるエラー早期発見
- **Biome**: 高速なリンティング・フォーマット

## 開発フロー

### 1. 開発サーバー起動
```bash
docker-compose up
```

### 2. ファイル監視
Viteが自動でファイル変更を検知し、HMRでブラウザを更新

### 3. リンティング・フォーマット
```bash
npm run lint      # リンティング
npm run lint:fix  # 自動修正
npm run format    # フォーマット
npm run typecheck # 型チェック
```

## トラブルシューティング

### よくある問題と解決法

#### 1. CSSが読み込まれない
- `frontend/entrypoints/application.ts`でCSSが正しくインポートされているか確認
- `vite_typescript_tag`がレイアウトに含まれているか確認

#### 2. Vue.jsコンポーネントが表示されない
- `document.getElementById('vue-app')`の要素が存在するか確認
- コンソールエラーをチェック

#### 3. Tailwind CSSクラスが効かない
- `tailwind.config.js`の`content`パスが正しいか確認
- PostCSS設定を確認

#### 4. 型エラー
- `npm run typecheck`で詳細なエラーを確認
- 必要な型定義をインストール

## 今後の拡張

### 機能追加時の手順
1. **コンポーネント作成**: `frontend/components/`に新しい`.vue`ファイル
2. **ルーティング**: 必要に応じてVue Routerを導入
3. **状態管理**: 複雑な状態はPiniaなどを検討
4. **API連携**: Axiosまたはfetchでバックエンドと通信

### 推奨ライブラリ
- **Vue Router**: SPA化する場合
- **Pinia**: 状態管理
- **VueUse**: Vueコンポーザブル
- **Headless UI**: アクセシブルなUIコンポーネント

## リファレンス

- [Vue.js 3 公式ドキュメント](https://vuejs.org/)
- [Tailwind CSS 公式ドキュメント](https://tailwindcss.com/)
- [Vite 公式ドキュメント](https://vitejs.dev/)
- [vite_ruby Gem](https://vite-ruby.netlify.app/)