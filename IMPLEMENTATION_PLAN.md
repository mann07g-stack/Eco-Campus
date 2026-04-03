# Campus E-Waste Collection System - Build Plan

## 1. Solution Modules

1. Flutter Mobile App (`apps/mobile_flutter`)
- Student flow: create request, negotiate, accept quote, show QR.
- Member flow: member login, scan QR, confirm collection.

2. Admin Web App (`apps/web-admin`)
- View and filter requests.
- Quote and negotiate.
- Register and manage campus members.
- Dashboard charts for trends, categories, and member performance.

3. API Server (`apps/api`)
- Authentication and authorization.
- Request and negotiation lifecycle.
- QR token issue and scan verification.
- Analytics endpoints.

4. Database (MongoDB)
- Collections: users, requests, negotiations, qrTokens.

## 2. Request Status Lifecycle

`SUBMITTED -> QUOTED -> BARGAINING -> AGREED -> QR_ISSUED -> COLLECTED`

Additional terminal states:
- `CANCELLED`

## 3. Key User Journeys

1. Student submits e-waste request.
2. Admin reviews image + description and sends quote.
3. Student sends counter-offer if needed.
4. Admin and student settle on final amount.
5. Student generates QR.
6. Campus member scans QR and confirms pickup.

## 4. Security

1. JWT role-based auth for USER, MEMBER, ADMIN.
2. Password hashing with bcrypt.
3. QR payload signed and one-time usage via token record.
4. Request state transition checks.

## 5. Development Milestones

1. Backend setup and DB models.
2. Auth + request flow APIs.
3. Web admin modules and analytics.
4. Flutter student/member UX implementation.
5. End-to-end testing and deployment.
