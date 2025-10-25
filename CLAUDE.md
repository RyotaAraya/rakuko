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
- **Authorization**: Pundit (planned)
- **State Management**: AASM (planned)
- **Background Jobs**: Sidekiq (planned)
- **Styling**: Tailwind CSS

### Code Organization

#### Rails Application Structure
- **Models**: Standard Rails models in `app/models/`
  - `User` model with Devise and OAuth integration
  - Role-based system with enum (student, department_manager, system_admin)
- **Controllers**:
  - `HomeController` for main application entry
  - `Users::OmniauthCallbacksController` for Google OAuth
- **Views**: ERB templates in `app/views/` with Vue.js integration points

#### Frontend Structure
- **Entry Point**: `frontend/entrypoints/application.ts` - Main Vite entry
- **Components**: Vue SFC components in `frontend/components/`
- **Styles**: Global CSS in `frontend/styles/application.css`
- **Types**: TypeScript definitions in `frontend/types/`

#### Database Schema
Key tables:
- `users` - User accounts with OAuth fields, roles, and department info
- `shift_requests` - Shift scheduling with status tracking

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

## Key Features Being Developed
- Student work hour tracking (20h/week limit compliance)
- Multi-job hour aggregation (40h/week total limit)
- Approval workflows for time-off requests
- Integration points with external systems (Rakuro, JobCan)