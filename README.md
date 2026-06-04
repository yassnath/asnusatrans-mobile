# AS Nusa Trans Mobile

**AS Nusa Trans Mobile** is a mobile-first logistics operations platform for transport businesses that need finance, fleet, invoice, expense, and reporting workflows in one connected system.

Built for real daily operations, the app helps transport teams move faster, reduce repeated manual work, and keep business data consistent from field activity to financial reporting.

Powered by Supabase and Firebase, the platform combines structured operational data with timely notifications, so teams can act on approvals, customer updates, payment reminders, and finance signals without waiting for manual follow-up.

## Product Overview

Transport operations often depend on scattered chats, spreadsheets, handwritten notes, and manual follow-up. AS Nusa Trans Mobile brings those moving parts into a focused operational command center where income, expenses, fleet usage, customer invoices, and owner visibility stay connected.

The result is a cleaner workflow for teams that need speed, accountability, and reliable printable documents.

## Key Advantages

- **Operationally practical**
  Designed around real transport details such as route, tonnage, armada, driver, customer, invoice entity, and payment status.

- **Finance-ready from day one**
  Supports invoice preview, fixed invoice grouping, expense records, payment status, PPH handling, and printable PDF outputs.

- **Mobile-first execution**
  Optimized for fast admin and field usage on smaller screens while still supporting larger desktop workflows.

- **Role-aware experience**
  Admin, owner, pengurus, and customer flows are separated so every user sees the right actions and information.

- **Cleaner business control**
  Helps owners monitor revenue, expenses, fleet movement, and unpaid activity without waiting for manual recaps.

- **Notification-powered coordination**
  Firebase-powered push notifications and in-app alerts help teams respond faster to finance reminders, customer activity, approvals, and operational updates.

## Core Features

### Income and Invoice Management

- Add and edit income with detailed trip rows
- Support for `Pribadi`, `CV. ANT`, and `PT. ANT` invoice modes
- Multi-detail invoice handling for repeated or grouped trips
- Manual subtotal support for special pricing cases
- Invoice preview before printing
- Fixed invoice grouping and reprint-friendly history
- Editable KOP data for printed invoice documents
- Dynamic invoice numbering based on business rules

### Expense Management

- Manual expense creation and tracking
- Expense preview and printable outputs
- Auto-generated driver allowance expenses from income data
- Support for route-based and special-case operational expenses
- Paid status visibility for expense records

### Armada and Driver Operations

- Armada list with availability status
- Ready, full, and inactive operational visibility
- Driver synchronization from selected armada
- Manual armada input for gabungan or special operational cases
- Fleet usage tracking from invoice schedule data

### Reports and Print Output

- Monthly and yearly operational reports
- Income-only, expense-only, and combined report modes
- PDF outputs designed for real business use
- Route, customer, status, and invoice-type filtering
- Fixed invoice reporting with payment tracking

### Dashboard and Monitoring

- Revenue and expense summaries
- Latest transaction visibility
- Armada usage overview
- Calendar timeline for income, expense, and fleet activity
- Role-specific dashboard content for faster decision-making

### Smart Notifications

- Firebase Cloud Messaging integration for push-ready operational alerts
- Foreground and background notification handling for important updates
- Role-based notification routing for staff, owner, admin, pengurus, and customer flows
- In-app customer notifications for invoice and order activity
- Finance reminder notifications for recurring weekly and monthly visibility
- Local notification support for a smoother cross-platform user experience

## Business Impact

AS Nusa Trans Mobile helps transport teams:

- reduce duplicate data entry
- improve invoice and expense consistency
- speed up document preparation
- improve owner visibility into cash flow
- connect field operations with finance records
- keep route, driver, armada, and payment data easier to audit
- reduce missed follow-ups through timely operational notifications

## Enterprise Readiness

The codebase is being shaped toward a cleaner enterprise foundation with extracted business logic, automated quality checks, focused regression tests, integration smoke coverage, and clearer documentation for future development.

Recent improvements strengthen the reporting and invoice areas by separating core logic from presentation code, making critical calculations easier to test, maintain, and evolve.

## Technology Foundation

- **Flutter** for cross-platform mobile and desktop delivery
- **Supabase** for authentication and data services
- **Firebase Cloud Messaging** for push notification delivery
- **Local notifications** for on-device reminders and foreground alerts
- **PDF and printing workflows** for business-ready documents
- **Protected session state handling** for safer operational continuity
- **Automated analysis, regression testing, and integration smoke checks** to protect key business flows

## Positioning

AS Nusa Trans Mobile is more than a simple invoice app. It is a logistics operations system for teams that need:

- reliable invoice workflows
- controlled expense tracking
- readable fleet monitoring
- practical print output
- route-based operational rules
- push-enabled operational coordination
- business visibility for owners and admins

For transport teams that care about speed, clarity, and financial control, AS Nusa Trans Mobile gives the operation a stronger digital backbone.
