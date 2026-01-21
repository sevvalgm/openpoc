# 🎯 QUICK REFERENCE - Company Creation Error Fixes

**One-page troubleshooting guide**

---

## 🔴 Error Symptom → Root Cause → Solution

### Symptom: "Backend creation failed: 500"
```
Root Cause:
  ├─ userId null/undefined (from JWT)
  ├─ Company name empty
  ├─ Duplicate company name
  └─ Database constraint violation

Solution:
  1. Backend: Check createCompany() validation ✅ Added
  2. Backend: Verify userId in JWT payload
  3. Frontend: Validate form before sending ✅ Added
  4. Database: Run schema verification
```

---

### Symptom: "response.text() returns empty string ({})"
```
Root Cause:
  └─ No global exception filter → empty response body

Solution:
  1. Backend: Add HttpExceptionFilter ✅ Added
  2. main.ts: Register filter globally ✅ Added
  3. Frontend: Parse response safely ✅ Added
```

---

### Symptom: "Error message doesn't show to user"
```
Root Cause:
  ├─ Generic error handling
  ├─ Status code not checked
  └─ No error categorization

Solution:
  1. Frontend: Add status-based error handling ✅ Added
  2. Backend: Return structured response ✅ Added
  3. UI: Show context-specific message ✅ Already working
```

---

## 📋 Deployment Checklist

```bash
# 1. Backend Compilation
$ npm run build   # Should have zero errors

# 2. Database Migrations
$ prisma migrate deploy   # Run any pending migrations

# 3. Verify Environment Variables
$ echo $API_PREFIX        # Should output: api
$ echo $CORS_ORIGIN       # Should output: valid URL

# 4. Test Company Creation
curl -X POST http://localhost:4041/api/companies \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Co","type":"STARTUP"}'

# Expected: 201 Created + JSON response
# NOT: 500 + empty body
# NOT: {} response

# 5. Test Error Scenarios
# Try with duplicate name → should get 409
# Try without auth → should get 401
# Try with invalid name → should get 400
```

---

## 🔍 Debug Commands

### Backend
```bash
# Check logs for errors
tail -f logs/app.log | grep -i "error"

# Run createCompany test
npm run test -- companies.service.spec.ts --verbose

# Verify exception filter is registered
grep -n "useGlobalFilters" src/main.ts
```

### Frontend
```bash
# Check browser console for error details
console.error() will show:
- message: Human-readable error
- code: Machine-readable code
- status: HTTP status code

# Network tab in DevTools
- Check request body is valid JSON
- Check response is not empty ({})
- Check Content-Type header
```

---

## 🧪 Test Data

### Valid Request
```json
{
  "name": "Acme Corporation",
  "type": "STARTUP",
  "industry": "Technology",
  "description": "We build amazing things",
  "website": "https://acme.com",
  "logo": "https://acme.com/logo.png",
  "size": "10-50"
}
```

### Error Cases
```json
// Empty name → 400 Bad Request
{"name": ""}

// Duplicate name → 409 Conflict
{"name": "Existing Company"}

// No auth → 401 Unauthorized
// (No Authorization header)

// Invalid token → 401 Unauthorized
// (Token invalid or expired)
```

---

## 📊 What Changed?

### Backend
| File | Lines | Change |
|------|-------|--------|
| companies.service.ts | 56-170 | Enhanced validation |
| http-exception.filter.ts | NEW | Exception handling |
| main.ts | 6, 34 | Filter registration |

### Frontend
| File | Lines | Change |
|------|-------|--------|
| platform-context.tsx | 177-245 | Error handling |

---

## 🚨 Common Issues & Fixes

| Issue | Fix |
|-------|-----|
| Still getting 500 errors | Restart backend server, check console |
| Response is empty {} | Verify HttpExceptionFilter registered |
| Status code not working | Check response.status is being read |
| Form validation not working | Check companyName is being trimmed |
| Token keeps expiring | Check JWT expiration time in .env |
| CORS errors | Verify CORS_ORIGIN matches frontend URL |

---

## 📞 Quick Debugging

**When things don't work:**

1. **Check backend logs first**
   ```bash
   grep -i "company" logs/app.log | tail -20
   ```

2. **Check browser DevTools**
   - Network tab → Check request/response
   - Console tab → Check error details
   - Application tab → Check token in localStorage

3. **Test with curl**
   ```bash
   curl -v http://localhost:4041/api/companies
   ```

4. **Verify environment**
   ```bash
   # Backend
   echo $JWT_SECRET       # Should not be empty
   echo $DATABASE_URL     # Should be valid
   
   # Frontend
   echo $NEXT_PUBLIC_API_BASE_URL  # Should be correct
   ```

---

## 🎓 Remember

✅ **Always validate userId** - JWT might be incomplete  
✅ **Parse responses safely** - Body might be empty or text  
✅ **Handle status codes** - 409 ≠ 500 ≠ 401  
✅ **Log at each step** - Easier debugging  
✅ **Return structured JSON** - Never empty body  
✅ **Use transactions** - Prevents race conditions  
✅ **Test error paths** - Not just happy path  

---

**Status:** ✅ All fixed | Ready for production | Document version 1.0

