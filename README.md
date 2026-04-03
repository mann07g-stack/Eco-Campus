# Eco-Campus

Eco-Campus is a campus e-waste collection platform with:

1. Flutter mobile app for students and campus members
2. React admin web console for operations and analytics
3. Node.js + Express API server
4. MongoDB database

## Monorepo Structure

```
apps/
	api/            # Node.js Express TypeScript backend
	web-admin/      # React + Vite admin dashboard
	mobile_flutter/ # Flutter app for users and campus members
IMPLEMENTATION_PLAN.md
```

## Core Flow

1. Student submits e-waste request with image and description.
2. Admin reviews and sends quote.
3. Student can counter-offer and bargain.
4. On agreement, app generates QR token.
5. Campus member scans QR and confirms collection.

## Environment Setup

Create and use these local files directly (already added in this repo, but still gitignored):

1. Root: `.env`
2. API: `apps/api/.env`
3. Web: `apps/web-admin/.env`
4. Mobile: `apps/mobile_flutter/.env`

Required backend values:

- `MONGODB_URI`
- `JWT_ACCESS_SECRET`
- `JWT_REFRESH_SECRET`

## Run Backend + Web

From repo root:

```bash
npm install
npm run dev:api
```

In another terminal:

```bash
npm run dev:web
```

## Run Flutter App

From `apps/mobile_flutter`:

```bash
flutter pub get
flutter run --dart-define=FLUTTER_API_BASE_URL=http://localhost:5000/api
```

## Notes

1. The admin web routes are role-protected by backend middleware; integrate JWT token storage/interceptors next.
2. Image upload is currently URL-based in the starter request flow; add Cloudinary or S3 upload endpoint for production.
3. Request status lifecycle is enforced in backend route handlers and can be expanded further with stricter transition guards.

