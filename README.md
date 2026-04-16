# AS Nusa Trans Mobile

**AS Nusa Trans Mobile** is a mobile-first logistics operations app built for transport businesses that need finance, fleet, and operational visibility in one place.

This project is designed for real daily execution, not just reporting. From invoice creation and auto-generated driver allowance expenses to fleet scheduling and printable documents, the app helps transport teams move faster with fewer manual steps.

## Why This Product Matters

Most transport businesses still split work across chat, spreadsheets, and manual approvals. That creates delays, duplicated input, and weak visibility.

AS Nusa Trans Mobile solves that by turning the daily workflow into one connected operational system:

- create and manage invoices with multi-trip detail rows
- record and track expenses with printable outputs
- monitor fleet usage and availability
- group operational data by role: admin, owner, and customer
- keep finance and field activity connected in one timeline

## What Makes It Strong

- **Operationally grounded**
  Built around actual transport workflows, including route, tonnage, armada, driver, and payment status.

- **Finance-ready**
  Supports invoice printing, expense printing, PDF reports, fixed invoice history, and company vs personal invoice behavior.

- **Faster daily execution**
  Repetitive tasks such as invoice detail entry, auto expense generation, and print preparation are streamlined for speed.

- **Role-aware by design**
  Different users see different actions, data, and summaries based on what they actually need to do.

- **Mobile-first with desktop support**
  Optimized for fast field usage, but still practical for larger-screen operations on Windows desktop.

## Core Features

### Authentication and Access

- Sign in and sign up flow
- Session persistence
- Biometric authentication option
- Role-based access control

### Dashboard

- Revenue and operational summaries
- Latest and biggest transaction insights
- Armada usage overview
- Role-specific dashboard content

### Income and Invoice Workflow

- Add and edit income with multi-detail departure rows
- Support for armada dropdown and manual armada input
- Driver sync based on selected armada
- Invoice entity support for `Pribadi`, `CV. ANT`, and `PT. ANT`
- Invoice preview, KOP editing, PDF print, and fixed invoice history
- Dynamic invoice numbering using business-friendly formats

### Expense Workflow

- Manual expense entry and management
- Printable expense documents
- Auto-generated driver allowance expenses from income records
- Better expense visibility inside calendar and invoice-related flows

### Armada Workflow

- Armada list and status overview
- Armada usage timeline from invoice schedule data
- Ready / Full / Inactive visibility for operational planning

### Reporting and Monitoring

- Monthly and yearly PDF reports
- Income-only, expense-only, or mixed report output
- Calendar timeline for income, expense, and armada movement
- Filterable views for faster operational review

## Business Impact

- reduces manual coordination across finance and operations
- improves invoice and expense consistency
- gives owners faster visibility into cash flow and fleet activity
- keeps printable outputs ready for real business use
- creates a stronger digital foundation for logistics growth

## Product Positioning

AS Nusa Trans Mobile is not just an admin panel.

It is an **operational command center** for transport teams that need:

- clean invoice workflows
- reliable expense control
- readable fleet monitoring
- role-based access
- production-friendly print outputs

If your operation depends on speed, accountability, and clear financial movement, this app is built for that environment.

## Tech Stack

- **Flutter** for cross-platform application development
- **Supabase** for authentication and data layer
- **PDF / Printing** for business document output
- **Shared Preferences + Secure Storage** for session and local operational state

## Release and Operations

### Android Release Build

For release APK generation, use:

```powershell
powershell -ExecutionPolicy Bypass -File tooling/android/build_release.ps1 `
  -SupabaseUrl "https://your-project.supabase.co" `
  -SupabaseAnonKey "your-anon-key"
```

If you want a signed production build, create `android/keystore.properties`
based on `android/keystore.properties.example` and place your keystore file
outside version control.

If you need an app bundle for Play Console:

```powershell
powershell -ExecutionPolicy Bypass -File tooling/android/build_release.ps1 `
  -SupabaseUrl "https://your-project.supabase.co" `
  -SupabaseAnonKey "your-anon-key" `
  -BuildAppBundle
```

### Push Notification Setup

Set Firebase service account secrets to Supabase:

```powershell
powershell -ExecutionPolicy Bypass -File tooling/supabase/set_push_secrets.ps1 `
  -ServiceAccountJsonPath "C:\path\to\firebase-service-account.json" `
  -ProjectRef "your-supabase-project-ref"
```

Then deploy the function:

```powershell
npx supabase functions deploy send-push --project-ref your-supabase-project-ref --use-api
```

### Supabase Invoice Entity Patch

If you are upgrading an existing project and want the new `Pribadi / CV. ANT / PT. ANT`
invoice split to work consistently in list, fix invoice, edit, and print flows,
run this patch in Supabase SQL Editor:

```sql
\i supabase/invoice_entity_support.sql
```

If you are using the dashboard manually through the Supabase web editor, copy the
contents of `supabase/invoice_entity_support.sql` and run it as `postgres`.

### Push Smoke Test

To verify that push delivery is alive from Supabase to admin/owner devices:

```powershell
powershell -ExecutionPolicy Bypass -File tooling/supabase/test_send_push.ps1 `
  -SupabaseUrl "https://your-project.supabase.co" `
  -SupabaseAnonKey "your-anon-key" `
  -Email "pengurus@cvant.local" `
  -Password "your-password"
```

### Quality Gate

Before shipping, run:

```powershell
powershell -ExecutionPolicy Bypass -File tooling/windows/run_quality_gate.ps1
```

The script stops early if the local Windows app from this workspace is still
running, because that can lock generated plugin files and make tests fail for
environment reasons instead of code reasons.

## Current Strength of the Repo

This codebase already includes strong operational behavior such as:

- invoice print preview and fixed-invoice reprint flow
- grouped invoice print generation with editable KOP data
- auto driver allowance expense synchronization
- calendar ordering for income, expense, and armada events
- armada usage monitoring on the dashboard
- mobile-oriented form handling for high-frequency admin work

## Closing

AS Nusa Trans Mobile is built for teams that do real transport work every day and need software that can keep up.

It brings together invoicing, expenses, fleet movement, and reporting into one focused system so operations stay faster, clearer, and easier to control.
