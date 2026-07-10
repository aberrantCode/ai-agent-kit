---
name: security
description: OWASP security patterns, secrets management, and security testing, plus a comprehensive security review checklist. Use this skill when adding authentication, handling user input, working with secrets, creating API endpoints, or implementing payment/sensitive features.
---

# Security Skill

*Load with: base.md*

Security best practices, automated security testing, and a comprehensive security review checklist for all projects.

---

## Core Principle

**Security is not optional.** Every project must pass security checks before merge. Assume all input is malicious, all secrets will leak if committed, and all dependencies have vulnerabilities.

---

## When to Activate

Apply the full review checklist in this skill whenever you are:

- Implementing authentication or authorization
- Handling user input or file uploads
- Creating new API endpoints
- Working with secrets or credentials
- Implementing payment features
- Storing or transmitting sensitive data
- Integrating third-party APIs

---

## Required Security Setup

### 1. Gitignore (Non-Negotiable)

Every project must have these in `.gitignore`:

```gitignore
# Environment files - NEVER commit
.env
.env.*
!.env.example

# Secrets
*.pem
*.key
*.p12
*.pfx
credentials.json
secrets.json
*-credentials.json
service-account*.json

# IDE and OS
.idea/
.vscode/settings.json
.DS_Store
Thumbs.db

# Dependencies
node_modules/
__pycache__/
*.pyc
.venv/
venv/

# Build outputs
dist/
build/
*.egg-info/

# Logs that might contain sensitive data
*.log
logs/
```

### 2. Environment Variables

**Create `.env.example`** with all required vars (no values):
```bash
# .env.example - Copy to .env and fill in values

# Server-side only (NEVER prefix with VITE_ or NEXT_PUBLIC_)
DATABASE_URL=
ANTHROPIC_API_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# Client-side safe (public, non-sensitive)
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
```

### Frontend Environment Variables (Critical!)

**NEVER put secrets in client-exposed env vars:**

| Framework | Client-Exposed Prefix | Server-Only |
|-----------|----------------------|-------------|
| Vite | `VITE_*` | No prefix |
| Next.js | `NEXT_PUBLIC_*` | No prefix |
| Create React App | `REACT_APP_*` | N/A (no server) |

```typescript
// WRONG - Secret exposed to browser bundle!
const apiKey = import.meta.env.VITE_ANTHROPIC_API_KEY;

// CORRECT - Only public values client-side
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;

// CORRECT - Secrets stay server-side only
// In API route or server function:
const apiKey = process.env.ANTHROPIC_API_KEY;
```

**Vercel Environment Variables:**
- In Vercel dashboard, secrets without `VITE_` prefix are server-only
- Only `VITE_*` vars are bundled into client code
- Always verify in browser devtools → Sources → your bundle that secrets aren't exposed

**Validate environment at startup:**
```typescript
// config/env.ts
import { z } from 'zod';

const envSchema = z.object({
  DATABASE_URL: z.string().url(),
  ANTHROPIC_API_KEY: z.string().min(1),
  NODE_ENV: z.enum(['development', 'production', 'test']),
});

export const env = envSchema.parse(process.env);
```

```python
# config/env.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str
    anthropic_api_key: str
    environment: str = "development"

    class Config:
        env_file = ".env"

settings = Settings()
```

### Secrets Verification Steps

- [ ] No hardcoded API keys, tokens, or passwords
- [ ] All secrets in environment variables
- [ ] `.env` / `.env.local` in .gitignore
- [ ] No secrets in git history
- [ ] Production secrets in hosting platform (Vercel, Railway)

---

## Security Tests

### Pre-Commit Security Checks

Add to pre-commit hooks:

**For all projects:**
```yaml
# .pre-commit-config.yaml (add to existing)
repos:
  # Detect secrets
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']

  # Check for security issues in dependencies
  - repo: local
    hooks:
      - id: security-check
        name: security-check
        entry: ./scripts/security-check.sh
        language: script
        pass_filenames: false
```

**TypeScript/JavaScript:**
```json
// package.json scripts
{
  "scripts": {
    "security:audit": "npm audit --audit-level=high",
    "security:secrets": "npx secretlint '**/*'",
    "security:deps": "npx better-npm-audit audit"
  }
}
```

**Python:**
```bash
# Add to dev dependencies
pip install safety bandit

# Commands
safety check           # Check dependencies for vulnerabilities
bandit -r src/        # Static security analysis
```

### Security Check Script

Create `scripts/security-check.sh`:

```bash
#!/bin/bash
set -e

echo "Running security checks..."

# Check for secrets in staged files
echo "Checking for secrets..."
if command -v detect-secrets &> /dev/null; then
  detect-secrets scan --baseline .secrets.baseline
fi

# Check .env is not staged
if git diff --cached --name-only | grep -E '^\.env$|^\.env\.' | grep -v '\.example$'; then
  echo "ERROR: .env file is staged for commit!"
  exit 1
fi

# Check for common secret patterns in staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)
if echo "$STAGED_FILES" | xargs grep -l -E '(password|secret|api_key|apikey|token|private_key)\s*[:=]\s*["\047][^"\047]+["\047]' 2>/dev/null; then
  echo "ERROR: Possible secrets found in staged files!"
  exit 1
fi

# Language-specific checks
if [ -f "package.json" ]; then
  echo "Checking npm dependencies..."
  npm audit --audit-level=high || echo "Warning: npm audit found issues"
fi

if [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
  echo "Checking Python dependencies..."
  if command -v safety &> /dev/null; then
    safety check || echo "Warning: safety found issues"
  fi
fi

echo "Security checks passed!"
```

```bash
chmod +x scripts/security-check.sh
```

---

## GitHub Actions Security Workflow

Create `.github/workflows/security.yml`:

```yaml
name: Security

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    # Run weekly on Monday at 9am UTC
    - cron: '0 9 * * 1'

jobs:
  secrets-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Detect secrets
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.pull_request.base.sha }}
          head: ${{ github.event.pull_request.head.sha }}

  dependency-audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Node.js projects
      - name: Setup Node
        if: hashFiles('package.json') != ''
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        if: hashFiles('package.json') != ''
        run: npm ci

      - name: NPM Audit
        if: hashFiles('package.json') != ''
        run: npm audit --audit-level=high

      # Python projects
      - name: Setup Python
        if: hashFiles('pyproject.toml') != '' || hashFiles('requirements.txt') != ''
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install safety
        if: hashFiles('pyproject.toml') != '' || hashFiles('requirements.txt') != ''
        run: pip install safety

      - name: Safety check
        if: hashFiles('pyproject.toml') != '' || hashFiles('requirements.txt') != ''
        run: safety check

  codeql:
    runs-on: ubuntu-latest
    permissions:
      security-events: write
    steps:
      - uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: ${{ hashFiles('package.json') != '' && 'javascript-typescript' || 'python' }}

      - name: Autobuild
        uses: github/codeql-action/autobuild@v3

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
```

---

## Input Validation (OWASP Top 10)

### 1. SQL Injection Prevention

**Never use string concatenation:**
```typescript
// BAD - SQL injection vulnerable
const user = await db.query(`SELECT * FROM users WHERE id = ${userId}`);

// GOOD - Parameterized query
const user = await db.query('SELECT * FROM users WHERE id = $1', [userId]);

// GOOD - Using ORM (Kysely, Prisma, Drizzle)
const user = await db.selectFrom('users').where('id', '=', userId).execute();

// GOOD - Supabase query builder (parameterized internally)
const { data } = await supabase.from('users').select('*').eq('email', userEmail);
```

```python
# BAD - SQL injection vulnerable
cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")

# GOOD - Parameterized query
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))

# GOOD - Using ORM (SQLAlchemy)
user = session.query(User).filter(User.id == user_id).first()
```

### 2. XSS Prevention

```typescript
// Always sanitize user input before rendering
import DOMPurify from 'dompurify';

// BAD - XSS vulnerable
element.innerHTML = userInput;

// GOOD - Sanitized
element.innerHTML = DOMPurify.sanitize(userInput);

// GOOD - Sanitized with an explicit allowlist
const clean = DOMPurify.sanitize(html, {
  ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'p'],
  ALLOWED_ATTR: []
});

// BEST - Use framework's built-in escaping (React does this by default)
return <div>{userInput}</div>;  // Safe in React

// DANGER - Bypasses React's protection
return <div dangerouslySetInnerHTML={{ __html: userInput }} />;  // Avoid!
```

### 3. Input Validation at Boundaries

```typescript
// Validate ALL external input with Zod
import { z } from 'zod';

const CreateUserSchema = z.object({
  email: z.string().email().max(255),
  name: z.string().min(1).max(100).regex(/^[a-zA-Z\s]+$/),
  age: z.number().int().min(0).max(150),
});

// In route handler
app.post('/users', async (req, res) => {
  const result = CreateUserSchema.safeParse(req.body);
  if (!result.success) {
    return res.status(400).json({ error: result.error });
  }
  // result.data is now typed and validated
});
```

Prefer **whitelist validation** (define what is allowed) over blacklist validation (enumerate what is forbidden), and keep validation error messages free of sensitive internals.

### 4. File Upload Validation

```typescript
function validateFileUpload(file: File) {
  // Size check (5MB max)
  const maxSize = 5 * 1024 * 1024
  if (file.size > maxSize) {
    throw new Error('File too large (max 5MB)')
  }

  // Type check
  const allowedTypes = ['image/jpeg', 'image/png', 'image/gif']
  if (!allowedTypes.includes(file.type)) {
    throw new Error('Invalid file type')
  }

  // Extension check
  const allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif']
  const extension = file.name.toLowerCase().match(/\.[^.]+$/)?.[0]
  if (!extension || !allowedExtensions.includes(extension)) {
    throw new Error('Invalid file extension')
  }

  return true
}
```

### 5. Path Traversal Prevention

```typescript
import path from 'path';

// BAD - Path traversal vulnerable
const filePath = `./uploads/${req.params.filename}`;

// GOOD - Validate and sanitize path
const filename = path.basename(req.params.filename);  // Strips ../
const filePath = path.join('./uploads', filename);

// Verify it's still within allowed directory
if (!filePath.startsWith(path.resolve('./uploads'))) {
  throw new Error('Invalid path');
}
```

---

## Authentication & Authorization

### JWT Best Practices

```typescript
import jwt from 'jsonwebtoken';

// Token generation
function generateToken(userId: string): string {
  return jwt.sign(
    { sub: userId },
    process.env.JWT_SECRET!,
    {
      expiresIn: '15m',      // Short-lived access tokens
      algorithm: 'HS256',
    }
  );
}

// Token verification
function verifyToken(token: string): { sub: string } {
  return jwt.verify(token, process.env.JWT_SECRET!, {
    algorithms: ['HS256'],   // Explicitly specify allowed algorithms
  }) as { sub: string };
}
```

### Token Storage

```typescript
// ❌ WRONG: localStorage (vulnerable to XSS)
localStorage.setItem('token', token)

// ✅ CORRECT: httpOnly cookies
res.setHeader('Set-Cookie',
  `token=${token}; HttpOnly; Secure; SameSite=Strict; Max-Age=3600`)
```

### Authorization Checks

Always verify authorization **before** sensitive operations — never after:

```typescript
export async function deleteUser(userId: string, requesterId: string) {
  // ALWAYS verify authorization first
  const requester = await db.users.findUnique({
    where: { id: requesterId }
  })

  if (requester.role !== 'admin') {
    return NextResponse.json(
      { error: 'Unauthorized' },
      { status: 403 }
    )
  }

  // Proceed with deletion
  await db.users.delete({ where: { id: userId } })
}
```

### Row Level Security (Supabase)

```sql
-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Users can only view their own data
CREATE POLICY "Users view own data"
  ON users FOR SELECT
  USING (auth.uid() = id);

-- Users can only update their own data
CREATE POLICY "Users update own data"
  ON users FOR UPDATE
  USING (auth.uid() = id);
```

### Password Hashing

```typescript
import bcrypt from 'bcrypt';

const SALT_ROUNDS = 12;  // Minimum 10, recommended 12+

async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, SALT_ROUNDS);
}

async function verifyPassword(password: string, hash: string): Promise<boolean> {
  return bcrypt.compare(password, hash);
}
```

```python
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(password: str, hashed: str) -> bool:
    return pwd_context.verify(password, hashed)
```

### Rate Limiting

```typescript
import rateLimit from 'express-rate-limit';

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 100,                   // 100 requests per window
  standardHeaders: true,
  legacyHeaders: false,
});

// Apply to all API routes
app.use('/api/', limiter);

// Apply stricter limits to auth routes
app.use('/api/auth', rateLimit({
  windowMs: 60 * 1000,  // 1 minute
  max: 5,                // 5 attempts per minute
  message: 'Too many login attempts, please try again later',
}));

// Aggressive rate limiting for expensive operations (e.g., search)
app.use('/api/search', rateLimit({
  windowMs: 60 * 1000,  // 1 minute
  max: 10,               // 10 requests per minute
  message: 'Too many search requests',
}));
```

Rate-limit verification steps:
- [ ] Rate limiting on all API endpoints
- [ ] Stricter limits on auth and expensive operations
- [ ] IP-based rate limiting
- [ ] User-based rate limiting (authenticated)

---

## CSRF Protection

### CSRF Tokens

```typescript
import { csrf } from '@/lib/csrf'

export async function POST(request: Request) {
  const token = request.headers.get('X-CSRF-Token')

  if (!csrf.verify(token)) {
    return NextResponse.json(
      { error: 'Invalid CSRF token' },
      { status: 403 }
    )
  }

  // Process request
}
```

### SameSite Cookies

```typescript
res.setHeader('Set-Cookie',
  `session=${sessionId}; HttpOnly; Secure; SameSite=Strict`)
```

CSRF verification steps:
- [ ] CSRF tokens on state-changing operations
- [ ] SameSite=Strict on all cookies
- [ ] Double-submit cookie pattern implemented

---

## Security Headers

```typescript
import helmet from 'helmet';

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
  },
}));
```

For Next.js, configure CSP via headers in `next.config.js`:

```typescript
// next.config.js
const securityHeaders = [
  {
    key: 'Content-Security-Policy',
    value: `
      default-src 'self';
      script-src 'self' 'unsafe-eval' 'unsafe-inline';
      style-src 'self' 'unsafe-inline';
      img-src 'self' data: https:;
      font-src 'self';
      connect-src 'self' https://api.example.com;
    `.replace(/\s{2,}/g, ' ').trim()
  }
]
```

---

## Sensitive Data Exposure

### Logging

```typescript
// ❌ WRONG: Logging sensitive data
console.log('User login:', { email, password })
console.log('Payment:', { cardNumber, cvv })

// ✅ CORRECT: Redact sensitive data
console.log('User login:', { email, userId })
console.log('Payment:', { last4: card.last4, userId })
```

### Error Messages

```typescript
// ❌ WRONG: Exposing internal details
catch (error) {
  return NextResponse.json(
    { error: error.message, stack: error.stack },
    { status: 500 }
  )
}

// ✅ CORRECT: Generic error messages
catch (error) {
  console.error('Internal error:', error)
  return NextResponse.json(
    { error: 'An error occurred. Please try again.' },
    { status: 500 }
  )
}
```

Verification steps:
- [ ] No passwords, tokens, or secrets in logs
- [ ] Error messages generic for users
- [ ] Detailed errors only in server logs
- [ ] No stack traces exposed to users

---

## Blockchain Security (Solana)

### Wallet Verification

```typescript
import { verify } from '@solana/web3.js'

async function verifyWalletOwnership(
  publicKey: string,
  signature: string,
  message: string
) {
  try {
    const isValid = verify(
      Buffer.from(message),
      Buffer.from(signature, 'base64'),
      Buffer.from(publicKey, 'base64')
    )
    return isValid
  } catch (error) {
    return false
  }
}
```

### Transaction Verification

```typescript
async function verifyTransaction(transaction: Transaction) {
  // Verify recipient
  if (transaction.to !== expectedRecipient) {
    throw new Error('Invalid recipient')
  }

  // Verify amount
  if (transaction.amount > maxAmount) {
    throw new Error('Amount exceeds limit')
  }

  // Verify user has sufficient balance
  const balance = await getBalance(transaction.from)
  if (balance < transaction.amount) {
    throw new Error('Insufficient balance')
  }

  return true
}
```

Verification steps:
- [ ] Wallet signatures verified
- [ ] Transaction details validated
- [ ] Balance checks before transactions
- [ ] No blind transaction signing

---

## Dependency Security

```bash
# Check for vulnerabilities
npm audit

# Fix automatically fixable issues
npm audit fix

# Update dependencies
npm update

# Check for outdated packages
npm outdated
```

**Lock files:**

```bash
# ALWAYS commit lock files
git add package-lock.json

# Use in CI/CD for reproducible builds
npm ci  # Instead of npm install
```

Verification steps:
- [ ] Dependencies up to date
- [ ] No known vulnerabilities (npm audit / safety check clean)
- [ ] Lock files committed
- [ ] Dependabot enabled on GitHub
- [ ] Regular security updates

---

## Automated Security Tests

```typescript
// Test authentication
test('requires authentication', async () => {
  const response = await fetch('/api/protected')
  expect(response.status).toBe(401)
})

// Test authorization
test('requires admin role', async () => {
  const response = await fetch('/api/admin', {
    headers: { Authorization: `Bearer ${userToken}` }
  })
  expect(response.status).toBe(403)
})

// Test input validation
test('rejects invalid input', async () => {
  const response = await fetch('/api/users', {
    method: 'POST',
    body: JSON.stringify({ email: 'not-an-email' })
  })
  expect(response.status).toBe(400)
})

// Test rate limiting
test('enforces rate limits', async () => {
  const requests = Array(101).fill(null).map(() =>
    fetch('/api/endpoint')
  )

  const responses = await Promise.all(requests)
  const tooManyRequests = responses.filter(r => r.status === 429)

  expect(tooManyRequests.length).toBeGreaterThan(0)
})
```

---

## Security Testing Checklist

Run before every release:

```markdown
## Security Checklist

### Secrets & Environment
- [ ] No secrets in code (run detect-secrets)
- [ ] .env files in .gitignore
- [ ] .env.example exists with all required vars
- [ ] Environment validated at startup

### Dependencies
- [ ] npm audit / safety check passes
- [ ] No known vulnerabilities in dependencies
- [ ] Dependencies up to date (Dependabot enabled)

### Input Validation
- [ ] All API inputs validated with schema (Zod/Pydantic)
- [ ] File uploads restricted by type and size
- [ ] Path traversal prevented

### Authentication
- [ ] Passwords hashed with bcrypt (12+ rounds)
- [ ] JWTs use short expiration
- [ ] Tokens stored in httpOnly cookies (not localStorage)
- [ ] Rate limiting on auth endpoints
- [ ] Session tokens rotated on login

### Authorization
- [ ] Authorization checks before sensitive operations
- [ ] Role-based access control implemented
- [ ] Row Level Security enabled in Supabase

### Database
- [ ] Parameterized queries only
- [ ] Least privilege database user
- [ ] Connection strings not logged

### Headers & CORS
- [ ] Security headers enabled (helmet)
- [ ] CSRF protection on state-changing operations
- [ ] CORS restricted to known origins
- [ ] HTTPS only in production

### Logging
- [ ] No secrets in logs
- [ ] No PII in logs (or properly masked)
- [ ] Failed auth attempts logged
```

---

## Pre-Deployment Security Checklist

Before ANY production deployment:

- [ ] **Secrets**: No hardcoded secrets, all in env vars
- [ ] **Input Validation**: All user inputs validated
- [ ] **SQL Injection**: All queries parameterized
- [ ] **XSS**: User content sanitized
- [ ] **CSRF**: Protection enabled
- [ ] **Authentication**: Proper token handling
- [ ] **Authorization**: Role checks in place
- [ ] **Rate Limiting**: Enabled on all endpoints
- [ ] **HTTPS**: Enforced in production
- [ ] **Security Headers**: CSP, X-Frame-Options configured
- [ ] **Error Handling**: No sensitive data in errors
- [ ] **Logging**: No sensitive data logged
- [ ] **Dependencies**: Up to date, no vulnerabilities
- [ ] **Row Level Security**: Enabled in Supabase
- [ ] **CORS**: Properly configured
- [ ] **File Uploads**: Validated (size, type)
- [ ] **Wallet Signatures**: Verified (if blockchain)

---

## Security Anti-Patterns

- ❌ Secrets in `VITE_*`, `NEXT_PUBLIC_*`, or `REACT_APP_*` env vars (client-exposed!)
- ❌ Secrets in code or config files committed to git
- ❌ .env files without .gitignore entry
- ❌ String concatenation for SQL queries
- ❌ `dangerouslySetInnerHTML` without sanitization
- ❌ `eval()` or `new Function()` with user input
- ❌ Passwords stored as plain text or weak hash (MD5, SHA1)
- ❌ JWTs with no expiration or very long expiration
- ❌ Tokens stored in localStorage
- ❌ No rate limiting on authentication endpoints
- ❌ Logging sensitive data (passwords, tokens, PII)
- ❌ Using `*` for CORS origins in production
- ❌ Ignoring npm audit / safety check warnings
- ❌ Running as root / admin in production
- ❌ Hardcoded credentials for any environment
- ❌ Disabling SSL/TLS verification

---

## Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Next.js Security](https://nextjs.org/docs/security)
- [Supabase Security](https://supabase.com/docs/guides/auth)
- [Web Security Academy](https://portswigger.net/web-security)

---

**Remember**: Security is not optional. One vulnerability can compromise the entire platform. When in doubt, err on the side of caution.

