# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rakuko (らくこ) is a student part-time work attendance management system built with Rails 7.1 and Vue.js 3. It specifically addresses Japanese labor law requirements for student workers, including 20-hour weekly limits and multi-job tracking.

## Development Commands

### Rails Commands
- `bin/rails server` - Start Rails development server
- `bin/rails console` - Open Rails console
- `bin/rails db:migrate` - Run database migrations
- `bin/rails db:seed` - Seed database with initial data

### Frontend Commands
- `npm run lint` - Lint TypeScript/Vue files with Biome
- `npm run lint:fix` - Fix linting issues automatically
- `npm run format` - Format code with Biome
- `npm run typecheck` - Run TypeScript type checking
- `bin/vite dev` - Start Vite development server for frontend assets

### Development Environment
- `foreman start -f Procfile.dev` - Start both Rails and Vite servers simultaneously

### Testing
The project uses standard Rails testing conventions. Check for test files in `test/` or `spec/` directories for specific test commands.

## Architecture

### Technology Stack
- **Backend**: Ruby on Rails 7.1 with PostgreSQL
- **Frontend**: Vue.js 3 + TypeScript (partial integration via Vite Rails)
- **Authentication**: Devise with Google OAuth2 integration
- **Authorization**: Pundit (role-based access control)
- **State Management**: AASM (User: pending/active/inactive, Application: pending/approved/rejected/canceled, WeeklyShift: draft/submitted)
- **Background Jobs**: Sidekiq (planned)
- **Styling**: Tailwind CSS

### Code Organization

#### Rails Application Structure
- **Models**: Standard Rails models in `app/models/`
  - `User` model with Devise and OAuth integration
  - `Role` + `UserRole` - Single role constraint (each user has exactly one role)
  - `WeeklyShift` + `DailySchedule` - Week-based shift management
  - `Attendance` + `TimeRecord` - Time tracking and attendance records
  - `Application` + `Approval` - Application and approval workflow (polymorphic)
- **Controllers**:
  - `HomeController` for main application entry
  - `Users::OmniauthCallbacksController` for Google OAuth
  - `Admin::UsersController` for user management
  - `ShiftRequestsController` for shift submission
  - `AttendancesController` for attendance tracking
- **Views**: ERB templates in `app/views/` with Vue.js integration points

#### Frontend Structure
- **Entry Point**: `frontend/entrypoints/application.ts` - Main Vite entry
- **Components**: Vue SFC components in `frontend/components/`
- **Styles**: Global CSS in `frontend/styles/application.css`
- **Types**: TypeScript definitions in `frontend/types/`

#### Database Schema
**Week-based Design** (solves month-crossing week problems):
- `weeks` - Week master table (Monday to Sunday, cross-month flag)
- `weekly_shifts` - User's weekly shift data (AASM: draft/submitted)
- `daily_schedules` - Daily schedule details (company/side-job hours)
- `monthly_summaries` - Monthly summary aggregated from weekly_shifts

**User Management**:
- `users` - User accounts (contract_start_date uses created_at, contract_end_date column)
- `roles` - Role definitions (student, department_manager, system_admin)
- `user_roles` - Single role constraint via join table
- `departments` - Department management

**Attendance & Time Tracking**:
- `time_records` - Clock in/out records (work_start, work_end, break_start, break_end)
- `attendances` - Daily attendance summary (auto-generated from time_records)

**Applications & Approvals**:
- `applications` - Applications (absence, late, early_leave, shift_change)
- `approvals` - Polymorphic approval records (department approval only)

**Other**:
- `month_end_closings` - Monthly closing process
- `notifications` - User notifications

### Vue.js Integration Pattern
The application uses a hybrid approach:
- Rails handles routing, authentication, and server-side rendering
- Vue.js components are mounted to specific DOM elements (e.g., `#vue-app`)
- Vite Rails plugin manages asset compilation and hot reloading

### Authentication Flow
- Google Workspace OAuth2 integration via omniauth-google-oauth2
- Custom callback controller at `Users::OmniauthCallbacksController`
- User creation with automatic password generation for OAuth users

## Development Guidelines

### Code Style
- **Ruby**: Follow Rails conventions
- **TypeScript/Vue**: Biome configuration enforces consistent formatting
  - 2-space indentation
- **Linting**: Use `npm run lint` before committing frontend changes

### Database Changes
- Always create migrations for schema changes
- Update `db/schema.rb` should be committed after running migrations

### Frontend Development
- Vue components should be placed in `frontend/components/`
- Use TypeScript for type safety
- Follow Vue 3 Composition API patterns where possible

## Known Issues & Technical Debt

### ~~フェーズ2-1 ER図不整合~~ ✅ 解決済み (フェーズ2-3で対応完了)
- ✅ Roles, UserRolesテーブル作成済み (ER図準拠)
- ✅ 権限管理システムをenumからuser_rolesテーブルに移行済み
- ✅ レガシーカラム削除済み (`role`, `name`, `department`, `provider`, `uid`)
- ✅ Pundit gemによる権限制御実装済み
- ✅ 管理者によるユーザー承認機能実装済み

### レガシーテーブル（未使用）
- ⚠️ `shifts`テーブル - 初期実装の残骸、`weekly_shifts`に置き換え済み
- ⚠️ `shift_schedules`テーブル - 初期実装の残骸、`daily_schedules`に置き換え済み
- **対応予定**: マイグレーションで削除すべき（本番データ確認後）

### 契約開始日の扱い
- `contract_start_date`カラムは存在するが、実際は`created_at`を契約開始日として使用
- 表示画面では`@user.created_at`を「契約開始日」として表示
- **理由**: ユーザー作成日 = 契約開始日という仕様

## Key Features Being Developed
- Student work hour tracking (20h/week limit compliance)
- Multi-job hour aggregation (40h/week total limit)
- Approval workflows for time-off requests
- Integration points with external systems (Rakuro, JobCan)