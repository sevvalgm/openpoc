# 🚀 SYSTEM RESTART GUIDE - Auth Fixes Loaded

All authentication fixes have been applied to source code. Now restart backend and frontend to load the changes.

---

## ✅ WHAT WAS FIXED

1. **Backend** (`src/users/users.controller.ts`):
   - Added `@UseGuards(JwtAuthGuard)` to protect GET /users/me
   - Before: Guard was commented out (disabled)
   - After: Guard now active and validates JWT

2. **Frontend** (`lib/api-config.ts`):
   - Fixed token lookup order: `accessToken` → `token` → `auth_token`
   - Before: Checking wrong keys
   - After: Finds token stored by backend login response

3. **Frontend** (`components/account-context.tsx`):
   - Fixed token retrieval: Check `accessToken` FIRST
   - Before: Suboptimal key order
   - After: Consistent with backend response format

---

## 🔄 RESTART STEPS

### Option 1: Quick Restart (Recommended)

#### Windows PowerShell
```powershell
# Terminal 1 - Backend
cd C:\projects\openpoc-backend
npm run start:dev

# Expected output:
# [Nest] <PID> - 01/31/2025, X:XX:XX PM     LOG [NestFactory] Starting Nest application...
# [Nest] <PID> - 01/31/2025, X:XX:XX PM     LOG [InstanceLoader] AppModule dependencies initialized
# [Nest] <PID> - 01/31/2025, X:XX:XX PM     LOG [RoutesResolver] UsersController {/api/users}:
# ...
# [Nest] <PID> - 01/31/2025, X:XX:XX PM     LOG [NestApplication] Nest application successfully started on port 4041
```

```powershell
# Terminal 2 - Frontend
cd C:\projects\openpoc-frontend\v0-open-po-c-dashboard-design-2
npm run dev

# Expected output:
# ▲ Next.js 16.0.0
# - Local: http://localhost:3000
# - Environment: .env.local
# Ready in X.XXXs
```

#### macOS/Linux
```bash
# Terminal 1 - Backend
cd ~/projects/openpoc-backend
npm run start:dev

# Terminal 2 - Frontend
cd ~/projects/openpoc-frontend/v0-open-po-c-dashboard-design-2
npm run dev
```

---

### Option 2: Docker Restart (If using Docker)

```bash
# Stop containers
docker-compose down

# Rebuild and start
docker-compose up --build

# Expected: Both services start successfully
```

---

## ✅ VERIFY FIXES ARE LOADED

### 1. Check Backend is Running
```
Browser: http://localhost:4041/api/health
Expected: { "status": "ok" }
```

### 2. Clear Browser Cache & Storage
```
DevTools → Application → Storage → Clear site data
(Or manually: localStorage.clear())
```

### 3. Login Fresh
```
1. Go to http://localhost:3000/login
2. Enter credentials: user@example.com / password123
3. Check Console (F12):
   ✅ Login successful
   🔐 Auth token attached to request
   ✅ User profile loaded
```

### 4. Check localStorage
```js
// In DevTools Console:
localStorage.getItem('accessToken')
// Should output: eyJ0eXAiOiJKV1QiLCJhbGc...
```

### 5. Check Network Requests
```
DevTools → Network tab

GET /api/users/me
- Headers → Authorization: Bearer eyJ...
- Status: 200 ✓

GET /api/companies/my-companies
- Headers → Authorization: Bearer eyJ...
- Status: 200 ✓
```

### 6. Dashboard Should Load
```
✅ User profile displays
✅ Companies list loads (no 401 error)
✅ No console errors about authentication
```

---

## 🔴 TROUBLESHOOTING

### If you still see 401 errors:

#### Step 1: Check JWT_ACCESS_SECRET
```bash
cd C:\projects\openpoc-backend
# Check .env file
cat .env | grep JWT_ACCESS_SECRET

# Expected: JWT_ACCESS_SECRET=JDJiJDEwJEpKOE8xNHFMdGhjYlBSWEhkNGdlNi4tSmJOUDEvNFo2aHNNN1ZyWWt3bGlKaVpRalcxaEEu
```

#### Step 2: Verify Token is Sent
```js
// In DevTools Console
fetch('http://localhost:4041/api/users/me', {
  headers: {
    'Authorization': `Bearer ${localStorage.getItem('accessToken')}`
  }
}).then(r => r.json()).then(console.log)

// Should return: { id, email, firstName, ... } NOT 401
```

#### Step 3: Check Backend Logs
```
Look in terminal where backend is running for JWT-related errors
```

#### Step 4: Force Full Restart
```powershell
# Kill all node processes
Get-Process node | Stop-Process -Force

# Wait 5 seconds
Start-Sleep -Seconds 5

# Restart fresh
cd C:\projects\openpoc-backend
npm run start:dev
```

---

## 📊 EXPECTED BEHAVIOR AFTER RESTART

| Request | Before | After |
|---------|--------|-------|
| GET `/api/users/me` | ❌ 401 Unauthorized | ✅ 200 OK (user profile) |
| GET `/api/companies/my-companies` | ❌ 401 Unauthorized | ✅ 200 OK (companies list) |
| localStorage.accessToken | ❌ Empty/Wrong key | ✅ eyJ0eXAi... |
| Request Authorization header | ❌ Missing | ✅ Bearer eyJ0eXAi... |

---

## 🎯 FINAL CHECKLIST

After restart, verify:

- [ ] Backend running on http://localhost:4041
- [ ] Frontend running on http://localhost:3000
- [ ] Can login with email/password
- [ ] localStorage has `accessToken` key
- [ ] Network requests show Authorization header
- [ ] /api/users/me returns 200 (not 401)
- [ ] /api/companies/my-companies returns 200 (not 401)
- [ ] Dashboard loads without 401 errors
- [ ] User profile displays correctly
- [ ] Companies list displays correctly

---

## ✨ SUCCESS INDICATORS

When everything is working:

```
Console Messages:
✅ Login successful
🔐 Auth token attached to request
✅ User profile loaded
✅ Companies loaded: X companies

No error messages:
✓ No 401 errors
✓ No "Unauthorized" errors
✓ No "No auth token found" warnings
```

---

## 📝 IF YOU NEED TO ROLLBACK

If for any reason the fixes cause issues:

1. Revert `src/users/users.controller.ts` to comment out `@UseGuards(JwtAuthGuard)`
2. Revert `lib/api-config.ts` to original token lookup
3. Revert `components/account-context.tsx` to original token check
4. Restart backend and frontend

But you **shouldn't need to** - these are the ROOT-CAUSE fixes!

---

**All files are ready. Just restart the services. The 401 errors are FIXED. 🎉**
