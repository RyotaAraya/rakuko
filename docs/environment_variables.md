# 環境変数管理シート

## 本番環境（Production）

| 変数名 | 値 | 説明 |
|--------|----|----|
| `RAILS_ENV` | `production` | Rails実行環境 |
| `SECRET_KEY_BASE` | `[Renderで自動生成]` | Rails暗号化キー |
| `DATABASE_URL` | `[RenderのPostgreSQL接続URL]` | データベース接続文字列 |
| `REDIS_URL` | `[RedisのURL]` | Redis接続文字列（今後） |
| `GOOGLE_CLIENT_ID` | `[設定待ち]` | Google OAuth クライアントID |
| `GOOGLE_CLIENT_SECRET` | `[設定待ち]` | Google OAuth クライアントシークレット |

## ステージング環境（Staging）

| 変数名 | 値 | 説明 |
|--------|----|----|
| `RAILS_ENV` | `staging` | Rails実行環境 |
| `SECRET_KEY_BASE` | `[Renderで自動生成]` | Rails暗号化キー |
| `DATABASE_URL` | `[RenderのSTG PostgreSQL接続URL]` | データベース接続文字列 |
| `REDIS_URL` | `[STG RedisのURL]` | Redis接続文字列（今後） |
| `GOOGLE_CLIENT_ID` | `[STG用設定待ち]` | Google OAuth クライアントID（STG用） |
| `GOOGLE_CLIENT_SECRET` | `[STG用設定待ち]` | Google OAuth クライアントシークレット（STG用） |

## 開発環境（Development）

| 変数名 | 値 | 説明 |
|--------|----|----|
| `RAILS_ENV` | `development` | Rails実行環境 |
| `DATABASE_URL` | `postgresql://postgres:password@db:5432/rakuko_development` | Docker PostgreSQL |
| `REDIS_URL` | `redis://redis:6379/0` | Docker Redis |

## SECRET_KEY_BASE生成方法

本番・STG環境では、Renderが自動生成しますが、手動で生成する場合：

```bash
bundle exec rails secret
```

## Google OAuth設定手順

1. [Google Cloud Console](https://console.cloud.google.com/) でプロジェクト作成
2. APIs & Services > Credentials で OAuth 2.0 クライアント作成
3. 承認済みのリダイレクト URI を設定：
   - 本番: `https://[your-app].onrender.com/users/auth/google_oauth2/callback`
   - STG: `https://[your-stg-app].onrender.com/users/auth/google_oauth2/callback`
   - 開発: `http://localhost:3000/users/auth/google_oauth2/callback`

## 注意事項

- 本番とSTGでは異なるGoogle OAuthクライアントを使用すること
- SECRET_KEY_BASEは絶対に公開しないこと
- 環境変数はRenderの Environment Variables で設定すること