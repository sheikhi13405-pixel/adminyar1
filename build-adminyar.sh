#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════
#  بسته‌ساز ادمین‌یار — همه فایل‌های پروژه + بررسی + ساخت ZIP
#  اجرا:  bash build-adminyar.sh
# ════════════════════════════════════════════════════════════
set -e
mkdir -p adminyar/public
cd adminyar

echo "── ۱/۳ ساخت فایل‌ها ──"

cat > package.json <<'AY_PKG_EOF'
{
  "name": "adminyar",
  "version": "1.0.0",
  "private": true,
  "main": "server.js",
  "scripts": { "start": "node server.js", "dev": "node --watch server.js" },
  "engines": { "node": ">=18" },
  "dependencies": {
    "bcryptjs": "^2.4.3",
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "jsonwebtoken": "^9.0.2",
    "multer": "^1.4.5-lts.1",
    "pg": "^8.12.0"
  }
}
AY_PKG_EOF

cat > .env.example <<'AY_ENV_EOF'
DATABASE_URL=postgres://postgres:postgres@localhost:5432/adminyar
JWT_SECRET=change-me-to-a-long-random-string
PORT=4000
ADMIN_EMAIL=admin@adminyar.ir
ADMIN_PASSWORD=Admin12345
MAX_UPLOAD_CEILING_MB=2048

# درگاه زرین‌پال (اختیاری؛ خالی = فقط پرداخت دستی)
ZARINPAL_MERCHANT_ID=
ZARINPAL_SANDBOX=true
PAYMENT_CALLBACK_URL=http://localhost:4000/api/payments/verify
AY_ENV_EOF

cat > .gitignore <<'AY_GIT_EOF'
node_modules
.env
uploads
AY_GIT_EOF

cat > docker-compose.yml <<'AY_DC_EOF'
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: adminyar
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports: ["5432:5432"]
    volumes: [pgdata:/var/lib/postgresql/data]
volumes:
  pgdata:
AY_DC_EOF

cat > README.md <<'AY_RM_EOF'
# ادمین‌یار (AdminYar) — MVP مدیریت هوشمند پیج اینستاگرام

سیستم اشتراکی ثبت سفارش تولید محتوا: مشتری پیج ثبت می‌کند، فایل خام آپلود
می‌کند و سفارش می‌دهد؛ تیم شما (مدیر/ادمین محتوا/تدوینگر/طراح) سفارش را
دریافت، انجام، تحویل، تأیید و زمان‌بندی می‌کند. پشتیبانی کامل RTL و تقویم شمسی.

## پیش‌نیازها
- Node.js نسخه ۱۸ یا بالاتر
- PostgreSQL (محلی یا Docker)
- اتصال اینترنت در مرورگر (CDN رسمی React/Tailwind/فونت وزیرمتن)

## نصب و اجرا (۴ قدم)
1) دیتابیس:
     docker compose up -d
   یا PostgreSQL محلی و ساخت دیتابیس adminyar
2) تنظیمات (اختیاری):
     copy .env.example .env        (ویندوز)
     cp .env.example .env          (لینوکس/مک)
3) نصب وابستگی‌ها:
     npm install
4) اجرا:
     npm start                     → http://localhost:4000

نکته: جداول دیتابیس، Seed پلن‌ها و حساب مدیر به‌صورت خودکار در اولین اجرا ساخته می‌شوند (Migration داخلی و idempotent).

## حساب‌های پیش‌فرض
- مدیر کل:  admin@adminyar.ir  /  Admin12345   (با .env قابل تغییر — حتماً عوض کنید)
- مشتری:     از صفحه «ثبت‌نام» → اشتراک آزمایشی ۳ روزه خودکار فعال می‌شود
- کارشناسان: مدیر از مسیر «تیم و کارشناسان» می‌سازد (تدوینگر/طراح/ادمین محتوا/پشتیبانی)

## قابلیت‌های این نسخه
- ثبت‌نام/ورود JWT + نقش‌محور (RBAC) + مسدودسازی حساب
- سه پلن (آزمایشی/عادی/حرفه‌ای) — قیمت، مدت و سقف‌ها از پنل مدیریت قابل ویرایش
- پیج‌ها با سقف پلن، آپلود چندفایلی با درصد پیشرفت، اعتبارسنجی MIME و حجم
- چرخه کامل سفارش: ثبت → تخصیص کارشناس → انجام → تحویل خروجی → تأیید/اصلاح → زمان‌بندی → انتشار → تکمیل
- تقویم شمسی ماهانه با جابه‌جایی تاریخ/ساعت + اعلام انتشار دستی + ثبت انتشار
- پرداخت: زرین‌پال واقعی (با کلید) + جریان «درخواست پرداخت دستی → تأیید ادمین»
- اعلان‌ها، گزارش داشبورد، لاگ فعالیت‌ها، تنظیمات فضای ذخیره‌سازی

## فعال‌سازی پرداخت آنلاین (زرین‌پال)
در .env مقداردهی کنید:
  ZARINPAL_MERCHANT_ID=xxxx-xxxx-...
  ZARINPAL_SANDBOX=true          (برای تولید false)
  PAYMENT_CALLBACK_URL=https://your-domain/api/payments/verify
سپس دکمه «پرداخت آنلاین» در صفحه اشتراک ظاهر می‌شود. بدون کلید، فقط «پرداخت دستی» فعال است.

## ساختار پروژه
  server.js            بک‌اند کامل (Express + PostgreSQL + آپلود + پرداخت + RBAC + Schema خودکار)
  public/index.html    فرانت‌اند کامل (React + Tailwind، RTL، تقویم جلالی جاسازی‌شده)

## امنیت پیاده‌شده
JWT با انقضا + bcrypt، RBAC روی هر اندپوینت، Rate-limit احراز هویت،
whitelist واقعی MIME، سقف حجم سه‌سطحی (سرور/تنظیمات/پلن)، نام فایل تصادفی،
ذخیره خارج از webroot، مالکیت‌سنجی دانلود فایل‌ها، جلوگیری از Path Traversal،
لاگ فعالیت، بلاک کاربر، هدرهای امنیتی.

## استقرار تولید
- npm install && npm start  (پیشنهاد: pm2 start server.js -n adminyar)
- پشت Nginx با TLS؛ client_max_body_size متناسب با MAX_UPLOAD_CEILING_MB
- در .env حتماً: JWT_SECRET تصادفی طولانی + ADMIN_PASSWORD جدید + ZARINPAL_*
- بکاپ شبانه:
    pg_dump adminyar | gzip > backup-$(date +%F).sql.gz
  + همگام‌سازی پوشه uploads/ به فضای دیگر

## فازهای بعدی
- فاز ۲: ذخیره‌سازی ابری S3 (S3_ENDPOINT, S3_BUCKET, S3_ACCESS_KEY, S3_SECRET_KEY)، OTP پیامکی (KAVENEGAR_API_KEY)، تیکت پشتیبانی، نمای هفتگی/روزانه تقویم
- فاز ۳: اینستاگرام رسمی Meta (META_APP_ID, META_APP_SECRET, IG_REDIRECT_URI)، هوش مصنوعی (OPENAI_API_KEY)
- فاز ۴: تحلیل عملکرد پیج، گزارش پیشرفته، فاکتور، درگاه‌های بیشتر
AY_RM_EOF

cat > server.js <<'AY_SRV_EOF'
'use strict';
/* ════════════════════════════════════════════════════════════
   ادمین‌یار — سرور یک‌فایلی MVP
   Node 18+ / Express / PostgreSQL / JWT / Multer / زرین‌پال
   ════════════════════════════════════════════════════════════ */
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const dotenv = require('dotenv');
dotenv.config();

const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const multer = require('multer');
const { Pool } = require('pg');

/* ── پیکربندی (با پیش‌فرض امن برای اجرای فوری) ─────────────── */
const env = {
  port: +process.env.PORT || 4000,
  databaseUrl: process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/adminyar',
  jwtSecret: process.env.JWT_SECRET || crypto.randomBytes(32).toString('hex'),
  jwtExpires: process.env.JWT_EXPIRES || '7d',
  clientUrl: (process.env.CLIENT_URL || '').replace(/\/+$/, ''),
  uploadDir: process.env.UPLOAD_DIR ? path.resolve(process.env.UPLOAD_DIR) : path.join(__dirname, 'uploads'),
  publicDir: path.join(__dirname, 'public'),
  adminEmail: process.env.ADMIN_EMAIL || 'admin@adminyar.ir',
  adminPassword: process.env.ADMIN_PASSWORD || 'Admin12345',
  ceilingMB: +process.env.MAX_UPLOAD_CEILING_MB || 2048,
  zp: {
    merchant: process.env.ZARINPAL_MERCHANT_ID || '',
    sandbox: process.env.ZARINPAL_SANDBOX !== 'false',
    callback: process.env.PAYMENT_CALLBACK_URL || ''
  }
};
if (!process.env.JWT_SECRET) console.warn('⚠ JWT_SECRET در .env تنظیم نشده؛ کلید موقت ساخته شد (بعد از ری‌استارت، نشست‌ها باطل می‌شوند).');

const pool = new Pool({ connectionString: env.databaseUrl, max: 10 });
pool.on('error', (e) => console.error('PG error:', e.message));

const ah = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

/* ── ثابت‌ها ──────────────────────────────────────────────── */
const ORDER_STATUS_LIST = ['pending','rejected','assigned','in_progress','delivered','revision_requested','approved','scheduled','completed','canceled'];
const ADMIN_ROLES = ['super_admin','content_admin','support'];
const EXPERT_ROLES = ['content_admin','editor','designer','support'];
const CONTENT_KINDS = ['story','post','reel','raw_video'];

/* ── Schema + Seed (idempotent — در هر بوت امن است) ────────── */
const SCHEMA = `
DO $$ BEGIN CREATE TYPE public.user_role    AS ENUM ('customer','super_admin','content_admin','editor','designer','support'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.order_status AS ENUM (${ORDER_STATUS_LIST.map(s=>`'${s}'`).join(',')}); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.sub_status   AS ENUM ('active','expired','unpaid','canceled'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.pay_status   AS ENUM ('pending','paid','failed'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.file_kind    AS ENUM ('story','post','reel','raw_video','deliverable'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.sched_status AS ENUM ('scheduled','manual_ready','published','failed'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name TEXT NOT NULL, email TEXT UNIQUE NOT NULL, password_hash TEXT NOT NULL,
  role user_role NOT NULL DEFAULT 'customer', specialty TEXT,
  is_blocked BOOLEAN NOT NULL DEFAULT FALSE, created_at TIMESTAMPTZ NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code TEXT UNIQUE NOT NULL, title TEXT NOT NULL,
  price_toman INTEGER NOT NULL DEFAULT 0, duration_days INT NOT NULL,
  max_pages INT NOT NULL DEFAULT 1, max_orders_per_period INT NOT NULL DEFAULT 10,
  max_file_size_mb INT NOT NULL DEFAULT 200, features JSONB NOT NULL DEFAULT '[]',
  is_active BOOLEAN NOT NULL DEFAULT TRUE, sort INT NOT NULL DEFAULT 0);

CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_id UUID NOT NULL REFERENCES plans(id),
  starts_at TIMESTAMPTZ NOT NULL, expires_at TIMESTAMPTZ NOT NULL,
  status sub_status NOT NULL DEFAULT 'active', created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS idx_subs_user ON subscriptions(user_id);

CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_id UUID NOT NULL REFERENCES plans(id),
  amount INTEGER NOT NULL, authority TEXT, method TEXT NOT NULL DEFAULT 'gateway',
  status pay_status NOT NULL DEFAULT 'pending', ref_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), paid_at TIMESTAMPTZ);

CREATE TABLE IF NOT EXISTS ig_pages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  username TEXT NOT NULL, title TEXT, category TEXT NOT NULL DEFAULT 'سایر',
  status TEXT NOT NULL DEFAULT 'active', created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, username));

CREATE TABLE IF NOT EXISTS files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  page_id UUID REFERENCES ig_pages(id) ON DELETE SET NULL,
  order_id UUID, kind file_kind NOT NULL,
  original_name TEXT NOT NULL, mime TEXT NOT NULL, size BIGINT NOT NULL,
  disk_path TEXT NOT NULL, description TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS idx_files_user ON files(user_id);

CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  page_id UUID REFERENCES ig_pages(id) ON DELETE SET NULL,
  type TEXT NOT NULL, title TEXT NOT NULL, description TEXT,
  status order_status NOT NULL DEFAULT 'pending',
  assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
  deliverable_file_id UUID REFERENCES files(id) ON DELETE SET NULL,
  revision_note TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
DO $$ BEGIN ALTER TABLE files ADD CONSTRAINT files_order_fk FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL; EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS order_files (
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  file_id UUID NOT NULL REFERENCES files(id) ON DELETE CASCADE,
  PRIMARY KEY (order_id, file_id));

CREATE TABLE IF NOT EXISTS order_logs (
  id BIGSERIAL PRIMARY KEY, order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action TEXT NOT NULL, note TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS scheduled_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  page_id UUID REFERENCES ig_pages(id) ON DELETE SET NULL,
  order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  media_file_id UUID REFERENCES files(id) ON DELETE SET NULL,
  type TEXT NOT NULL DEFAULT 'post', caption TEXT, publish_at TIMESTAMPTZ NOT NULL,
  status sched_status NOT NULL DEFAULT 'scheduled', note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS idx_sched_publish ON scheduled_posts(publish_at);

CREATE TABLE IF NOT EXISTS notifications (
  id BIGSERIAL PRIMARY KEY, user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL, body TEXT, read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS idx_notif_user ON notifications(user_id);

CREATE TABLE IF NOT EXISTS activity_logs (
  id BIGSERIAL PRIMARY KEY, user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action TEXT NOT NULL, entity TEXT, entity_id UUID, meta JSONB, ip TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value JSONB NOT NULL);
`;

async function ensureSchema() {
  await pool.query(SCHEMA);
  await pool.query(`INSERT INTO plans (code,title,price_toman,duration_days,max_pages,max_orders_per_period,max_file_size_mb,features,sort) VALUES
    ('trial','اشتراک آزمایشی',0,3,1,3,100,'["ثبت یک پیج","آپلود عکس و فیلم خام","مشاهده تقویم محتوایی","ثبت تا ۳ سفارش"]',0),
    ('standard','اشتراک عادی',990000,30,1,20,500,'["مدیریت یک پیج","آپلود استوری، پست، ریلز و فیلم خام","تقویم محتوایی شمسی","سفارش تدوین و طراحی","درخواست کپشن و هشتگ","زمان‌بندی انتشار"]',1),
    ('pro','اشتراک حرفه‌ای',2490000,30,5,999,1024,'["مدیریت تا ۵ پیج","تمام امکانات پلن عادی","سفارش نامحدود","اولویت انجام سفارش","پشتیبانی اختصاصی"]',2)
    ON CONFLICT (code) DO NOTHING`);
  await pool.query(`INSERT INTO settings (key,value) VALUES
    ('storage.max_file_size_mb','200'),
    ('storage.allowed_mime','["image/jpeg","image/png","image/webp","image/gif","video/mp4","video/quicktime","video/webm","video/x-matroska"]')
    ON CONFLICT (key) DO NOTHING`);
  const a = await pool.query('SELECT 1 FROM users WHERE email=$1', [env.adminEmail]);
  if (!a.rowCount) {
    await pool.query(`INSERT INTO users(full_name,email,password_hash,role) VALUES('مدیر مجموعه',$1,$2,'super_admin')`,
      [env.adminEmail, await bcrypt.hash(env.adminPassword, 10)]);
    console.log(`✔ ابرمدیر ساخته شد → ${env.adminEmail} / ${env.adminPassword}`);
  }
}

/* ── ابزارها ──────────────────────────────────────────────── */
const sign = (u) => jwt.sign({ id: u.id, role: u.role }, env.jwtSecret, { expiresIn: env.jwtExpires });

async function logActivity({ userId = null, action, entity = null, entityId = null, meta = null, ip = null }) {
  try {
    await pool.query('INSERT INTO activity_logs(user_id,action,entity,entity_id,meta,ip) VALUES($1,$2,$3,$4,$5,$6)',
      [userId, action, entity, entityId, meta ? JSON.stringify(meta) : null, ip]);
  } catch (e) { console.error('log:', e.message); }
}
async function notify(userId, title, body = null) {
  await pool.query('INSERT INTO notifications(user_id,title,body) VALUES($1,$2,$3)', [userId, title, body]);
}
async function notifyRoles(roles, title, body = null) {
  const r = await pool.query('SELECT id FROM users WHERE role = ANY($1) AND is_blocked=false', [roles]);
  for (const u of r.rows) await notify(u.id, title, body);
}
async function olog(orderId, actorId, action, note = null) {
  await pool.query('INSERT INTO order_logs(order_id,actor_id,action,note) VALUES($1,$2,$3,$4)', [orderId, actorId, action, note]);
}

let sCache = { at: 0, data: {} };
async function getSettings() {
  if (Date.now() - sCache.at < 30000) return sCache.data;
  const r = await pool.query('SELECT key,value FROM settings');
  sCache = { at: Date.now(), data: Object.fromEntries(r.rows.map((x) => [x.key, x.value])) };
  return sCache.data;
}

async function getSubscription(userId) {
  const r = await pool.query(
    `SELECT s.id,s.status,s.starts_at,s.expires_at,s.created_at,
            p.id plan_id,p.code plan_code,p.title plan_title,p.duration_days,p.price_toman,
            p.max_pages,p.max_orders_per_period,p.max_file_size_mb,p.features
       FROM subscriptions s JOIN plans p ON p.id=s.plan_id
      WHERE s.user_id=$1 ORDER BY s.created_at DESC LIMIT 1`, [userId]);
  if (!r.rowCount) return null;
  const s = r.rows[0];
  if (s.status === 'active' && new Date(s.expires_at) <= new Date()) {
    await pool.query(`UPDATE subscriptions SET status='expired' WHERE id=$1`, [s.id]);
    s.status = 'expired';
  }
  s.is_active = s.status === 'active';
  return s;
}

async function activateSubscription(userId, plan) {
  const cur = await pool.query(
    `SELECT expires_at FROM subscriptions WHERE user_id=$1 AND status='active' ORDER BY expires_at DESC LIMIT 1`, [userId]);
  const base = cur.rowCount && new Date(cur.rows[0].expires_at) > new Date() ? new Date(cur.rows[0].expires_at) : new Date();
  const expires = new Date(base.getTime() + plan.duration_days * 86400000);
  await pool.query(`INSERT INTO subscriptions(user_id,plan_id,starts_at,expires_at,status) VALUES($1,$2,$3,$4,'active')`,
    [userId, plan.id, base, expires]);
}

/* ── ذخیره‌سازی فایل ─────────────────────────────────────── */
function targetDir() {
  const d = new Date();
  const dir = path.join(env.uploadDir, String(d.getFullYear()), String(d.getMonth() + 1).padStart(2, '0'));
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}
function safeJoin(base, rel) {
  const p = path.resolve(base, rel);
  if (!p.startsWith(path.resolve(base))) throw new Error('مسیر نامعتبر');
  return p;
}
const upload = multer({
  storage: multer.diskStorage({
    destination: (_q, _f, cb) => { try { cb(null, targetDir()); } catch (e) { cb(e); } },
    filename: (_q, file, cb) => cb(null, Date.now() + '-' + crypto.randomBytes(6).toString('hex') + (path.extname(file.originalname) || '').toLowerCase().slice(0, 10))
  }),
  limits: { files: 1, fileSize: env.ceilingMB * 1024 * 1024 },
  fileFilter: async (_q, file, cb) => {
    try { const s = await getSettings(); cb(null, (s['storage.allowed_mime'] || []).includes(file.mimetype)); }
    catch (e) { cb(e); }
  }
});

/* ── زرین‌پال (واقعی — v4) ───────────────────────────────── */
const zpHost = env.zp.sandbox ? 'https://sandbox.zarinpal.com' : 'https://payment.zarinpal.com';
async function zpRequest({ amount, description, callbackUrl, email }) {
  const res = await fetch(`${zpHost}/pg/v4/payment/request.json`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ merchant_id: env.zp.merchant, amount, callback_url: callbackUrl, description, metadata: { email } })
  });
  const d = await res.json();
  if (!d?.data || d.data.code !== 100) throw Object.assign(new Error('خطا در اتصال به درگاه پرداخت'), { status: 502 });
  return { authority: d.data.authority, redirectUrl: `${zpHost}/pg/StartPay/${d.data.authority}` };
}
async function zpVerify({ amount, authority }) {
  const res = await fetch(`${zpHost}/pg/v4/payment/verify.json`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ merchant_id: env.zp.merchant, amount, authority })
  });
  const d = await res.json();
  return d?.data && [100, 101].includes(d.data.code) ? d.data : null; // 101 = قبلاً تأییدشده
}

/* ── Middleware ها ────────────────────────────────────────── */
async function authRequired(req, res, next) {
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!token) return res.status(401).json({ message: 'ابتدا وارد شوید' });
  try {
    const p = jwt.verify(token, env.jwtSecret);
    const u = await pool.query('SELECT id,full_name,email,role,specialty,is_blocked FROM users WHERE id=$1', [p.id]);
    if (!u.rowCount || u.rows[0].is_blocked) return res.status(401).json({ message: 'حساب مسدود یا نامعتبر است' });
    req.user = u.rows[0]; next();
  } catch { return res.status(401).json({ message: 'نشست نامعتبر است' }); }
}
const requireRoles = (...roles) => (req, res, next) =>
  roles.includes(req.user.role) ? next() : res.status(403).json({ message: 'دسترسی غیرمجاز' });

/* Rate-limit سبک برای احراز هویت */
const attempts = new Map();
function authLimiter(req, res, next) {
  const now = Date.now();
  const arr = (attempts.get(req.ip) || []).filter((t) => now - t < 15 * 60000);
  if (arr.length >= 40) return res.status(429).json({ message: 'تلاش‌های زیاد؛ ۱۵ دقیقه بعد امتحان کنید' });
  attempts.set(req.ip, [...arr, now]);
  next();
}

/* ── اپلیکیشن ─────────────────────────────────────────────── */
const app = express();
app.set('trust proxy', 1);
app.use((_, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'same-origin');
  next();
});
app.use(cors());
app.use(express.json({ limit: '1mb' }));

/* ═══ ۱) احراز هویت ═══════════════════════════════════════ */
app.post('/api/auth/register', authLimiter, ah(async (req, res) => {
  const { fullName, email, password } = req.body || {};
  if (!fullName || fullName.trim().length < 3) return res.status(400).json({ message: 'نام و نام خانوادگی را کامل وارد کنید' });
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email || '')) return res.status(400).json({ message: 'ایمیل معتبر نیست' });
  if (!password || password.length < 8) return res.status(400).json({ message: 'رمز عبور باید حداقل ۸ کاراکتر باشد' });
  let u;
  try {
    u = await pool.query(`INSERT INTO users(full_name,email,password_hash) VALUES($1,$2,$3) RETURNING id,full_name,email,role`,
      [fullName.trim(), email.toLowerCase().trim(), await bcrypt.hash(password, 10)]);
  } catch (e) {
    if (e.code === '23505') return res.status(409).json({ message: 'این ایمیل قبلاً ثبت شده است' });
    throw e;
  }
  const user = u.rows[0];
  const plan = await pool.query(`SELECT * FROM plans WHERE code='trial' AND is_active LIMIT 1`);
  if (plan.rowCount) {
    const days = plan.rows[0].duration_days;
    await pool.query(`INSERT INTO subscriptions(user_id,plan_id,starts_at,expires_at,status) VALUES($1,$2,now(),$3,'active')`,
      [user.id, plan.rows[0].id, new Date(Date.now() + days * 86400000)]);
  }
  await notify(user.id, 'خوش آمدید 👋', 'اشتراک آزمایشی ۳ روزه فعال شد. اولین پیج خود را ثبت کنید.');
  await logActivity({ userId: user.id, action: 'register', ip: req.ip });
  res.status(201).json({ token: sign(user), user });
}));

app.post('/api/auth/login', authLimiter, ah(async (req, res) => {
  const { email, password } = req.body || {};
  const r = await pool.query('SELECT * FROM users WHERE email=$1', [(email || '').toLowerCase().trim()]);
  if (!r.rowCount || !(await bcrypt.compare(password || '', r.rows[0].password_hash)))
    return res.status(401).json({ message: 'ایمیل یا رمز عبور اشتباه است' });
  const u = r.rows[0];
  if (u.is_blocked) return res.status(403).json({ message: 'حساب شما مسدود شده است' });
  await logActivity({ userId: u.id, action: 'login', ip: req.ip });
  const user = { id: u.id, full_name: u.full_name, email: u.email, role: u.role };
  res.json({ token: sign(user), user });
}));

app.get('/api/auth/me', authRequired, (req, res) => res.json(req.user));

/* ═══ ۲) تنظیمات عمومی ════════════════════════════════════ */
app.get('/api/config', (_, res) => res.json({ gatewayEnabled: !!(env.zp.merchant && env.zp.callback) }));
app.get('/api/plans', ah(async (_, res) => {
  res.json((await pool.query('SELECT * FROM plans WHERE is_active ORDER BY sort')).rows);
}));

/* ═══ ۳) پیج‌های اینستاگرام ═══════════════════════════════ */
app.get('/api/pages', authRequired, ah(async (req, res) => {
  res.json((await pool.query(
    `SELECT p.*, (SELECT count(*)::int FROM orders o WHERE o.page_id=p.id) orders_count
       FROM ig_pages p WHERE p.user_id=$1 ORDER BY p.created_at DESC`, [req.user.id])).rows);
}));
app.post('/api/pages', authRequired, ah(async (req, res) => {
  const uname = (req.body.username || '').trim().replace(/^@/, '');
  if (!/^[a-zA-Z0-9._]{2,30}$/.test(uname)) return res.status(400).json({ message: 'نام کاربری اینستاگرام معتبر نیست' });
  const sub = await getSubscription(req.user.id);
  if (!sub || !sub.is_active) return res.status(402).json({ code: 'SUBSCRIPTION_REQUIRED', message: 'اشتراک فعالی ندارید' });
  const c = await pool.query('SELECT count(*)::int c FROM ig_pages WHERE user_id=$1', [req.user.id]);
  if (c.rows[0].c >= sub.max_pages) return res.status(403).json({ code: 'PAGE_LIMIT', message: `سقف پیج پلن شما (${sub.max_pages}) تکمیل شده است` });
  const r = await pool.query('INSERT INTO ig_pages(user_id,username,title,category) VALUES($1,$2,$3,$4) RETURNING *',
    [req.user.id, uname, req.body.title || uname, req.body.category || 'سایر']);
  await logActivity({ userId: req.user.id, action: 'page_create', entity: 'ig_page', entityId: r.rows[0].id, ip: req.ip });
  res.status(201).json(r.rows[0]);
}));
app.delete('/api/pages/:id', authRequired, ah(async (req, res) => {
  const own = await pool.query('SELECT id FROM ig_pages WHERE id=$1 AND user_id=$2', [req.params.id, req.user.id]);
  if (!own.rowCount) return res.status(404).json({ message: 'پیج یافت نشد' });
  const oc = await pool.query('SELECT count(*)::int c FROM orders WHERE page_id=$1', [req.params.id]);
  if (oc.rows[0].c > 0) return res.status(409).json({ message: 'این پیج سفارش دارد و قابل حذف نیست' });
  await pool.query('DELETE FROM ig_pages WHERE id=$1', [req.params.id]);
  res.json({ ok: true });
}));

/* ═══ ۴) آپلود / دانلود فایل ═════════════════════════════ */
app.post('/api/uploads', authRequired, upload.single('file'), ah(async (req, res) => {
  if (!req.file) return res.status(400).json({ message: 'فایلی ارسال نشد یا نوع فایل مجاز نیست' });
  const { kind, pageId, description, orderId } = req.body;
  const fail = async (msg, code = 400) => { try { fs.unlinkSync(req.file.path); } catch {} res.status(code).json({ message: msg }); };

  if (!['story','post','reel','raw_video','deliverable'].includes(kind)) return await fail('نوع فایل نامعتبر است');

  if (kind === 'deliverable') {
    if (!['editor','designer','content_admin','super_admin'].includes(req.user.role) || !orderId)
      return await fail('اجازه این عملیات را ندارید', 403);
    const o = await pool.query('SELECT assigned_to FROM orders WHERE id=$1', [orderId]);
    if (!o.rowCount) return await fail('سفارش یافت نشد', 404);
    if (!['content_admin','super_admin'].includes(req.user.role) && o.rows[0].assigned_to !== req.user.id)
      return await fail('این سفارش به شما اختصاص نیافته است', 403);
  } else {
    if (req.user.role !== 'customer') return await fail('فقط مشتریان می‌توانند محتوا آپلود کنند', 403);
    const sub = await getSubscription(req.user.id);
    if (!sub || !sub.is_active) return await fail('اشتراک فعالی ندارید', 402);
    const s = await getSettings();
    const g = Number(s['storage.max_file_size_mb'] || 0);
    const limitMb = g > 0 ? Math.min(sub.max_file_size_mb, g) : sub.max_file_size_mb;
    if (req.file.size > limitMb * 1048576) return await fail(`حجم فایل بیشتر از سقف مجاز (${limitMb} مگابایت) است`, 413);
    if (pageId) {
      const p = await pool.query('SELECT id FROM ig_pages WHERE id=$1 AND user_id=$2', [pageId, req.user.id]);
      if (!p.rowCount) return await fail('پیج نامعتبر است');
    }
  }
  const rel = path.relative(env.uploadDir, req.file.path);
  const r = await pool.query(
    `INSERT INTO files(user_id,page_id,order_id,kind,original_name,mime,size,disk_path,description)
     VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
    [req.user.id, kind === 'deliverable' ? null : (pageId || null), kind === 'deliverable' ? orderId : null,
     kind, req.file.originalname, req.file.mimetype, req.file.size, rel, description || null]);
  await logActivity({ userId: req.user.id, action: 'upload', entity: 'file', entityId: r.rows[0].id, meta: { kind, size: req.file.size }, ip: req.ip });
  res.status(201).json(r.rows[0]);
}));

app.get('/api/uploads', authRequired, ah(async (req, res) => {
  const kinds = (req.query.kinds || '').split(',').filter((k) => CONTENT_KINDS.includes(k));
  const r = await pool.query(
    `SELECT id,kind,original_name,mime,size,description,created_at FROM files
      WHERE user_id=$1 AND kind <> 'deliverable'
      ${kinds.length ? 'AND kind = ANY($2::file_kind[])' : ''}
      ORDER BY created_at DESC LIMIT 100`,
    kinds.length ? [req.user.id, kinds] : [req.user.id]);
  res.json(r.rows);
}));

app.get('/api/uploads/:id/download', authRequired, ah(async (req, res, next) => {
  const f = await pool.query('SELECT * FROM files WHERE id=$1', [req.params.id]);
  if (!f.rowCount) return res.status(404).json({ message: 'فایل یافت نشد' });
  const file = f.rows[0];
  let ok = file.user_id === req.user.id || ADMIN_ROLES.includes(req.user.role);
  if (!ok) {
    const a = await pool.query(
      `SELECT 1 FROM orders o
        WHERE (o.user_id=$1 OR o.assigned_to=$1)
          AND (o.id=$2 OR EXISTS(SELECT 1 FROM order_files of WHERE of.order_id=o.id AND of.file_id=$3)) LIMIT 1`,
      [req.user.id, file.order_id, file.id]);
    ok = !!a.rowCount;
  }
  if (!ok) return res.status(403).json({ message: 'دسترسی به این فایل را ندارید' });
  res.setHeader('Content-Type', file.mime || 'application/octet-stream');
  res.setHeader('Content-Disposition', `attachment; filename*=UTF-8''${encodeURIComponent(file.original_name)}`);
  res.sendFile(safeJoin(env.uploadDir, file.disk_path), (err) => err && next(err));
}));

/* ═══ ۵) سفارش‌ها ═════════════════════════════════════════ */
async function mustOrder(id) { const r = await pool.query('SELECT * FROM orders WHERE id=$1', [id]); return r.rowCount ? r.rows[0] : null; }
async function setOrderStatus(id, status, extra = {}) {
  const sets = ['status=$2', 'updated_at=now()']; const params = [id, status];
  if (extra.deliverableFileId) { params.push(extra.deliverableFileId); sets.push(`deliverable_file_id=$${params.length}`); }
  if (extra.revisionNote) { params.push(extra.revisionNote); sets.push(`revision_note=$${params.length}`); }
  await pool.query(`UPDATE orders SET ${sets.join(', ')} WHERE id=$1`, params);
}

app.post('/api/orders', authRequired, ah(async (req, res) => {
  const { pageId, type, title, description, fileIds } = req.body || {};
  if (!pageId || !type || !title) return res.status(400).json({ message: 'فیلدهای الزامی را کامل کنید' });
  const sub = await getSubscription(req.user.id);
  if (!sub || !sub.is_active) return res.status(402).json({ code: 'SUBSCRIPTION_REQUIRED', message: 'اشتراک فعالی ندارید' });
  const pg = await pool.query('SELECT id FROM ig_pages WHERE id=$1 AND user_id=$2', [pageId, req.user.id]);
  if (!pg.rowCount) return res.status(404).json({ message: 'پیج یافت نشد' });
  const cnt = await pool.query('SELECT count(*)::int c FROM orders WHERE user_id=$1 AND created_at >= $2', [req.user.id, sub.starts_at]);
  if (cnt.rows[0].c >= sub.max_orders_per_period)
    return res.status(403).json({ code: 'ORDER_LIMIT', message: 'سقف سفارش پلن شما در این دوره تکمیل شده است' });
  if (!Array.isArray(fileIds) || !fileIds.length) return res.status(400).json({ message: 'حداقل یک فایل ضمیمه کنید' });
  const fr = await pool.query(`SELECT id FROM files WHERE id = ANY($1::uuid[]) AND user_id=$2 AND kind <> 'deliverable'`, [fileIds, req.user.id]);
  if (fr.rowCount !== fileIds.length) return res.status(400).json({ message: 'یک یا چند فایل نامعتبر است' });

  const o = await pool.query(`INSERT INTO orders(user_id,page_id,type,title,description) VALUES($1,$2,$3,$4,$5) RETURNING *`,
    [req.user.id, pageId, type, title, description || null]);
  for (const f of fileIds) await pool.query('INSERT INTO order_files(order_id,file_id) VALUES($1,$2)', [o.rows[0].id, f]);
  await olog(o.rows[0].id, req.user.id, 'create', 'سفارش توسط مشتری ثبت شد');
  await notifyRoles(['super_admin', 'content_admin'], 'سفارش جدید 🆕', `«${title}» توسط ${req.user.full_name}`);
  await logActivity({ userId: req.user.id, action: 'order_create', entity: 'order', entityId: o.rows[0].id, ip: req.ip });
  res.status(201).json(o.rows[0]);
}));

app.get('/api/orders', authRequired, ah(async (req, res) => {
  const params = []; let where = '1=1';
  if (req.user.role === 'customer') { params.push(req.user.id); where += ` AND o.user_id=$${params.length}`; }
  else if (['editor','designer'].includes(req.user.role)) { params.push(req.user.id); where += ` AND o.assigned_to=$${params.length}`; }
  else if (!ADMIN_ROLES.includes(req.user.role)) return res.status(403).json({ message: 'دسترسی غیرمجاز' });
  const st = ORDER_STATUS_LIST.includes(req.query.status) ? req.query.status : null;
  if (st) { params.push(st); where += ` AND o.status=$${params.length}`; }
  const r = await pool.query(
    `SELECT o.*, p.username page_username, u.full_name customer_name, e.full_name expert_name
       FROM orders o LEFT JOIN ig_pages p ON p.id=o.page_id
       LEFT JOIN users u ON u.id=o.user_id LEFT JOIN users e ON e.id=o.assigned_to
      WHERE ${where} ORDER BY o.created_at DESC LIMIT 100`, params);
  res.json(r.rows);
}));

app.get('/api/orders/:id', authRequired, ah(async (req, res) => {
  const r = await pool.query(
    `SELECT o.*, u.full_name customer_name, u.email customer_email, p.username page_username,
            e.full_name expert_name, df.original_name deliverable_name
       FROM orders o JOIN users u ON u.id=o.user_id
       LEFT JOIN ig_pages p ON p.id=o.page_id LEFT JOIN users e ON e.id=o.assigned_to
       LEFT JOIN files df ON df.id=o.deliverable_file_id WHERE o.id=$1`, [req.params.id]);
  if (!r.rowCount) return res.status(404).json({ message: 'سفارش یافت نشد' });
  const o = r.rows[0];
  const ok = o.user_id === req.user.id || o.assigned_to === req.user.id || ADMIN_ROLES.includes(req.user.role);
  if (!ok) return res.status(403).json({ message: 'دسترسی غیرمجاز' });
  const files = await pool.query(
    `SELECT f.id,f.kind,f.original_name,f.size,f.mime,f.description,f.created_at
       FROM order_files of JOIN files f ON f.id=of.file_id WHERE of.order_id=$1 ORDER BY f.created_at`, [o.id]);
  const logs = await pool.query(
    `SELECT l.action,l.note,l.created_at,u.full_name actor_name,u.role actor_role
       FROM order_logs l LEFT JOIN users u ON u.id=l.actor_id WHERE l.order_id=$1 ORDER BY l.created_at`, [o.id]);
  const post = await pool.query('SELECT * FROM scheduled_posts WHERE order_id=$1 ORDER BY created_at DESC LIMIT 1', [o.id]);
  res.json({ ...o, files: files.rows, logs: logs.rows, post: post.rows[0] || null });
}));

/* اکشن‌های مشتری */
app.post('/api/orders/:id/approve', authRequired, ah(async (req, res) => {
  const o = await mustOrder(req.params.id);
  if (!o) return res.status(404).json({ message: 'سفارش یافت نشد' });
  if (o.user_id !== req.user.id) return res.status(403).json({ message: 'دسترسی غیرمجاز' });
  if (o.status !== 'delivered') return res.status(400).json({ message: 'فقط سفارش تحویل‌شده قابل تأیید است' });
  await setOrderStatus(o.id, 'approved');
  await olog(o.id, req.user.id, 'approved', 'مشتری محتوا را تأیید کرد');
  if (o.assigned_to) await notify(o.assigned_to, 'تأیید مشتری ✅', `محتوای «${o.title}» تأیید شد`);
  res.json({ ok: true });
}));
app.post('/api/orders/:id/revision', authRequired, ah(async (req, res) => {
  const note = (req.body.note || '').trim();
  const o = await mustOrder(req.params.id);
  if (!o) return res.status(404).json({ message: 'سفارش یافت نشد' });
  if (o.user_id !== req.user.id) return res.status(403).json({ message: 'دسترسی غیرمجاز' });
  if (o.status !== 'delivered') return res.status(400).json({ message: 'درخواست اصلاح فقط روی خروجی تحویل‌شده ممکن است' });
  if (note.length < 5) return res.status(400).json({ message: 'شرح درخواست اصلاح را بنویسید' });
  await setOrderStatus(o.id, 'revision_requested', { revisionNote: note });
  await olog(o.id, req.user.id, 'revision_requested', note);
  if (o.assigned_to) await notify(o.assigned_to, 'درخواست اصلاح 🔄', `برای «${o.title}» درخواست اصلاح ثبت شد`);
  res.json({ ok: true });
}));
app.post('/api/orders/:id/cancel', authRequired, ah(async (req, res) => {
  const o = await mustOrder(req.params.id);
  if (!o) return res.status(404).json({ message: 'سفارش یافت نشد' });
  if (o.user_id !== req.user.id) return res.status(403).json({ message: 'دسترسی غیرمجاز' });
  if (o.status !== 'pending') return res.status(400).json({ message: 'فقط سفارش در انتظار بررسی قابل لغو است' });
  await setOrderStatus(o.id, 'canceled');
  await olog(o.id, req.user.id, 'canceled', 'لغو توسط مشتری');
  res.json({ ok: true });
}));
app.post('/api/orders/:id/schedule', authRequired, ah(async (req, res) => {
  const { publishAt, caption } = req.body || {};
  const o = await mustOrder(req.params.id);
  if (!o) return res.status(404).json({ message: 'سفارش یافت نشد' });
  if (o.user_id !== req.user.id) return res.status(403).json({ message: 'دسترسی غیرمجاز' });
  if (!['approved','scheduled'].includes(o.status)) return res.status(400).json({ message: 'ابتدا محتوا باید تأیید شود' });
  const d = new Date(publishAt || '');
  if (isNaN(d.getTime())) return res.status(400).json({ message: 'تاریخ انتشار نامعتبر است' });
  if (d.getTime() < Date.now() - 60000) return res.status(400).json({ message: 'زمان انتشار باید در آینده باشد' });
  const type = o.type === 'raw_to_reel' ? 'reel' : o.type === 'story_design' ? 'story' : 'post';
  const ex = await pool.query('SELECT id FROM scheduled_posts WHERE order_id=$1 LIMIT 1', [o.id]);
  if (ex.rowCount) await pool.query(`UPDATE scheduled_posts SET publish_at=$2, caption=$3, status='scheduled' WHERE id=$1`, [ex.rows[0].id, d, caption || null]);
  else await pool.query(
    `INSERT INTO scheduled_posts(user_id,page_id,order_id,media_file_id,type,caption,publish_at) VALUES($1,$2,$3,$4,$5,$6,$7)`,
    [o.user_id, o.page_id, o.id, o.deliverable_file_id, type, caption || null, d]);
  await setOrderStatus(o.id, 'scheduled');
  await olog(o.id, req.user.id, 'scheduled', 'زمان‌بندی توسط مشتری ثبت شد');
  await notifyRoles(['super_admin','content_admin'], 'زمان‌بندی جدید 📅', `سفارش «${o.title}» برای انتشار برنامه‌ریزی شد`);
  res.json({ ok: true });
}));

/* اکشن کارشناس / ادمین محتوا */
app.post('/api/orders/:id/status', authRequired, ah(async (req, res) => {
  const { status, deliverableFileId, note } = req.body || {};
  const o = await mustOrder(req.params.id);
  if (!o) return res.status(404).json({ message: 'سفارش یافت نشد' });
  const isAssigned = o.assigned_to === req.user.id && ['editor','designer'].includes(req.user.role);
  const isBoss = ['super_admin','content_admin'].includes(req.user.role);
  if (!isAssigned && !isBoss) return res.status(403).json({ message: 'این سفارش به شما اختصاص نیافته است' });
  const map = { assigned: ['in_progress'], in_progress: ['delivered'], revision_requested: ['in_progress'] };
  if (!map[o.status] || !map[o.status].includes(status)) return res.status(400).json({ message: 'تغییر وضعیت در این مرحله مجاز نیست' });
  if (status === 'delivered') {
    if (!deliverableFileId) return res.status(400).json({ message: 'فایل خروجی را ضمیمه کنید' });
    const f = await pool.query(`SELECT id FROM files WHERE id=$1 AND kind='deliverable' AND order_id=$2`, [deliverableFileId, o.id]);
    if (!f.rowCount) return res.status(400).json({ message: 'فایل خروجی نامعتبر است' });
    await setOrderStatus(o.id, status, { deliverableFileId });
    await olog(o.id, req.user.id, 'delivered', note || 'خروجی برای مشتری ارسال شد');
    await notify(o.user_id, 'خروجی آماده است 🎬', `سفارش «${o.title}» تحویل شد؛ لطفاً بررسی کنید`);
  } else {
    await setOrderStatus(o.id, status);
    await olog(o.id, req.user.id, status, note || null);
  }
  res.json({ ok: true });
}));

/* ═══ ۶) تقویم ═════════════════════════════════════════════ */
app.get('/api/calendar', authRequired, ah(async (req, res) => {
  const { from, to } = req.query;
  if (!from || !to) return res.status(400).json({ message: 'بازه زمانی (from/to) الزامی است' });
  const all = req.query.all === '1' && ADMIN_ROLES.includes(req.user.role);
  const r = await pool.query(
    `SELECT sp.*, p.username page_username, o.title order_title, u.full_name customer_name
       FROM scheduled_posts sp LEFT JOIN ig_pages p ON p.id=sp.page_id
       LEFT JOIN orders o ON o.id=sp.order_id LEFT JOIN users u ON u.id=sp.user_id
      WHERE sp.publish_at BETWEEN $1 AND $2 ${all ? '' : 'AND sp.user_id=$3'} ORDER BY sp.publish_at`,
    all ? [from, to] : [from, to, req.user.id]);
  res.json(r.rows);
}));
app.patch('/api/calendar/:id', authRequired, ah(async (req, res) => {
  const { publishAt, caption } = req.body || {};
  const p = await pool.query('SELECT * FROM scheduled_posts WHERE id=$1', [req.params.id]);
  if (!p.rowCount) return res.status(404).json({ message: 'محتوا یافت نشد' });
  const post = p.rows[0];
  if (!(post.user_id === req.user.id || ['super_admin','content_admin'].includes(req.user.role)))
    return res.status(403).json({ message: 'دسترسی غیرمجاز' });
  if (post.status === 'published') return res.status(400).json({ message: 'محتوای منتشرشده قابل ویرایش نیست' });
  if (publishAt) {
    const d = new Date(publishAt);
    if (isNaN(d.getTime())) return res.status(400).json({ message: 'تاریخ نامعتبر است' });
    await pool.query('UPDATE scheduled_posts SET publish_at=$2 WHERE id=$1', [post.id, d]);
  }
  if (caption !== undefined) await pool.query('UPDATE scheduled_posts SET caption=$2 WHERE id=$1', [post.id, caption]);
  res.json((await pool.query('SELECT * FROM scheduled_posts WHERE id=$1', [post.id])).rows[0]);
}));
app.delete('/api/calendar/:id', authRequired, ah(async (req, res) => {
  const p = await pool.query('SELECT * FROM scheduled_posts WHERE id=$1', [req.params.id]);
  if (!p.rowCount) return res.status(404).json({ message: 'محتوا یافت نشد' });
  if (p.rows[0].user_id !== req.user.id) return res.status(403).json({ message: 'دسترسی غیرمجاز' });
  if (p.rows[0].status !== 'scheduled') return res.status(400).json({ message: 'فقط محتوای زمان‌بندی‌شده قابل حذف است' });
  await pool.query('DELETE FROM scheduled_posts WHERE id=$1', [req.params.id]);
  res.json({ ok: true });
}));
app.post('/api/calendar/:id/manual-ready', authRequired, requireRoles('super_admin','content_admin'), ah(async (req, res) => {
  const p = await pool.query('SELECT * FROM scheduled_posts WHERE id=$1', [req.params.id]);
  if (!p.rowCount) return res.status(404).json({ message: 'محتوا یافت نشد' });
  if (p.rows[0].status !== 'scheduled') return res.status(400).json({ message: 'فقط آیتم زمان‌بندی‌شده قابل اعلام است' });
  await pool.query(`UPDATE scheduled_posts SET status='manual_ready' WHERE id=$1`, [req.params.id]);
  await notify(p.rows[0].user_id, 'زمان انتشار رسیده ⏰', 'لطفاً محتوای زمان‌بندی‌شده را طبق تقویم، به‌صورت دستی در اینستاگرام منتشر کنید.');
  res.json({ ok: true });
}));
app.post('/api/calendar/:id/publish', authRequired, requireRoles('super_admin','content_admin'), ah(async (req, res) => {
  const p = await pool.query('SELECT * FROM scheduled_posts WHERE id=$1', [req.params.id]);
  if (!p.rowCount) return res.status(404).json({ message: 'محتوا یافت نشد' });
  const post = p.rows[0];
  if (!['scheduled','manual_ready'].includes(post.status)) return res.status(400).json({ message: 'این آیتم قابل ثبت انتشار نیست' });
  await pool.query(`UPDATE scheduled_posts SET status='published' WHERE id=$1`, [post.id]);
  if (post.order_id) {
    await pool.query(`UPDATE orders SET status='completed', updated_at=now() WHERE id=$1`, [post.order_id]);
    await olog(post.order_id, req.user.id, 'completed', 'انتشار انجام و سفارش تکمیل شد');
  }
  await notify(post.user_id, 'منتشر شد 🎉', 'محتوای شما با موفقیت منتشر شد.');
  await logActivity({ userId: req.user.id, action: 'publish', entity: 'scheduled_post', entityId: post.id, ip: req.ip });
  res.json({ ok: true });
}));

/* ═══ ۷) اشتراک و پرداخت ═════════════════════════════════ */
app.get('/api/subscriptions/me', authRequired, ah(async (req, res) => {
  const r = await pool.query(
    `SELECT s.id,s.status,s.starts_at,s.expires_at,s.created_at,
            p.id plan_id,p.code plan_code,p.title plan_title,p.duration_days,p.price_toman,
            p.max_pages,p.max_orders_per_period,p.max_file_size_mb,p.features
       FROM subscriptions s JOIN plans p ON p.id=s.plan_id
      WHERE s.user_id=$1 ORDER BY s.created_at DESC`, [req.user.id]);
  const rows = r.rows;
  let current = rows.find((x) => x.status === 'active') || null;
  if (current && new Date(current.expires_at) <= new Date()) {
    await pool.query(`UPDATE subscriptions SET status='expired' WHERE id=$1`, [current.id]);
    current.status = 'expired';
  }
  const pays = await pool.query(
    `SELECT pa.id,pa.amount,pa.status,pa.method,pa.created_at,p.title plan_title
       FROM payments pa JOIN plans p ON p.id=pa.plan_id
      WHERE pa.user_id=$1 ORDER BY pa.created_at DESC LIMIT 10`, [req.user.id]);
  res.json({ current, history: rows, hadTrial: rows.some((x) => x.plan_code === 'trial'), payments: pays.rows });
}));

app.post('/api/subscriptions/checkout', authRequired, ah(async (req, res) => {
  const p = await pool.query('SELECT * FROM plans WHERE id=$1 AND is_active', [req.body.planId]);
  if (!p.rowCount) return res.status(404).json({ message: 'پلن یافت نشد' });
  const plan = p.rows[0];
  if (plan.code === 'trial') return res.status(400).json({ message: 'پلن آزمایشی فقط یک‌بار فعال می‌شود' });
  if (!env.zp.merchant || !env.zp.callback)
    return res.status(503).json({ message: 'درگاه آنلاین پیکربندی نشده؛ از گزینه «پرداخت دستی» استفاده کنید' });
  const pay = await pool.query(`INSERT INTO payments(user_id,plan_id,amount,method) VALUES($1,$2,$3,'gateway') RETURNING *`,
    [req.user.id, plan.id, plan.price_toman]);
  const { authority, redirectUrl } = await zpRequest({
    amount: plan.price_toman, description: `خرید اشتراک ${plan.title} — ادمین‌یار`,
    callbackUrl: env.zp.callback, email: req.user.email });
  await pool.query('UPDATE payments SET authority=$2 WHERE id=$1', [pay.rows[0].id, authority]);
  await logActivity({ userId: req.user.id, action: 'payment_request', entity: 'payment', entityId: pay.rows[0].id, ip: req.ip });
  res.json({ redirectUrl });
}));

/* جریان واقعی «پرداخت دستی»: ثبت درخواست → تأیید ادمین پس از واریز */
app.post('/api/subscriptions/request-manual', authRequired, ah(async (req, res) => {
  const p = await pool.query('SELECT * FROM plans WHERE id=$1 AND is_active', [req.body.planId]);
  if (!p.rowCount) return res.status(404).json({ message: 'پلن یافت نشد' });
  const plan = p.rows[0];
  if (plan.code === 'trial') return res.status(400).json({ message: 'پلن آزمایشی فقط یک‌بار فعال می‌شود' });
  const dup = await pool.query(`SELECT id FROM payments WHERE user_id=$1 AND status='pending' AND plan_id=$2`, [req.user.id, plan.id]);
  if (dup.rowCount) return res.status(409).json({ message: 'درخواستی در انتظار تأیید دارید' });
  const pay = await pool.query(`INSERT INTO payments(user_id,plan_id,amount,method) VALUES($1,$2,$3,'manual') RETURNING *`,
    [req.user.id, plan.id, plan.price_toman]);
  await notifyRoles(['super_admin'], 'درخواست پرداخت دستی 💳', `${req.user.full_name} برای «${plan.title}» درخواست خرید ثبت کرد`);
  res.status(201).json(pay.rows[0]);
}));

/* کال‌بک عمومی زرین‌پال */
app.get('/api/payments/verify', ah(async (req, res) => {
  const toClient = (p) => res.redirect(`${env.clientUrl}/${p}`);
  const { Authority, Status } = req.query;
  if (!Authority) return toClient('#/subscription?pay=fail');
  const p = await pool.query('SELECT * FROM payments WHERE authority=$1', [Authority]);
  if (!p.rowCount) return toClient('#/subscription?pay=fail');
  const pay = p.rows[0];
  if (Status !== 'OK') { await pool.query(`UPDATE payments SET status='failed' WHERE id=$1`, [pay.id]); return toClient('#/subscription?pay=fail'); }
  try {
    const v = await zpVerify({ amount: pay.amount, authority: Authority });
    if (!v) throw new Error('verify failed');
    await pool.query(`UPDATE payments SET status='paid', paid_at=now(), ref_id=$2 WHERE id=$1`, [pay.id, v.ref_id || null]);
    const plan = (await pool.query('SELECT * FROM plans WHERE id=$1', [pay.plan_id])).rows[0];
    await activateSubscription(pay.user_id, plan);
    await notify(pay.user_id, 'پرداخت موفق 💳', `اشتراک «${plan.title}» فعال شد.`);
    await logActivity({ userId: pay.user_id, action: 'payment_success', entity: 'payment', entityId: pay.id, meta: { ref: v.ref_id } });
    toClient('#/subscription?pay=success');
  } catch {
    await pool.query(`UPDATE payments SET status='failed' WHERE id=$1`, [pay.id]);
    toClient('#/subscription?pay=fail');
  }
}));

/* ═══ ۸) اعلان‌ها ═════════════════════════════════════════ */
app.get('/api/notifications', authRequired, ah(async (req, res) => {
  const rows = await pool.query('SELECT * FROM notifications WHERE user_id=$1 ORDER BY created_at DESC LIMIT 50', [req.user.id]);
  const u = await pool.query('SELECT count(*)::int c FROM notifications WHERE user_id=$1 AND read=false', [req.user.id]);
  res.json({ rows: rows.rows, unread: u.rows[0].c });
}));
app.post('/api/notifications/:id/read', authRequired, ah(async (req, res) => {
  await pool.query('UPDATE notifications SET read=true WHERE id=$1 AND user_id=$2', [req.params.id, req.user.id]);
  res.json({ ok: true });
}));
app.post('/api/notifications/read-all', authRequired, ah(async (req, res) => {
  await pool.query('UPDATE notifications SET read=true WHERE user_id=$1', [req.user.id]);
  res.json({ ok: true });
}));

/* ═══ ۹) پنل مدیریت ═══════════════════════════════════════ */
const admin = express.Router();
admin.use(authRequired, requireRoles('super_admin','content_admin','editor','designer','support'));

admin.get('/stats', requireRoles('super_admin','content_admin','support'), ah(async (_, res) => {
  const s = await pool.query(`
    SELECT (SELECT count(*) FROM users WHERE role='customer')::int users,
           (SELECT count(*) FROM subscriptions WHERE status='active')::int active_subs,
           (SELECT count(*) FROM orders WHERE status='pending')::int pending_orders,
           (SELECT count(*) FROM orders)::int total_orders,
           (SELECT count(*) FROM payments WHERE status='pending')::int pending_payments,
           (SELECT coalesce(sum(amount),0)::int revenue FROM payments WHERE status='paid')`);
  const recent = await pool.query(
    `SELECT o.id,o.title,o.type,o.status,o.created_at,u.full_name customer_name
       FROM orders o JOIN users u ON u.id=o.user_id ORDER BY o.created_at DESC LIMIT 8`);
  res.json({ ...s.rows[0], recent: recent.rows });
}));

admin.use('/users', requireRoles('super_admin','content_admin','support'));
admin.get('/users', ah(async (req, res) => {
  const q = `%${(req.query.q || '').trim()}%`;
  res.json((await pool.query(
    `SELECT u.id,u.full_name,u.email,u.is_blocked,u.created_at,
            (SELECT p.title FROM subscriptions s JOIN plans p ON p.id=s.plan_id WHERE s.user_id=u.id ORDER BY s.created_at DESC LIMIT 1) plan_title,
            (SELECT s.status FROM subscriptions s WHERE s.user_id=u.id ORDER BY s.created_at DESC LIMIT 1) sub_status,
            (SELECT s.expires_at FROM subscriptions s WHERE s.user_id=u.id ORDER BY s.created_at DESC LIMIT 1) expires_at,
            (SELECT count(*)::int FROM orders o WHERE o.user_id=u.id) orders_count
       FROM users u WHERE u.role='customer' AND (u.email ILIKE $1 OR u.full_name ILIKE $1)
      ORDER BY u.created_at DESC LIMIT 100`, [q])).rows);
}));
admin.post('/users/:id/block', requireRoles('super_admin','content_admin'), ah(async (req, res) => {
  await pool.query('UPDATE users SET is_blocked=$2 WHERE id=$1 AND role=$3', [req.params.id, !!req.body.blocked, 'customer']);
  await logActivity({ userId: req.user.id, action: req.body.blocked ? 'user_block' : 'user_unblock', entity: 'user', entityId: req.params.id });
  res.json({ ok: true });
}));

admin.get('/orders', ah(async (req, res) => {
  const params = []; let where = '1=1';
  if (['editor','designer'].includes(req.user.role)) { params.push(req.user.id); where += ` AND o.assigned_to=$${params.length}`; }
  const st = ORDER_STATUS_LIST.includes(req.query.status) ? req.query.status : null;
  if (st) { params.push(st); where += ` AND o.status=$${params.length}`; }
  res.json((await pool.query(
    `SELECT o.*, u.full_name customer_name, p.username page_username, e.full_name expert_name,
            (SELECT count(*)::int FROM order_files of WHERE of.order_id=o.id) files_count
       FROM orders o JOIN users u ON u.id=o.user_id
       LEFT JOIN ig_pages p ON p.id=o.page_id LEFT JOIN users e ON e.id=o.assigned_to
      WHERE ${where} ORDER BY o.created_at DESC LIMIT 150`, params)).rows);
}));
admin.post('/orders/:id/assign', requireRoles('super_admin','content_admin'), ah(async (req, res) => {
  const { expertId } = req.body || {};
  if (!expertId) return res.status(400).json({ message: 'کارشناس را انتخاب کنید' });
  const ex = await pool.query(`SELECT id,full_name FROM users WHERE id=$1 AND role IN ('editor','designer') AND is_blocked=false`, [expertId]);
  if (!ex.rowCount) return res.status(400).json({ message: 'کارشناس معتبر نیست' });
  const o = await mustOrder(req.params.id);
  if (!o) return res.status(404).json({ message: 'سفارش یافت نشد' });
  if (!['pending','assigned'].includes(o.status)) return res.status(400).json({ message: 'در این وضعیت امکان تخصیص نیست' });
  await pool.query(`UPDATE orders SET assigned_to=$2, status='assigned', updated_at=now() WHERE id=$1`, [o.id, expertId]);
  await olog(o.id, req.user.id, 'assign', `تخصیص به: ${ex.rows[0].full_name}`);
  await notify(expertId, 'سفارش جدید به شما اختصاص یافت 📌', `«${o.title}»`);
  await notify(o.user_id, 'بررسی سفارش', `سفارش «${o.title}» به کارشناس اختصاص یافت`);
  res.json({ ok: true });
}));
admin.post('/orders/:id/reject', requireRoles('super_admin','content_admin'), ah(async (req, res) => {
  const o = await mustOrder(req.params.id);
  if (!o) return res.status(404).json({ message: 'سفارش یافت نشد' });
  if (o.status !== 'pending') return res.status(400).json({ message: 'فقط سفارش در انتظار بررسی قابل رد است' });
  await pool.query(`UPDATE orders SET status='rejected', revision_note=$2, updated_at=now() WHERE id=$1`, [o.id, req.body.note || null]);
  await olog(o.id, req.user.id, 'reject', req.body.note || 'سفارش رد شد');
  await notify(o.user_id, 'سفارش رد شد', req.body.note ? `دلیل: ${req.body.note}` : `سفارش «${o.title}» تأیید نشد`);
  res.json({ ok: true });
}));

admin.get('/experts', requireRoles('super_admin','content_admin'), ah(async (_, res) => {
  res.json((await pool.query(
    `SELECT id,full_name,email,role,specialty,is_blocked,created_at,
            (SELECT count(*)::int FROM orders o WHERE o.assigned_to=u.id AND o.status NOT IN ('completed','canceled','rejected')) active_orders
       FROM users u WHERE role = ANY($1) ORDER BY created_at DESC`, [EXPERT_ROLES])).rows);
}));
admin.post('/experts', requireRoles('super_admin'), ah(async (req, res) => {
  const { fullName, email, password, role, specialty } = req.body || {};
  if (!fullName || !/.+@.+\..+/.test(email || '') || !password || password.length < 8)
    return res.status(400).json({ message: 'اطلاعات حساب معتبر نیست (رمز حداقل ۸ کاراکتر)' });
  if (!EXPERT_ROLES.includes(role)) return res.status(400).json({ message: 'نقش انتخاب‌شده مجاز نیست' });
  try {
    const r = await pool.query(
      `INSERT INTO users(full_name,email,password_hash,role,specialty) VALUES($1,$2,$3,$4,$5) RETURNING id,full_name,email,role,specialty`,
      [fullName.trim(), email.toLowerCase().trim(), await bcrypt.hash(password, 10), role, specialty || null]);
    await logActivity({ userId: req.user.id, action: 'expert_create', entity: 'user', entityId: r.rows[0].id });
    res.status(201).json(r.rows[0]);
  } catch (e) { if (e.code === '23505') return res.status(409).json({ message: 'این ایمیل قبلاً ثبت شده است' }); throw e; }
}));

admin.get('/plans', requireRoles('super_admin'), ah(async (_, res) => res.json((await pool.query('SELECT * FROM plans ORDER BY sort')).rows)));
admin.put('/plans/:id', requireRoles('super_admin'), ah(async (req, res) => {
  const b = req.body || {};
  const nums = [b.price_toman, b.duration_days, b.max_pages, b.max_orders_per_period, b.max_file_size_mb];
  if (nums.some((n) => n === undefined || isNaN(+n) || +n < 0)) return res.status(400).json({ message: 'مقادیر عددی معتبر نیست' });
  if (!Array.isArray(b.features)) return res.status(400).json({ message: 'ویژگی‌ها باید آرایه متن باشد' });
  const r = await pool.query(
    `UPDATE plans SET title=$2,price_toman=$3,duration_days=$4,max_pages=$5,max_orders_per_period=$6,
            max_file_size_mb=$7,features=$8,is_active=$9,sort=$10 WHERE id=$1 RETURNING *`,
    [req.params.id, b.title, +b.price_toman, +b.duration_days, +b.max_pages, +b.max_orders_per_period, +b.max_file_size_mb,
     JSON.stringify(b.features), !!b.is_active, +b.sort || 0]);
  if (!r.rowCount) return res.status(404).json({ message: 'پلن یافت نشد' });
  await logActivity({ userId: req.user.id, action: 'plan_update', entity: 'plan', entityId: req.params.id });
  res.json(r.rows[0]);
}));

admin.get('/settings', requireRoles('super_admin'), ah(async (_, res) => {
  res.json(Object.fromEntries((await pool.query('SELECT key,value FROM settings')).rows.map((x) => [x.key, x.value])));
}));
admin.put('/settings/:key', requireRoles('super_admin'), ah(async (req, res) => {
  const key = req.params.key; let { value } = req.body || {};
  if (!['storage.max_file_size_mb','storage.allowed_mime'].includes(key)) return res.status(400).json({ message: 'کلید نامعتبر است' });
  if (key === 'storage.max_file_size_mb') {
    value = +value;
    if (isNaN(value) || value < 1 || value > env.ceilingMB) return res.status(400).json({ message: `مقدار باید بین ۱ تا ${env.ceilingMB} باشد` });
  } else if (!Array.isArray(value) || !value.length || !value.every((m) => /^[\w.+-]+\/[\w.+-]+$/.test(m))) {
    return res.status(400).json({ message: 'لیست MIME معتبر نیست' });
  }
  await pool.query(`INSERT INTO settings(key,value) VALUES($1,$2) ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value`, [key, JSON.stringify(value)]);
  sCache.at = 0; // باطل‌کردن کش
  await logActivity({ userId: req.user.id, action: 'settings_update', meta: { key } });
  res.json({ ok: true });
}));

admin.post('/notify', requireRoles('super_admin','content_admin'), ah(async (req, res) => {
  const { userId, title, body } = req.body || {};
  if (!title || title.trim().length < 3) return res.status(400).json({ message: 'عنوان اعلان را بنویسید' });
  if (userId) await notify(userId, title.trim(), body || null);
  else await pool.query(`INSERT INTO notifications(user_id,title,body) SELECT id,$1,$2 FROM users WHERE role='customer' AND is_blocked=false`, [title.trim(), body || null]);
  await logActivity({ userId: req.user.id, action: 'notify_send', meta: { userId: userId || 'all' } });
  res.json({ ok: true });
}));

admin.get('/payments', requireRoles('super_admin'), ah(async (_, res) => {
  res.json((await pool.query(
    `SELECT pa.*, u.full_name user_name, u.email user_email, p.title plan_title
       FROM payments pa JOIN users u ON u.id=pa.user_id JOIN plans p ON p.id=pa.plan_id
      ORDER BY pa.created_at DESC LIMIT 100`)).rows);
}));
admin.post('/payments/:id/confirm', requireRoles('super_admin'), ah(async (req, res) => {
  const q = await pool.query('SELECT * FROM payments WHERE id=$1', [req.params.id]);
  if (!q.rowCount) return res.status(404).json({ message: 'پرداخت یافت نشد' });
  const pay = q.rows[0];
  if (pay.status !== 'pending') return res.status(400).json({ message: 'قبلاً پردازش شده است' });
  const plan = (await pool.query('SELECT * FROM plans WHERE id=$1', [pay.plan_id])).rows[0];
  await pool.query(`UPDATE payments SET status='paid', paid_at=now() WHERE id=$1`, [pay.id]);
  await activateSubscription(pay.user_id, plan);
  await notify(pay.user_id, 'پرداخت تأیید شد ✅', `اشتراک «${plan.title}» فعال شد.`);
  await logActivity({ userId: req.user.id, action: 'payment_confirm', entity: 'payment', entityId: pay.id });
  res.json({ ok: true });
}));
admin.post('/payments/:id/reject', requireRoles('super_admin'), ah(async (req, res) => {
  const q = await pool.query('SELECT * FROM payments WHERE id=$1', [req.params.id]);
  if (!q.rowCount) return res.status(404).json({ message: 'پرداخت یافت نشد' });
  if (q.rows[0].status !== 'pending') return res.status(400).json({ message: 'قبلاً پردازش شده است' });
  await pool.query(`UPDATE payments SET status='failed' WHERE id=$1`, [req.params.id]);
  await notify(q.rows[0].user_id, 'پرداخت تأیید نشد', 'در صورت واریز، با پشتیبانی تماس بگیرید.');
  res.json({ ok: true });
}));

app.use('/api/admin', admin);
app.use('/api', (_, res) => res.status(404).json({ message: 'مسیر API یافت نشد' }));

/* ── سرو فرانت‌اند ───────────────────────────────────────── */
app.use(express.static(env.publicDir));
app.get('*', (req, res, next) => {
  if (req.path.startsWith('/api')) return next();
  res.sendFile(path.join(env.publicDir, 'index.html'), (err) => err && next(err));
});

/* ── هندلر مرکزی خطا ─────────────────────────────────────── */
app.use((err, _req, res, _next) => {
  console.error(err);
  if (err && err.name === 'MulterError')
    return res.status(400).json({ message: err.code === 'LIMIT_FILE_SIZE' ? `حجم فایل بیش از سقف سرور (${env.ceilingMB}MB) است` : 'خطا در دریافت فایل: ' + err.code });
  res.status(err.status || 500).json({ message: err.expose && err.status ? err.message : 'خطای داخلی سرور' });
});
process.on('unhandledRejection', (e) => console.error('unhandledRejection:', e));

/* ── شروع ────────────────────────────────────────────────── */
(async () => {
  try {
    await ensureSchema();
    app.listen(env.port, () => console.log(`\n  ✔ ادمین‌یار آماده است → http://localhost:${env.port}\n    مدیر: ${env.adminEmail} / ${env.adminPassword}\n`));
  } catch (e) {
    console.error('✖ خطا در راه‌اندازی (دیتابیس روشن است؟):', e.message);
    process.exit(1);
  }
})();
AY_SRV_EOF

cat > public/index.html <<'AY_HTML_EOF'
<!doctype html>
<html lang="fa" dir="rtl">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>ادمین‌یار — مدیریت هوشمند پیج اینستاگرام</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/rastikerdar/vazirmatn@v33.003/Vazirmatn-font-face.css"/>
<script src="https://cdn.tailwindcss.com"></script>
<script>
tailwind.config={theme:{extend:{
  colors:{navy:{950:'#05081C',900:'#0A0F2E',800:'#0F1638',700:'#161F4E',600:'#232D6B'}},
  fontFamily:{sans:['Vazirmatn','sans-serif']},
  boxShadow:{neon:'0 0 18px rgba(34,211,238,.35)',glow:'0 4px 24px rgba(124,58,237,.35)'}
}}};
</script>
<style>
  html{scrollbar-color:#232d6b #05081c}
  body{background:#05081c;color:#e2e8f0;font-family:Vazirmatn,sans-serif}
  ::-webkit-scrollbar{width:8px;height:8px}
  ::-webkit-scrollbar-thumb{background:#232d6b;border-radius:8px}
  input[type=datetime-local]{color-scheme:dark}
  .fade-up{animation:fadeUp .35s ease both}
  @keyframes fadeUp{from{opacity:0;transform:translateY(14px)}to{opacity:1;transform:none}}
</style>
<script crossorigin src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
<script crossorigin src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
<script src="https://unpkg.com/@babel/standalone@7/babel.min.js"></script>
</head>
<body>
<div id="root"></div>

<script type="text/babel" data-presets="react">
const {useState,useEffect,useMemo,useRef,createContext,useContext} = React;

/* ═══════════ ۱) ابزارها: اعداد فارسی + تقویم جلالی (جاسازی‌شده) ═══════════ */
const faDigits = s => String(s).replace(/\d/g, d=>'۰۱۲۳۴۵۶۷۸۹'[d]);
const faNum = n => Number(n).toLocaleString('fa-IR');
const pad2 = n => String(n).padStart(2,'0');
const fmtSize = b => faDigits((b/1048576).toFixed(1))+' مگابایت';

const Jal=(()=>{
  const breaks=[-61,9,38,199,426,686,756,818,1111,1181,1210,1635,2060,2097,2192,2262,2324,2394,2456,3178];
  const div=(a,b)=>~~(a/b), mod=(a,b)=>a-~~(a/b)*b;
  function jalCal(jy){
    let gy=jy+621, leapJ=-14, jp=breaks[0], jm, jump=0, leap, leapG, march, n, i;
    for(i=1;i<breaks.length;i++){ jm=breaks[i]; jump=jm-jp; if(jy<jm) break; leapJ+=div(jump,33)*8+div(mod(jump,33),4); jp=jm; }
    n=jy-jp; leapJ+=div(n,33)*8+div(mod(n,33)+3,4);
    if(mod(jump,33)===4 && jump-n===4) leapJ+=1;
    leapG=div(gy,4)-div((div(gy,100)+1)*3,4)-150; march=20+leapJ-leapG;
    if(jump-n<6) n=n-jump+div(jump+4,33)*33;
    leap=mod(mod(n+1,33)-1,4); if(leap===-1) leap=4;
    return {leap,gy,march};
  }
  function g2d(gy,gm,gd){ let d=div((gy+div(gm-8,6)+100100)*1461,4)+div(153*mod(gm+9,12)+2,5)+gd-34840408; return d-div(div(gy+100100+div(gm-8,6),100)*3,4)+752; }
  function d2g(j){ j=4*j+139361631; j+=div(div(4*j+183187720,146097)*3,4)*4-3908; const i=div(mod(j,1461),4)*5+308; const gd=div(mod(i,153),5)+1, gm=mod(div(i,153),12)+1; return {gy:div(j,1461)-100100+div(8-gm,6),gm,gd}; }
  function j2d(jy,jm,jd){ const r=jalCal(jy); return g2d(r.gy,3,r.march)+(jm-1)*31-div(jm,7)*(jm-7)+jd-1; }
  function d2j(j){ let gy=d2g(j).gy, jy=gy-621; const r=jalCal(jy); let k=j-g2d(gy,3,r.march), jm, jd;
    if(k>=0){ if(k<=185) return {jy,jm:1+div(k,31),jd:mod(k,31)+1}; k-=186; } else { jy-=1; k+=179; if(r.leap===1) k+=1; }
    jm=7+div(k,30); jd=mod(k,30)+1; return {jy,jm,jd};
  }
  return {
    toJal:(y,m,d)=>d2j(g2d(y,m,d)),
    toGreg:(y,m,d)=>d2g(j2d(y,m,d)),
    isLeap:y=>jalCal(y).leap===0,
    monthLen:(y,m)=> m<=6?31 : m<=11?30 : (jalCal(y).leap===0?30:29)
  };
})();

const MONTHS=['فروردین','اردیبهشت','خرداد','تیر','مرداد','شهریور','مهر','آبان','آذر','دی','بهمن','اسفند'];
const WEEKDAYS=['ش','ی','د','س','چ','پ','ج'];
function jDate(d){ d=new Date(d); const j=Jal.toJal(d.getFullYear(),d.getMonth()+1,d.getDate()); return faDigits(j.jy+'/'+pad2(j.jm)+'/'+pad2(j.jd)); }
function jTime(d){ d=new Date(d); return faDigits(pad2(d.getHours())+':'+pad2(d.getMinutes())); }
function dayKey(d){ d=new Date(d); return d.getFullYear()+'-'+pad2(d.getMonth()+1)+'-'+pad2(d.getDate()); }
function toLocalInput(d){ d=new Date(d); return d.getFullYear()+'-'+pad2(d.getMonth()+1)+'-'+pad2(d.getDate())+'T'+pad2(d.getHours())+':'+pad2(d.getMinutes()); }
function monthGrid(jy,jm){
  const g=Jal.toGreg(jy,jm,1);
  const first=new Date(g.gy,g.gm-1,g.gd);
  const off=(first.getDay()+1)%7;
  const start=new Date(first); start.setDate(start.getDate()-off);
  return Array.from({length:42},(_,i)=>{
    const dt=new Date(start); dt.setDate(start.getDate()+i);
    const j=Jal.toJal(dt.getFullYear(),dt.getMonth()+1,dt.getDate());
    return {date:dt, jd:j.jd, inMonth:j.jm===jm&&j.jy===jy, key:dayKey(dt)};
  });
}
const uid=()=> (crypto.randomUUID ? crypto.randomUUID() : 'id-'+Date.now()+'-'+Math.random());

/* ═══════════ ۲) ثابت‌ها ═══════════ */
const ORDER_STATUS={
  pending:{label:'در انتظار بررسی',cls:'bg-amber-500/15 text-amber-300 border-amber-400/30'},
  rejected:{label:'رد شده',cls:'bg-rose-500/15 text-rose-300 border-rose-400/30'},
  assigned:{label:'اختصاص‌یافته',cls:'bg-blue-500/15 text-blue-300 border-blue-400/30'},
  in_progress:{label:'در حال انجام',cls:'bg-violet-500/15 text-violet-300 border-violet-400/30'},
  delivered:{label:'تحویل‌شده',cls:'bg-cyan-500/15 text-cyan-300 border-cyan-400/30'},
  revision_requested:{label:'درخواست اصلاح',cls:'bg-orange-500/15 text-orange-300 border-orange-400/30'},
  approved:{label:'تأییدشده',cls:'bg-emerald-500/15 text-emerald-300 border-emerald-400/30'},
  scheduled:{label:'زمان‌بندی‌شده',cls:'bg-sky-500/15 text-sky-300 border-sky-400/30'},
  completed:{label:'تکمیل‌شده',cls:'bg-emerald-500/25 text-emerald-200 border-emerald-300/40'},
  canceled:{label:'لغوشده',cls:'bg-slate-500/15 text-slate-300 border-slate-400/30'}
};
const SCHED_STATUS={
  scheduled:{label:'زمان‌بندی‌شده',cls:'bg-sky-500/15 text-sky-300 border-sky-400/30',dot:'bg-sky-400'},
  manual_ready:{label:'آماده انتشار دستی',cls:'bg-amber-500/15 text-amber-300 border-amber-400/30',dot:'bg-amber-400'},
  published:{label:'منتشرشده',cls:'bg-emerald-500/15 text-emerald-300 border-emerald-400/30',dot:'bg-emerald-400'},
  failed:{label:'ناموفق',cls:'bg-rose-500/15 text-rose-300 border-rose-400/30',dot:'bg-rose-400'}
};
const PAY_STATUS={
  pending:{label:'در انتظار تأیید',cls:'bg-amber-500/15 text-amber-300 border-amber-400/30'},
  paid:{label:'پرداخت‌شده',cls:'bg-emerald-500/15 text-emerald-300 border-emerald-400/30'},
  failed:{label:'ناموفق',cls:'bg-rose-500/15 text-rose-300 border-rose-400/30'}
};
const ORDER_TYPES={edit_video:'تدوین ویدیو',raw_to_reel:'تبدیل فیلم خام به ریلز',design:'طراحی گرافیک',story_design:'طراحی استوری',caption_hashtag:'کپشن و هشتگ'};
const FILE_KINDS={story:'استوری',post:'پست/اسلاید',reel:'ریلز',raw_video:'فیلم خام',deliverable:'خروجی نهایی'};
const ROLE_LABELS={customer:'مشتری',super_admin:'مدیر کل',content_admin:'ادمین محتوا',editor:'تدوینگر',designer:'طراح گرافیک',support:'کارشناس پشتیبانی'};
const SUB_BADGE={active:'bg-emerald-500/15 text-emerald-300',expired:'bg-rose-500/15 text-rose-300',unpaid:'bg-slate-500/15 text-slate-300',canceled:'bg-orange-500/15 text-orange-300'};
const ADMIN_ROLES=['super_admin','content_admin','editor','designer','support'];

/* ═══════════ ۳) لایه API (fetch + XHR برای پیشرفت آپلود) ═══════════ */
async function request(method,p,body){
  const headers={};
  const t=localStorage.getItem('ay_token');
  if(t) headers.Authorization='Bearer '+t;
  let payload;
  if(body!==undefined){ headers['Content-Type']='application/json'; payload=JSON.stringify(body); }
  const res=await fetch('/api'+p,{method,headers,body:payload});
  let data=null; try{ data=await res.json(); }catch(e){}
  if(res.status===401){ localStorage.removeItem('ay_token'); localStorage.removeItem('ay_user'); if(!location.hash.startsWith('#/login')) location.hash='#/login'; }
  if(res.status===402 && data && data.code==='SUBSCRIPTION_REQUIRED'){ location.hash='#/subscription'; }
  if(!res.ok){ const err=new Error((data&&data.message)||('خطای '+res.status)); err.status=res.status; throw err; }
  return data;
}
const api={get:p=>request('GET',p),post:(p,b)=>request('POST',p,b),put:(p,b)=>request('PUT',p,b),patch:(p,b)=>request('PATCH',p,b),del:p=>request('DELETE',p)};

function uploadXHR(form,onProgress){
  return new Promise((resolve,reject)=>{
    const xhr=new XMLHttpRequest();
    xhr.open('POST','/api/uploads');
    const t=localStorage.getItem('ay_token'); if(t) xhr.setRequestHeader('Authorization','Bearer '+t);
    xhr.upload.onprogress=e=>{ if(e.lengthComputable&&onProgress) onProgress(Math.round(e.loaded/e.total*100)); };
    xhr.onerror=()=>reject(new Error('خطای شبکه'));
    xhr.onload=()=>{ let d=null; try{d=JSON.parse(xhr.responseText);}catch(e){}
      if(xhr.status>=200&&xhr.status<300) resolve(d);
      else reject(new Error((d&&d.message)||'خطا در آپلود')); };
    xhr.send(form);
  });
}
async function downloadFile(id,name){
  const t=localStorage.getItem('ay_token');
  const res=await fetch('/api/uploads/'+id+'/download',{headers:t?{Authorization:'Bearer '+t}:{}});
  if(!res.ok){ let d=null; try{d=await res.json();}catch(e){} throw new Error((d&&d.message)||'خطا در دانلود'); }
  const blob=await res.blob();
  const url=URL.createObjectURL(blob);
  const a=document.createElement('a'); a.href=url; a.download=name||'file';
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(()=>URL.revokeObjectURL(url),2000);
}

/* ═══════════ ۴) Toast ═══════════ */
const toastSet=new Set();
function toast(msg,type){ toastSet.forEach(f=>f({msg,type:type||'success'})); }
function ToastHost(){
  const [items,setItems]=useState([]);
  useEffect(()=>{
    const f=t=>{ const id=uid(); setItems(l=>[...l,{...t,id}]); setTimeout(()=>setItems(l=>l.filter(x=>x.id!==id)),3800); };
    toastSet.add(f); return ()=>toastSet.delete(f);
  },[]);
  return (
    <div className="fixed bottom-5 inset-x-0 flex flex-col items-center gap-2 z-[100] px-4 pointer-events-none">
      {items.map(t=>(
        <div key={t.id} className={'fade-up flex items-center gap-2 rounded-xl px-4 py-3 text-sm border backdrop-blur shadow-lg '+
          (t.type==='error'?'bg-rose-500/15 border-rose-400/40 text-rose-200':'bg-emerald-500/15 border-emerald-400/40 text-emerald-200')}>
          <Ic n={t.type==='error'?'alert':'check'} c="w-4 h-4 shrink-0"/>{t.msg}
        </div>
      ))}
    </div>
  );
}

/* ═══════════ ۵) آیکون‌های SVG داخلی ═══════════ */
const PATHS={
  menu:'<line x1="4" x2="20" y1="6" y2="6"/><line x1="4" x2="20" y1="12" y2="12"/><line x1="4" x2="20" y1="18" y2="18"/>',
  x:'<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
  bell:'<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
  download:'<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" x2="12" y1="15" y2="3"/>',
  upload:'<path d="M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242"/><path d="M12 12v9"/><path d="m16 16-4-4-4 4"/>',
  calendar:'<path d="M8 2v4"/><path d="M16 2v4"/><rect width="18" height="18" x="3" y="4" rx="2"/><path d="M3 10h18"/>',
  plus:'<path d="M5 12h14"/><path d="M12 5v14"/>',
  trash:'<path d="M3 6h18"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/><path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>',
  check:'<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>',
  alert:'<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/><path d="M12 9v4"/><path d="M12 17h.01"/>',
  pencil:'<path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/>',
  refresh:'<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/>',
  logout:'<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" x2="9" y1="12" y2="12"/>',
  users:'<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
  clipboard:'<rect width="8" height="4" x="8" y="2" rx="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/>',
  credit:'<rect width="20" height="14" x="2" y="5" rx="2"/><line x1="2" x2="22" y1="10" y2="10"/>',
  settings:'<line x1="4" x2="4" y1="21" y2="14"/><line x1="4" x2="4" y1="10" y2="3"/><line x1="12" x2="12" y1="21" y2="12"/><line x1="12" x2="12" y1="8" y2="3"/><line x1="20" x2="20" y1="21" y2="16"/><line x1="20" x2="20" y1="12" y2="3"/><line x1="2" x2="6" y1="14" y2="14"/><line x1="10" x2="14" y1="8" y2="8"/><line x1="18" x2="22" y1="16" y2="16"/>',
  send:'<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>',
  chevL:'<path d="m15 18-6-6 6-6"/>',
  chevR:'<path d="m9 18 6-6-6-6"/>',
  clock:'<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>',
  image:'<rect width="18" height="18" x="3" y="3" rx="2"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21"/>',
  video:'<path d="m22 8-6 4 6 4V8Z"/><rect width="14" height="12" x="2" y="6" rx="2"/>',
  layout:'<rect width="7" height="9" x="3" y="3" rx="1"/><rect width="7" height="5" x="14" y="3" rx="1"/><rect width="7" height="9" x="14" y="12" rx="1"/><rect width="7" height="5" x="3" y="16" rx="1"/>',
  instagram:'<rect width="20" height="20" x="2" y="2" rx="5"/><path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z"/><line x1="17.5" x2="17.51" y1="6.5" y2="6.5"/>',
  megaphone:'<path d="m3 11 18-5v12L3 14v-3z"/><path d="M11.6 16.8a3 3 0 1 1-5.8-1.6"/>',
  tag:'<path d="M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 .586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42z"/><circle cx="7.5" cy="7.5" r=".5" fill="currentColor"/>',
  sparkles:'<path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z"/>',
  usercog:'<circle cx="18" cy="15" r="3"/><circle cx="9" cy="7" r="4"/><path d="M10 15H6a4 4 0 0 0-4 4v2"/><path d="m21.7 16.4-.9-.3"/><path d="m15.2 13.9-.9-.3"/><path d="m16.6 18.7.3-.9"/><path d="m19.1 12.2.3-.9"/><path d="m19.6 18.7-.4-1"/><path d="m16.8 12.3-.4-1"/><path d="m14.3 16.6 1-.4"/><path d="m20.7 13.8 1-.4"/>',
  shieldcheck:'<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>',
  shieldx:'<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9.5 10.5 5 5"/><path d="m14.5 10.5-5 5"/>',
  file:'<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/>'
};
function Ic({n,c}){ return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={c||'w-4 h-4'} dangerouslySetInnerHTML={{__html:PATHS[n]||''}}/>; }

/* ═══════════ ۶) کامپوننت‌های UI ═══════════ */
function Card({className,children}){ return <div className={'bg-navy-800/60 backdrop-blur border border-white/10 rounded-2xl '+(className||'')}>{children}</div>; }
function Spinner({c}){ return <svg className={'animate-spin text-cyan-400 '+(c||'w-6 h-6')} viewBox="0 0 24 24" fill="none"><circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"/><path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"/></svg>; }
function Button({variant,loading,className,children,as,...props}){
  const v={primary:'bg-gradient-to-l from-violet-600 to-cyan-500 text-white shadow-glow hover:brightness-110',
    ghost:'bg-white/5 hover:bg-white/10 text-slate-200 border border-white/10',
    danger:'bg-rose-500/80 hover:bg-rose-500 text-white',
    success:'bg-emerald-500/80 hover:bg-emerald-500 text-white',
    outline:'border border-cyan-400/40 text-cyan-300 hover:bg-cyan-400/10'};
  const Tag=as||'button';
  return <Tag className={'inline-flex items-center justify-center gap-2 rounded-xl px-4 py-2.5 text-sm font-medium transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed active:scale-[.98] '+v[variant||'primary']+' '+(className||'')} disabled={loading||(props&&props.disabled)} {...props}>{loading&&<Spinner c="w-4 h-4"/>}{children}</Tag>;
}
function Input({label,className,...p}){
  return <label className="block space-y-1.5">{label&&<span className="text-xs text-slate-400">{label}</span>}
    <input className={'w-full bg-navy-900/70 border border-white/10 rounded-xl px-3.5 py-2.5 text-sm outline-none focus:border-cyan-400/60 placeholder:text-slate-500 '+(className||'')} {...p}/></label>;
}
function Select({label,className,children,...p}){
  return <label className="block space-y-1.5">{label&&<span className="text-xs text-slate-400">{label}</span>}
    <select className={'w-full bg-navy-900/70 border border-white/10 rounded-xl px-3 py-2.5 text-sm outline-none focus:border-cyan-400/60 '+(className||'')} {...p}>{children}</select></label>;
}
function Ta({label,className,...p}){
  return <label className="block space-y-1.5">{label&&<span className="text-xs text-slate-400">{label}</span>}
    <textarea rows={3} className={'w-full bg-navy-900/70 border border-white/10 rounded-xl px-3.5 py-2.5 text-sm outline-none focus:border-cyan-400/60 placeholder:text-slate-500 resize-y '+(className||'')} {...p}/></label>;
}
function Modal({open,onClose,title,children,wide}){
  if(!open) return null;
  return <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center sm:p-4">
    <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={onClose}></div>
    <div className={'fade-up relative w-full bg-navy-800 border border-white/10 rounded-t-3xl sm:rounded-2xl p-5 space-y-4 '+(wide?'sm:max-w-2xl':'sm:max-w-md')}>
      <div className="flex items-center justify-between"><h3 className="font-bold">{title}</h3>
        <button onClick={onClose}><Ic n="x" c="w-5 h-5 text-slate-400"/></button></div>
      {children}
    </div></div>;
}
function Badge({s,map}){ const m=map||ORDER_STATUS; const x=m[s]||{label:s,cls:'bg-slate-500/15 text-slate-300 border-slate-400/30'};
  return <span className={'inline-flex items-center rounded-full border px-2.5 py-0.5 text-[11px] font-medium whitespace-nowrap '+x.cls}>{x.label}</span>; }
function PageTitle({title,sub,children}){
  return <div className="flex flex-wrap items-center justify-between gap-3 mb-6"><div>
    <h1 className="text-xl font-bold">{title}</h1>{sub&&<p className="text-sm text-slate-400 mt-1">{sub}</p>}</div>{children}</div>;
}
function Empty({text}){ return <div className="text-center py-14 text-slate-500 text-sm">{text||'موردی یافت نشد'}</div>; }
function Brand(){
  return <div className="flex items-center gap-2.5">
    <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-violet-600 to-cyan-400 flex items-center justify-center font-black text-white shadow-neon">آ</div>
    <div><div className="font-extrabold tracking-tight leading-5">ادمین‌یار</div>
    <div className="text-[10px] text-slate-400">مدیریت هوشمند پیج اینستاگرام</div></div></div>;
}
function AuthShell({title,sub,children}){
  return <div className="min-h-screen flex items-center justify-center p-4 bg-[radial-gradient(ellipse_at_top_right,rgba(124,58,237,.18),transparent_60%),radial-gradient(ellipse_at_bottom_left,rgba(34,211,238,.12),transparent_55%)]">
    <div className="fade-up w-full max-w-sm space-y-6"><Brand/>
      <Card className="p-6 space-y-5"><div><h1 className="text-lg font-bold">{title}</h1><p className="text-sm text-slate-400 mt-1">{sub}</p></div>{children}</Card>
    </div></div>;
}

/* ═══════════ ۷) احراز هویت ═══════════ */
const AuthCtx=createContext(null);
function AuthProvider({children}){
  const [user,setUser]=useState(()=>{ try{return JSON.parse(localStorage.getItem('ay_user'));}catch(e){return null;} });
  const [ready,setReady]=useState(!localStorage.getItem('ay_token'));
  useEffect(()=>{ (async()=>{
    if(!localStorage.getItem('ay_token')){ setReady(true); return; }
    try{ setUser(await request('GET','/auth/me')); }catch(e){}
    setReady(true);
  })(); },[]);
  const store=(t,u)=>{ localStorage.setItem('ay_token',t); localStorage.setItem('ay_user',JSON.stringify(u)); setUser(u); };
  const value={
    user,ready,
    login:async(email,password)=>{ const r=await request('POST','/auth/login',{email,password}); store(r.token,r.user); return r.user; },
    register:async(p)=>{ const r=await request('POST','/auth/register',p); store(r.token,r.user); return r.user; },
    logout:()=>{ localStorage.removeItem('ay_token'); localStorage.removeItem('ay_user'); setUser(null); go('/login'); }
  };
  return <AuthCtx.Provider value={value}>{children}</AuthCtx.Provider>;
}
const useAuth=()=>useContext(AuthCtx);
const homeFor=r=> r==='customer' ? '/dashboard' : '/admin';

/* ═══════════ ۸) روتر Hash ═══════════ */
function useRoute(){
  const [h,setH]=useState(()=>location.hash.slice(1)||'/');
  useEffect(()=>{ const f=()=>setH(location.hash.slice(1)||'/');
    window.addEventListener('hashchange',f); return ()=>window.removeEventListener('hashchange',f); },[]);
  const pq=h.split('?');
  return { path:pq[0]||'/', query:new URLSearchParams(pq[1]||'') };
}
const go=p=>{ location.hash=p; };
function Link({to,children,className,onClick,title}){ return <a href={'#'+to} className={className} onClick={onClick} title={title}>{children}</a>; }
function Redirect({to}){ useEffect(()=>{ go(to); },[]); return null; }

/* ═══════════ ۹) صفحات احراز هویت ═══════════ */
function Login(){
  const {user,login}=useAuth();
  const [f,setF]=useState({email:'',password:''}); const [busy,setBusy]=useState(false);
  if(user) return <Redirect to={homeFor(user.role)}/>;
  const submit=async e=>{ e.preventDefault(); setBusy(true);
    try{ const u=await login(f.email,f.password); toast('خوش آمدید، '+u.full_name); go(homeFor(u.role)); }
    catch(err){ toast(err.message,'error'); } finally{ setBusy(false); } };
  return <AuthShell title="ورود به ادمین‌یار" sub="پنل مدیریت پیج اینستاگرام شما">
    <form onSubmit={submit} className="space-y-4">
      <Input label="ایمیل" type="email" dir="ltr" required placeholder="you@example.com" value={f.email} onChange={e=>setF({...f,email:e.target.value})}/>
      <Input label="رمز عبور" type="password" required value={f.password} onChange={e=>setF({...f,password:e.target.value})}/>
      <Button className="w-full" loading={busy} type="submit">ورود</Button>
      <p className="text-center text-sm text-slate-400">حساب ندارید؟ <Link to="/register" className="text-cyan-300 font-medium hover:underline">ثبت‌نام + ۳ روز رایگان</Link></p>
    </form></AuthShell>;
}
function Register(){
  const {user,register}=useAuth();
  const [f,setF]=useState({fullName:'',email:'',password:'',confirm:''}); const [busy,setBusy]=useState(false);
  if(user) return <Redirect to={homeFor(user.role)}/>;
  const submit=async e=>{ e.preventDefault();
    if(f.password!==f.confirm) return toast('تکرار رمز مطابقت ندارد','error');
    setBusy(true);
    try{ const u=await register({fullName:f.fullName,email:f.email,password:f.password});
      toast('ثبت‌نام شد؛ اشتراک آزمایشی ۳ روزه فعال شد 🎉'); go(homeFor(u.role)); }
    catch(err){ toast(err.message,'error'); } finally{ setBusy(false); } };
  return <AuthShell title="ساخت حساب جدید" sub="با ثبت‌نام، ۳ روز اشتراک آزمایشی رایگان می‌گیرید">
    <form onSubmit={submit} className="space-y-4">
      <Input label="نام و نام خانوادگی" required value={f.fullName} onChange={e=>setF({...f,fullName:e.target.value})}/>
      <Input label="ایمیل" type="email" dir="ltr" required value={f.email} onChange={e=>setF({...f,email:e.target.value})}/>
      <Input label="رمز عبور (حداقل ۸ کاراکتر)" type="password" required value={f.password} onChange={e=>setF({...f,password:e.target.value})}/>
      <Input label="تکرار رمز عبور" type="password" required value={f.confirm} onChange={e=>setF({...f,confirm:e.target.value})}/>
      <Button className="w-full" loading={busy} type="submit">ثبت‌نام</Button>
      <p className="text-center text-sm text-slate-400">قبلاً ثبت‌نام کرده‌اید؟ <Link to="/login" className="text-cyan-300 font-medium hover:underline">ورود</Link></p>
    </form></AuthShell>;
}

/* ═══════════ ۱۰) اسکلت (سایدبار + هدر) ═══════════ */
function useUnread(){
  const [n,setN]=useState(0);
  useEffect(()=>{ let t; const f=async()=>{ try{ const r=await api.get('/notifications'); setN(r.unread); }catch(e){} };
    f(); t=setInterval(f,30000); return ()=>clearInterval(t); },[]);
  return n;
}
const NAV={
  customer:[
    {to:'/dashboard',l:'داشبورد',i:'layout',end:true},{to:'/pages',l:'پیج‌های من',i:'instagram'},
    {to:'/upload',l:'آپلود محتوا',i:'upload'},{to:'/orders/new',l:'ثبت سفارش',i:'plus'},
    {to:'/orders',l:'سفارش‌های من',i:'clipboard'},{to:'/calendar',l:'تقویم محتوایی',i:'calendar'},
    {to:'/subscription',l:'اشتراک',i:'credit'},{to:'/notifications',l:'اعلان‌ها',i:'bell'}],
  super_admin:[
    {to:'/admin',l:'داشبورد',i:'layout',end:true},{to:'/admin/orders',l:'سفارش‌ها',i:'clipboard'},
    {to:'/admin/calendar',l:'تقویم انتشار',i:'calendar'},{to:'/admin/users',l:'کاربران',i:'users'},
    {to:'/admin/payments',l:'پرداخت‌ها',i:'credit'},{to:'/admin/experts',l:'تیم و کارشناسان',i:'usercog'},
    {to:'/admin/plans',l:'پلن‌ها و قیمت‌ها',i:'tag'},{to:'/admin/settings',l:'تنظیمات',i:'settings'},
    {to:'/admin/notify',l:'ارسال اعلان',i:'megaphone'}],
  content_admin:[
    {to:'/admin',l:'داشبورد',i:'layout',end:true},{to:'/admin/orders',l:'سفارش‌ها',i:'clipboard'},
    {to:'/admin/calendar',l:'تقویم انتشار',i:'calendar'},{to:'/admin/notify',l:'ارسال اعلان',i:'megaphone'}],
  support:[
    {to:'/admin',l:'داشبورد',i:'layout',end:true},{to:'/admin/orders',l:'سفارش‌ها (مشاهده)',i:'clipboard'},
    {to:'/admin/users',l:'کاربران',i:'users'}],
  editor:[{to:'/admin/orders',l:'سفارش‌های من',i:'clipboard'}],
  designer:[{to:'/admin/orders',l:'سفارش‌های من',i:'clipboard'}]
};
function Shell({children}){
  const {path}=useRoute();
  const {user,logout}=useAuth();
  const [open,setOpen]=useState(false);
  const unread=useUnread();
  const items=NAV[user.role]||[];
  const notifTo=user.role==='customer'?'/notifications':'/admin/notifications';
  return (
    <div className="min-h-screen bg-[radial-gradient(ellipse_at_top,rgba(124,58,237,.10),transparent_55%)]">
      <aside className={'fixed inset-y-0 right-0 z-40 w-72 bg-navy-900/95 backdrop-blur border-l border-white/10 p-5 transition-transform duration-300 lg:translate-x-0 '+(open?'translate-x-0':'translate-x-full')}>
        <Brand/>
        <nav className="mt-8 space-y-1">
          {items.map(it=>{
            const active=it.end? path===it.to : (path===it.to||path.startsWith(it.to+'/'));
            return <Link key={it.to} to={it.to} onClick={()=>setOpen(false)}
              className={'flex items-center gap-3 rounded-xl px-3.5 py-2.5 text-sm transition '+(active?'bg-gradient-to-l from-violet-600/30 to-cyan-500/20 text-white border border-cyan-400/20 shadow-neon':'text-slate-400 hover:text-white hover:bg-white/5')}>
              <Ic n={it.i}/>{it.l}</Link>;
          })}
        </nav>
        <div className="absolute bottom-5 right-5 left-5 border-t border-white/10 pt-4 flex items-center justify-between">
          <div className="min-w-0"><div className="text-sm font-medium truncate">{user.full_name}</div>
            <div className="text-[11px] text-slate-400">{ROLE_LABELS[user.role]}</div></div>
          <button onClick={logout} title="خروج" className="p-2 rounded-lg hover:bg-rose-500/15 text-slate-400 hover:text-rose-300 transition"><Ic n="logout"/></button>
        </div>
      </aside>
      {open&&<div className="fixed inset-0 bg-black/60 z-30 lg:hidden" onClick={()=>setOpen(false)}></div>}
      <div className="lg:mr-72">
        <header className="sticky top-0 z-20 backdrop-blur bg-navy-950/70 border-b border-white/5 px-4 py-3 flex items-center justify-between">
          <button className="lg:hidden p-2 -mr-2" onClick={()=>setOpen(true)}><Ic n="menu" c="w-5 h-5"/></button>
          <div className="lg:hidden scale-90 origin-right"><Brand/></div>
          <Link to={notifTo} className="lg:ml-auto relative block p-2 rounded-lg hover:bg-white/5 transition">
            <Ic n="bell" c="w-5 h-5 text-slate-300"/>
            {unread>0&&<span className="absolute -top-0.5 -left-0.5 min-w-[18px] h-[18px] px-1 rounded-full bg-cyan-400 text-navy-950 text-[10px] font-bold flex items-center justify-center">{faNum(unread)}</span>}
          </Link>
        </header>
        <main className="fade-up p-4 md:p-6 max-w-6xl mx-auto">{children}</main>
      </div>
    </div>
  );
}

/* ═══════════ ۱۱) داشبورد مشتری ═══════════ */
function Dashboard(){
  const [d,setD]=useState(null);
  useEffect(()=>{ (async()=>{ try{
    const [orders,pages,sub,cal]=await Promise.all([
      api.get('/orders'),api.get('/pages'),api.get('/subscriptions/me'),
      api.get('/calendar?from='+encodeURIComponent(new Date().toISOString())+'&to='+encodeURIComponent(new Date(Date.now()+14*86400000).toISOString()))]);
    setD({orders,pages,sub,upcoming:cal});
  }catch(e){} })(); },[]);
  if(!d) return <div className="flex justify-center py-20"><Spinner/></div>;
  const active=d.orders.filter(o=>!['completed','canceled','rejected'].includes(o.status)).length;
  const waiting=d.orders.filter(o=>o.status==='delivered').length;
  const cur=d.sub.current;
  const isActive=cur&&cur.status==='active';
  const daysLeft=isActive?Math.max(0,Math.ceil((new Date(cur.expires_at)-Date.now())/86400000)):0;
  const stats=[
    {l:'پیج‌های من',v:d.pages.length,i:'instagram',to:'/pages'},
    {l:'سفارش‌های فعال',v:active,i:'clipboard',to:'/orders'},
    {l:'در انتظار تأیید شما',v:waiting,i:'check',to:'/orders'},
    {l:'انتشارهای ۱۴ روز آینده',v:d.upcoming.length,i:'calendar',to:'/calendar'}];
  return (<div>
    <PageTitle title="داشبورد" sub="نمای کلی فعالیت پیج‌های شما"/>
    {!isActive&&<Card className="p-5 mb-6 border-amber-400/30 bg-amber-500/5 flex flex-wrap items-center justify-between gap-3">
      <div className="flex items-center gap-3"><Ic n="credit" c="w-6 h-6 text-amber-300"/>
        <div><div className="font-medium text-amber-200">اشتراک فعالی ندارید</div>
        <div className="text-xs text-amber-300/70">برای آپلود و ثبت سفارش، اشتراک بخرید یا تمدید کنید</div></div></div>
      <Button variant="outline" as="a" href="#/subscription">خرید / تمدید اشتراک</Button>
    </Card>}
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-6">
      {stats.map(s=><Link key={s.l} to={s.to}><Card className="p-4 hover:border-cyan-400/30 transition group">
        <div className="flex items-center justify-between"><div className="text-[11px] text-slate-400">{s.l}</div><Ic n={s.i} c="w-4 h-4 text-cyan-400"/></div>
        <div className="text-2xl font-extrabold mt-2 bg-gradient-to-l from-cyan-300 to-violet-300 bg-clip-text text-transparent">{faNum(s.v)}</div>
      </Card></Link>)}
    </div>
    {isActive&&<Card className="p-5 mb-6">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="font-medium">{cur.plan_title}</div>
        <div className="text-xs text-slate-400">{faNum(daysLeft)} روز باقی‌مانده · پایان: {jDate(cur.expires_at)}</div></div>
      <div className="h-1.5 bg-white/10 rounded-full overflow-hidden mt-3">
        <div className="h-full bg-gradient-to-l from-violet-500 to-cyan-400" style={{width:Math.min(100,(daysLeft/cur.duration_days)*100)+'%'}}></div></div>
    </Card>}
    <div className="grid lg:grid-cols-2 gap-4">
      <Card className="p-5">
        <div className="flex items-center justify-between mb-3"><h2 className="font-bold">آخرین سفارش‌ها</h2><Link to="/orders" className="text-xs text-cyan-300 hover:underline">همه</Link></div>
        <div className="space-y-2">
          {d.orders.slice(0,5).map(o=><Link key={o.id} to={'/orders/'+o.id} className="flex items-center justify-between p-2.5 rounded-xl hover:bg-white/5 transition">
            <div className="min-w-0"><div className="text-sm truncate">{o.title}</div>
            <div className="text-[11px] text-slate-400">{ORDER_TYPES[o.type]||o.type} · {jDate(o.created_at)}</div></div><Badge s={o.status}/></Link>)}
          {!d.orders.length&&<div className="text-xs text-slate-500 py-4 text-center">هنوز سفارشی ثبت نکرده‌اید</div>}
        </div>
      </Card>
      <Card className="p-5">
        <div className="flex items-center justify-between mb-3"><h2 className="font-bold">انتشارهای پیش‌رو</h2><Link to="/calendar" className="text-xs text-cyan-300 hover:underline">تقویم</Link></div>
        <div className="space-y-2">
          {d.upcoming.slice(0,5).map(p=><div key={p.id} className="flex items-center justify-between p-2.5 rounded-xl bg-white/[.03]">
            <div className="flex items-center gap-2.5 min-w-0"><span className={'w-2 h-2 rounded-full shrink-0 '+(SCHED_STATUS[p.status]?SCHED_STATUS[p.status].dot:'bg-sky-400')}></span>
              <div className="min-w-0"><div className="text-sm truncate">{p.order_title||p.type}</div>
              <div className="text-[11px] text-slate-400">@{p.page_username}</div></div></div>
            <div className="text-xs text-slate-300 shrink-0">{jDate(p.publish_at)} · {jTime(p.publish_at)}</div></div>)}
          {!d.upcoming.length&&<div className="text-xs text-slate-500 py-4 text-center">انتشار زمان‌بندی‌شده‌ای ندارید</div>}
        </div>
        <Link to="/orders/new"><Button variant="outline" className="w-full mt-4">+ ثبت سفارش جدید</Button></Link>
      </Card>
    </div>
  </div>);
}

/* ═══════════ ۱۲) پیج‌ها ═══════════ */
function Pages(){
  const [rows,setRows]=useState(null); const [open,setOpen]=useState(false); const [busy,setBusy]=useState(false);
  const [f,setF]=useState({username:'',title:'',category:'سایر'});
  const load=()=>api.get('/pages').then(setRows).catch(()=>setRows([]));
  useEffect(()=>{ load(); },[]);
  const add=async e=>{ e.preventDefault(); setBusy(true);
    try{ await api.post('/pages',f); toast('پیج ثبت شد'); setOpen(false); setF({username:'',title:'',category:'سایر'}); load(); }
    catch(err){ toast(err.message,'error'); } finally{ setBusy(false); } };
  const del=async id=>{ if(!confirm('پیج حذف شود؟')) return;
    try{ await api.del('/pages/'+id); toast('حذف شد'); load(); }catch(err){ toast(err.message,'error'); } };
  if(rows===null) return <div className="flex justify-center py-20"><Spinner/></div>;
  return (<div>
    <PageTitle title="پیج‌های اینستاگرام" sub="پیج‌هایی که تیم ادمین‌یار مدیریت می‌کند">
      <Button onClick={()=>setOpen(true)}><Ic n="plus"/>افزودن پیج</Button></PageTitle>
    {rows.length?<div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
      {rows.map(p=><Card key={p.id} className="p-5 hover:border-cyan-400/25 transition">
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <div className="w-11 h-11 rounded-2xl bg-gradient-to-br from-violet-600/40 to-cyan-400/30 flex items-center justify-center"><Ic n="instagram" c="w-5 h-5 text-cyan-300"/></div>
            <div><div className="font-medium">{p.title}</div><div className="text-xs text-slate-400" dir="ltr">@{p.username}</div></div></div>
          <button onClick={()=>del(p.id)} className="p-2 rounded-lg text-slate-500 hover:text-rose-300 hover:bg-rose-500/10 transition"><Ic n="trash"/></button>
        </div>
        <div className="flex items-center justify-between mt-4 text-xs text-slate-400">
          <span>{p.category}</span><span className="flex items-center gap-1"><Ic n="clipboard" c="w-3.5 h-3.5"/>{faNum(p.orders_count)} سفارش</span></div>
      </Card>)}
    </div>:<Card><Empty text="هنوز پیژی ثبت نکرده‌اید؛ اولین پیج را اضافه کنید"/></Card>}
    <Modal open={open} onClose={()=>setOpen(false)} title="افزودن پیج اینستاگرام">
      <form onSubmit={add} className="space-y-4">
        <Input label="نام کاربری اینستاگرام" dir="ltr" required placeholder="your_page" value={f.username} onChange={e=>setF({...f,username:e.target.value})}/>
        <Input label="نام نمایشی" placeholder="مثلاً: کافه ستاره" value={f.title} onChange={e=>setF({...f,title:e.target.value})}/>
        <Select label="دسته‌بندی" value={f.category} onChange={e=>setF({...f,category:e.target.value})}>
          {['فروشگاه','خدمات','شخصی','تولید محتوا','آموزش','سایر'].map(c=><option key={c}>{c}</option>)}</Select>
        <Button className="w-full" loading={busy} type="submit">ثبت پیج</Button>
      </form></Modal>
  </div>);
}

/* ═══════════ ۱۳) آپلود چندفایلی با درصد پیشرفت ═══════════ */
function Upload(){
  const inputRef=useRef(null);
  const [pages,setPages]=useState([]); const [pageId,setPageId]=useState('');
  const [limitMb,setLimitMb]=useState(100); const [kind,setKind]=useState('story');
  const [items,setItems]=useState([]); const [drag,setDrag]=useState(false); const [busy,setBusy]=useState(false);
  useEffect(()=>{
    api.get('/pages').then(r=>{ setPages(r); if(r[0]) setPageId(r[0].id); }).catch(()=>{});
    api.get('/subscriptions/me').then(r=>setLimitMb((r.current&&r.current.max_file_size_mb)||100)).catch(()=>{});
  },[]);
  const upd=(id,patch)=>setItems(l=>l.map(x=>x.id===id?{...x,...patch}:x));
  const addFiles=list=>{
    const ok=[...list].filter(fl=>{ if(fl.size>limitMb*1048576){ toast('«'+fl.name+'» بزرگ‌تر از سقف '+faNum(limitMb)+' مگابایت است','error'); return false; } return true; });
    if(ok.length) setItems(prev=>[...prev,...ok.map(fl=>({id:uid(),file:fl,desc:'',progress:0,status:'ready'}))]);
  };
  const start=async()=>{
    if(!pageId) return toast('ابتدا پیج مقصد را انتخاب کنید','error');
    const queue=items.filter(x=>x.status==='ready');
    if(!queue.length) return toast('فایلی برای آپلود انتخاب نشده','error');
    setBusy(true);
    const worker=async()=>{
      while(queue.length){
        const it=queue.shift(); upd(it.id,{status:'uploading',progress:0});
        try{
          const fd=new FormData();
          fd.append('file',it.file); fd.append('kind',kind); fd.append('pageId',pageId); fd.append('description',it.desc||'');
          await uploadXHR(fd,p=>upd(it.id,{progress:p}));
          upd(it.id,{status:'done',progress:100});
        }catch(err){ upd(it.id,{status:'error',msg:err.message}); }
      }
    };
    await Promise.all([worker(),worker(),worker()]);
    setBusy(false); toast('فرآیند آپلود تمام شد');
  };
  const accept= kind==='reel'||kind==='raw_video' ? 'video/*' : kind==='post' ? 'image/*' : 'image/*,video/*';
  const readyCount=items.filter(x=>x.status==='ready').length;
  return (<div>
    <PageTitle title="آپلود محتوا" sub={'حداکثر حجم هر فایل: '+faNum(limitMb)+' مگابایت — چند فایل هم‌زمان'}/>
    <div className="grid md:grid-cols-2 gap-4 mb-5">
      <Select label="پیج مقصد" value={pageId} onChange={e=>setPageId(e.target.value)}>
        {pages.map(p=><option key={p.id} value={p.id}>@{p.username} — {p.title}</option>)}</Select>
      <Select label="نوع محتوا" value={kind} onChange={e=>setKind(e.target.value)}>
        {['story','post','reel','raw_video'].map(k=><option key={k} value={k}>{FILE_KINDS[k]}</option>)}</Select>
    </div>
    <div onClick={()=>inputRef.current&&inputRef.current.click()}
      onDragOver={e=>{e.preventDefault();setDrag(true);}} onDragLeave={()=>setDrag(false)}
      onDrop={e=>{e.preventDefault();setDrag(false);addFiles(e.dataTransfer.files);}}
      className={'border-2 border-dashed rounded-2xl p-10 text-center cursor-pointer transition mb-5 '+(drag?'border-cyan-400 bg-cyan-400/10':'border-white/15 hover:border-cyan-400/50 hover:bg-white/[.03]')}>
      <Ic n="upload" c="w-10 h-10 mx-auto text-cyan-400"/>
      <div className="mt-3 text-sm font-medium">فایل‌ها را اینجا رها کنید یا کلیک کنید</div>
      <div className="text-xs text-slate-400 mt-1">{FILE_KINDS[kind]} — انتخاب چندگانه پشتیبانی می‌شود</div>
      <input ref={inputRef} type="file" multiple accept={accept} className="hidden" onChange={e=>{addFiles(e.target.files); e.target.value='';}}/>
    </div>
    <div className="space-y-3">
      {items.map(it=><Card key={it.id} className="p-4">
        <div className="flex flex-wrap items-center gap-3">
          <Ic n={it.file.type.indexOf('video')===0?'video':'image'} c="w-8 h-8 text-cyan-300"/>
          <div className="flex-1 min-w-[200px]">
            <div className="text-sm truncate">{it.file.name}</div>
            <div className="text-xs text-slate-400">{fmtSize(it.file.size)} · {FILE_KINDS[kind]}</div>
            {it.status==='ready'&&<Input className="mt-2" placeholder="توضیح این فایل (اختیاری)" value={it.desc} onChange={e=>upd(it.id,{desc:e.target.value})}/>}
          </div>
          <div className="w-full sm:w-44">
            {it.status==='done'?<span className="text-emerald-300 text-sm flex items-center gap-1.5"><Ic n="check" c="w-4 h-4"/>آپلود شد</span>
            :it.status==='error'?<span className="text-rose-300 text-xs">{it.msg}</span>
            :<React.Fragment>
              <div className="h-1.5 bg-white/10 rounded-full overflow-hidden">
                <div className="h-full bg-gradient-to-l from-violet-500 to-cyan-400 transition-all" style={{width:it.progress+'%'}}></div></div>
              <div className="text-[11px] text-slate-400 mt-1">{it.status==='uploading'?'در حال آپلود '+faNum(it.progress)+'٪':'آماده آپلود'}</div>
            </React.Fragment>}
          </div>
        </div></Card>)}
    </div>
    <div className="mt-5 flex flex-wrap gap-3">
      <Button onClick={start} loading={busy} disabled={!readyCount}><Ic n="upload"/>شروع آپلود ({faNum(readyCount)} فایل)</Button>
      {items.some(x=>x.status==='done')&&<Link to="/orders/new"><Button variant="outline">ثبت سفارش با این فایل‌ها</Button></Link>}
    </div>
  </div>);
}

/* ═══════════ ۱۴) ثبت سفارش ═══════════ */
function NewOrder(){
  const [pages,setPages]=useState([]); const [files,setFiles]=useState([]);
  const [sel,setSel]=useState({}); const [busy,setBusy]=useState(false);
  const [f,setF]=useState({pageId:'',type:'edit_video',title:'',description:''});
  useEffect(()=>{
    api.get('/pages').then(r=>{ setPages(r); if(r[0]) setF(p=>({...p,pageId:r[0].id})); }).catch(()=>{});
    api.get('/uploads?kinds=story,post,reel,raw_video').then(setFiles).catch(()=>{});
  },[]);
  const toggle=id=>setSel(s=>{ const n={...s}; n[id]=!n[id]; return n; });
  const selected=Object.keys(sel).filter(k=>sel[k]);
  const submit=async e=>{ e.preventDefault();
    if(!selected.length) return toast('حداقل یک فایل انتخاب کنید','error');
    setBusy(true);
    try{ const r=await api.post('/orders',{...f,fileIds:selected});
      toast('سفارش ثبت شد و به تیم رسید ✅'); go('/orders/'+r.id); }
    catch(err){ toast(err.message,'error'); } finally{ setBusy(false); } };
  return (<div>
    <PageTitle title="ثبت سفارش جدید" sub="فایل‌های آپلودشده را انتخاب و درخواست خود را ثبت کنید"/>
    {!pages.length&&<Card className="p-5 mb-5 border-amber-400/30 text-amber-200 text-sm">ابتدا در «پیج‌های من» یک پیج ثبت کنید.</Card>}
    <form onSubmit={submit} className="space-y-5">
      <div className="grid md:grid-cols-2 gap-4">
        <Select label="پیج" required value={f.pageId} onChange={e=>setF({...f,pageId:e.target.value})}>
          {pages.map(p=><option key={p.id} value={p.id}>@{p.username}</option>)}</Select>
        <Select label="نوع سفارش" value={f.type} onChange={e=>setF({...f,type:e.target.value})}>
          {Object.keys(ORDER_TYPES).map(k=><option key={k} value={k}>{ORDER_TYPES[k]}</option>)}</Select>
      </div>
      <Input label="عنوان سفارش" required placeholder="مثلاً: تدوین ریلز معرفی محصول جدید" value={f.title} onChange={e=>setF({...f,title:e.target.value})}/>
      <Ta label="توضیحات (سبک تدوین، موسیقی، متن کپشن و...)" value={f.description} onChange={e=>setF({...f,description:e.target.value})}/>
      <div>
        <div className="text-xs text-slate-400 mb-2">فایل‌های شما ({faNum(files.length)} — برای انتخاب کلیک کنید)</div>
        {files.length?<div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {files.map(fl=>{
            const on=!!sel[fl.id];
            return <button type="button" key={fl.id} onClick={()=>toggle(fl.id)}
              className={'text-right rounded-xl border p-3 transition flex items-center gap-3 '+(on?'border-cyan-400/60 bg-cyan-400/10 shadow-neon':'border-white/10 bg-navy-800/60 hover:border-white/25')}>
              <Ic n={fl.mime.indexOf('video')===0?'video':'image'} c={'w-6 h-6 shrink-0 '+(on?'text-cyan-300':'text-slate-400')}/>
              <div className="min-w-0"><div className="text-xs truncate">{fl.original_name}</div>
              <div className="text-[10px] text-slate-400">{FILE_KINDS[fl.kind]} · {fmtSize(fl.size)}</div></div>
            </button>; })}
        </div>:<Card className="p-5 text-sm text-slate-400">فایلی آپلود نکرده‌اید. به <Link to="/upload" className="text-cyan-300 underline">صفحه آپلود</Link> بروید.</Card>}
      </div>
      <Button type="submit" loading={busy} className="min-w-44">ثبت سفارش</Button>
    </form>
  </div>);
}

/* ═══════════ ۱۵) لیست سفارش‌های مشتری ═══════════ */
function Orders(){
  const [rows,setRows]=useState(null);
  useEffect(()=>{ api.get('/orders').then(setRows).catch(()=>setRows([])); },[]);
  if(rows===null) return <div className="flex justify-center py-20"><Spinner/></div>;
  return (<div>
    <PageTitle title="سفارش‌های من" sub="پیگیری وضعیت تمام سفارش‌ها">
      <Button onClick={()=>go('/orders/new')}><Ic n="plus"/>سفارش جدید</Button></PageTitle>
    {rows.length?<div className="space-y-3">
      {rows.map(o=><Link key={o.id} to={'/orders/'+o.id}><Card className="p-4 hover:border-cyan-400/30 transition group">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="min-w-0">
            <div className="font-medium group-hover:text-cyan-300 transition truncate">{o.title}</div>
            <div className="text-xs text-slate-400 mt-0.5">{ORDER_TYPES[o.type]||o.type}{o.page_username?' · @'+o.page_username:''} · {jDate(o.created_at)}</div></div>
          <div className="flex items-center gap-3"><Badge s={o.status}/><Ic n="chevL" c="w-4 h-4 text-slate-500"/></div>
        </div></Card></Link>)}
    </div>:<Card><Empty text="سفارشی ثبت نکرده‌اید"/></Card>}
  </div>);
}

/* ═══════════ ۱۶) جزئیات سفارش (مشتری/ادمین/کارشناس) ═══════════ */
function OrderDetail({id,admin}){
  const {user}=useAuth();
  const [o,setO]=useState(null); const [experts,setExperts]=useState([]);
  const [modal,setModal]=useState(null); const [form,setForm]=useState({});
  const load=()=>api.get('/orders/'+id).then(setO).catch(e=>toast(e.message,'error'));
  useEffect(()=>{ load();
    if(user&&['super_admin','content_admin'].includes(user.role))
      api.get('/admin/experts').then(r=>setExperts(r.filter(x=>['editor','designer'].includes(x.role)))).catch(()=>{});
  },[]);
  if(!o) return <div className="flex justify-center py-24"><Spinner/></div>;
  const isOwner=o.user_id===user.id;
  const isExpert=['editor','designer'].includes(user.role)&&o.assigned_to===user.id;
  const isBoss=['super_admin','content_admin'].includes(user.role);
  const act=async(fn,msg)=>{ try{ await fn(); toast(msg); load(); }catch(e){ toast(e.message,'error'); } };
  const submitModal=async()=>{
    if(modal==='assign') await act(()=>api.post('/admin/orders/'+o.id+'/assign',{expertId:form.expertId}),'به کارشناس اختصاص یافت');
    if(modal==='reject') await act(()=>api.post('/admin/orders/'+o.id+'/reject',{note:form.note}),'سفارش رد شد');
    if(modal==='revision') await act(()=>api.post('/orders/'+o.id+'/revision',{note:form.note}),'درخواست اصلاح ارسال شد');
    if(modal==='schedule') await act(()=>api.post('/orders/'+o.id+'/schedule',{publishAt:form.publishAt,caption:form.caption}),'زمان‌بندی ثبت شد');
    setModal(null);
  };
  const onDeliver=async e=>{
    const fl=e.target.files&&e.target.files[0]; if(!fl) return;
    try{
      const fd=new FormData(); fd.append('file',fl); fd.append('kind','deliverable'); fd.append('orderId',o.id); fd.append('description','خروجی نهایی');
      const r=await uploadXHR(fd);
      await api.post('/orders/'+o.id+'/status',{status:'delivered',deliverableFileId:r.id});
      toast('خروجی برای مشتری ارسال شد'); load();
    }catch(err){ toast(err.message,'error'); }
  };
  const logLabel=l=>({create:'ثبت سفارش',assign:'تخصیص کارشناس',reject:'رد سفارش',completed:'تکمیل سفارش'}[l.action]||(ORDER_STATUS[l.action]&&ORDER_STATUS[l.action].label)||l.action);
  return (<div>
    <PageTitle title={o.title} sub={(ORDER_TYPES[o.type]||o.type)+(o.page_username?' · @'+o.page_username:'')+' · '+jDate(o.created_at)}>
      <Badge s={o.status}/></PageTitle>
    {(isBoss||isOwner||isExpert)&&<div className="flex flex-wrap gap-2 mb-5">
      {isBoss&&['pending','assigned'].includes(o.status)&&<Button variant="outline" onClick={()=>{setForm({expertId:experts[0]?experts[0].id:''});setModal('assign');}}><Ic n="usercog"/>تخصیص به کارشناس</Button>}
      {isBoss&&o.status==='pending'&&<Button variant="danger" onClick={()=>{setForm({note:''});setModal('reject');}}><Ic n="shieldx"/>رد سفارش</Button>}
      {isOwner&&o.status==='pending'&&<Button variant="ghost" onClick={()=>act(()=>api.post('/orders/'+o.id+'/cancel'),'سفارش لغو شد')}>لغو سفارش</Button>}
      {isOwner&&o.status==='delivered'&&<React.Fragment>
        <Button variant="success" onClick={()=>act(()=>api.post('/orders/'+o.id+'/approve'),'محتوا تأیید شد')}><Ic n="check"/>تأیید محتوا</Button>
        <Button variant="outline" onClick={()=>{setForm({note:''});setModal('revision');}}><Ic n="refresh"/>درخواست اصلاح</Button>
      </React.Fragment>}
      {isOwner&&['approved','scheduled'].includes(o.status)&&<Button onClick={()=>{setForm({publishAt:toLocalInput(new Date(Date.now()+3600000)),caption:(o.post&&o.post.caption)||''});setModal('schedule');}}>
        <Ic n="calendar"/>{o.status==='scheduled'?'ویرایش زمان‌بندی':'زمان‌بندی انتشار'}</Button>}
      {(isExpert||isBoss)&&o.status==='assigned'&&<Button onClick={()=>act(()=>api.post('/orders/'+o.id+'/status',{status:'in_progress'}),'شروع انجام ثبت شد')}>شروع انجام</Button>}
      {(isExpert||isBoss)&&['in_progress','revision_requested'].includes(o.status)&&
        <label className="cursor-pointer"><input type="file" className="hidden" onChange={onDeliver} accept="video/*,image/*"/>
        <Button as="span" variant="success"><Ic n="download"/>ارسال خروجی به مشتری</Button></label>}
      {isBoss&&o.post&&['scheduled','manual_ready'].includes(o.post.status)&&<React.Fragment>
        <Button variant="ghost" onClick={()=>act(()=>api.post('/calendar/'+o.post.id+'/manual-ready'),'اعلام انتشار دستی ارسال شد')}><Ic n="megaphone"/>اعلام انتشار دستی</Button>
        <Button variant="success" onClick={()=>act(()=>api.post('/calendar/'+o.post.id+'/publish'),'انتشار ثبت و سفارش تکمیل شد')}><Ic n="send"/>ثبت انجام انتشار</Button>
      </React.Fragment>}
    </div>}
    <div className="grid lg:grid-cols-2 gap-4">
      <div className="space-y-4">
        <Card className="p-5 space-y-3">
          <h2 className="font-bold">اطلاعات سفارش</h2>
          {admin&&<div className="text-sm text-slate-300">مشتری: <span className="text-cyan-300">{o.customer_name}</span> <span className="text-xs text-slate-500" dir="ltr">{o.customer_email}</span></div>}
          <div className="text-sm text-slate-300">کارشناس: {o.expert_name||<span className="text-slate-500">—</span>}</div>
          {o.description&&<div className="text-sm bg-white/5 rounded-xl p-3 leading-6">{o.description}</div>}
          {o.revision_note&&o.status==='revision_requested'&&<div className="text-sm bg-orange-500/10 border border-orange-400/30 text-orange-200 rounded-xl p-3">درخواست اصلاح: {o.revision_note}</div>}
        </Card>
        <Card className="p-5 space-y-3">
          <h2 className="font-bold">فایل‌های سفارش</h2>
          {o.files.map(fl=><div key={fl.id} className="flex items-center justify-between gap-3 bg-white/[.03] rounded-xl p-3">
            <div className="min-w-0"><div className="text-sm truncate">{fl.original_name}</div>
            <div className="text-[11px] text-slate-400">{FILE_KINDS[fl.kind]}{fl.description?' · '+fl.description:''}</div></div>
            <Button variant="ghost" className="!px-3 !py-1.5 shrink-0" onClick={()=>downloadFile(fl.id,fl.original_name).catch(e=>toast(e.message,'error'))}><Ic n="download"/>دریافت</Button>
          </div>)}
          {o.deliverable_file_id&&<div className="flex items-center justify-between gap-3 bg-emerald-500/10 border border-emerald-400/30 rounded-xl p-3">
            <div className="text-sm truncate text-emerald-200 min-w-0">🎬 خروجی نهایی: {o.deliverable_name}</div>
            <Button variant="success" className="!px-3 !py-1.5 shrink-0" onClick={()=>downloadFile(o.deliverable_file_id,o.deliverable_name).catch(e=>toast(e.message,'error'))}><Ic n="download"/>دانلود</Button>
          </div>}
        </Card>
        {o.post&&<Card className="p-5 space-y-2">
          <h2 className="font-bold">اطلاعات انتشار</h2>
          <div className="text-sm text-slate-300">زمان: {jDate(o.post.publish_at)} — {jTime(o.post.publish_at)}</div>
          {o.post.caption&&<div className="text-sm bg-white/5 rounded-xl p-3 whitespace-pre-wrap">{o.post.caption}</div>}
          <Badge s={o.post.status} map={SCHED_STATUS}/>
        </Card>}
      </div>
      <Card className="p-5">
        <h2 className="font-bold mb-4">تاریخچه سفارش</h2>
        {o.logs.map((l,i)=><div key={i} className="flex gap-3">
          <div className="flex flex-col items-center">
            <div className="w-2.5 h-2.5 rounded-full bg-cyan-400 shadow-neon mt-1.5"></div>
            {i<o.logs.length-1&&<div className="flex-1 w-px bg-white/10"></div>}
          </div>
          <div className="pb-5">
            <div className="text-sm">{logLabel(l)}</div>
            <div className="text-[11px] text-slate-400">{l.actor_name||'سیستم'} · {jDate(l.created_at)} {jTime(l.created_at)}</div>
            {l.note&&<div className="text-xs bg-white/5 rounded-lg px-2.5 py-1.5 mt-1.5 inline-block text-slate-300">{l.note}</div>}
          </div></div>)}
      </Card>
    </div>
    <Modal open={modal==='assign'} onClose={()=>setModal(null)} title="تخصیص به کارشناس">
      <div className="space-y-4">
        <Select label="کارشناس" value={form.expertId||''} onChange={e=>setForm({...form,expertId:e.target.value})}>
          {experts.map(x=><option key={x.id} value={x.id}>{x.full_name} — {x.role==='editor'?'تدوینگر':'طراح'}</option>)}</Select>
        <Button className="w-full" onClick={submitModal}>ثبت تخصیص</Button></div></Modal>
    <Modal open={modal==='reject'} onClose={()=>setModal(null)} title="رد سفارش">
      <div className="space-y-4"><Ta label="دلیل رد (برای مشتری ارسال می‌شود)" value={form.note||''} onChange={e=>setForm({...form,note:e.target.value})}/>
      <Button variant="danger" className="w-full" onClick={submitModal}>رد سفارش</Button></div></Modal>
    <Modal open={modal==='revision'} onClose={()=>setModal(null)} title="درخواست اصلاح">
      <div className="space-y-4"><Ta label="چه چیزی را اصلاح دهیم؟" value={form.note||''} onChange={e=>setForm({...form,note:e.target.value})}/>
      <Button className="w-full" onClick={submitModal}>ارسال درخواست</Button></div></Modal>
    <Modal open={modal==='schedule'} onClose={()=>setModal(null)} title="زمان‌بندی انتشار">
      <div className="space-y-4">
        <Input label="تاریخ و ساعت انتشار" type="datetime-local" value={form.publishAt||''} onChange={e=>setForm({...form,publishAt:e.target.value})}/>
        <Ta label="کپشن پیشنهادی (اختیاری)" value={form.caption||''} onChange={e=>setForm({...form,caption:e.target.value})}/>
        <Button className="w-full" onClick={submitModal}>ثبت زمان‌بندی</Button></div></Modal>
  </div>);
}

/* ═══════════ ۱۷) تقویم شمسی ═══════════ */
function CalendarPage({admin}){
  const {user}=useAuth();
  const now=Jal.toJal(new Date().getFullYear(),new Date().getMonth()+1,new Date().getDate());
  const [ym,setYm]=useState({jy:now.jy,jm:now.jm});
  const [posts,setPosts]=useState(null);
  const [selKey,setSelKey]=useState(dayKey(new Date()));
  const [edit,setEdit]=useState(null);
  const grid=useMemo(()=>monthGrid(ym.jy,ym.jm),[ym]);
  const load=()=>{
    const from=grid[0].date.toISOString(), to=grid[41].date.toISOString();
    api.get('/calendar?from='+encodeURIComponent(from)+'&to='+encodeURIComponent(to)+(admin?'&all=1':''))
      .then(setPosts).catch(()=>setPosts([]));
  };
  useEffect(()=>{ load(); },[ym]);
  const byDay=useMemo(()=>{ const m={}; (posts||[]).forEach(p=>{ const k=dayKey(p.publish_at); (m[k]=m[k]||[]).push(p); }); return m; },[posts]);
  const prev=()=>setYm(s=>s.jm===1?{jy:s.jy-1,jm:12}:{jy:s.jy,jm:s.jm-1});
  const next=()=>setYm(s=>s.jm===12?{jy:s.jy+1,jm:1}:{jy:s.jy,jm:s.jm+1});
  const act=async(fn,msg)=>{ try{ await fn(); toast(msg); load(); }catch(e){ toast(e.message,'error'); } };
  const saveEdit=async()=>{
    try{ await api.patch('/calendar/'+edit.id,{publishAt:edit.publishAt,caption:edit.caption}); toast('زمان‌بندی به‌روزرسانی شد'); setEdit(null); load(); }
    catch(e){ toast(e.message,'error'); } };
  if(posts===null) return <div className="flex justify-center py-20"><Spinner/></div>;
  const isBoss=['super_admin','content_admin'].includes(user.role);
  return (<div>
    <PageTitle title={admin?'تقویم انتشار (مدیریت)':'تقویم محتوایی'} sub="تاریخ و ساعت انتشار محتوا را مدیریت کنید">
      <div className="flex items-center gap-2">
        <Button variant="ghost" className="!px-3" onClick={prev}><Ic n="chevR"/></Button>
        <div className="font-bold min-w-32 text-center">{MONTHS[ym.jm-1]} {faDigits(ym.jy)}</div>
        <Button variant="ghost" className="!px-3" onClick={next}><Ic n="chevL"/></Button>
      </div></PageTitle>
    <div className="grid lg:grid-cols-3 gap-4">
      <Card className="lg:col-span-2 p-3 md:p-4">
        <div className="grid grid-cols-7 gap-1.5 mb-2">
          {WEEKDAYS.map((w,i)=><div key={i} className="text-center text-[11px] text-slate-400 py-1">{w}</div>)}</div>
        <div className="grid grid-cols-7 gap-1.5">
          {grid.map((cell,i)=>{
            const list=byDay[cell.key]||[];
            const today=cell.key===dayKey(new Date());
            return <button key={i} onClick={()=>setSelKey(cell.key)}
              className={'aspect-square md:aspect-[4/3] rounded-xl border p-1.5 text-right transition min-w-0 '+
                (cell.inMonth?'bg-white/[.03] border-white/10 hover:border-cyan-400/40 ':'opacity-30 ')+
                (selKey===cell.key?'!border-cyan-400/70 bg-cyan-400/10 ':'')+
                (today?'ring-1 ring-violet-400/60':'')}>
              <div className={'text-[11px] md:text-xs '+(today?'text-violet-300 font-bold':'')}>{faDigits(cell.jd)}</div>
              <div className="mt-1 space-y-0.5">
                {list.slice(0,2).map(p=><div key={p.id} className={'h-1.5 rounded-full '+(SCHED_STATUS[p.status]?SCHED_STATUS[p.status].dot:'bg-sky-400')}></div>)}
                {list.length>2&&<div className="text-[9px] text-slate-400">+{faDigits(list.length-2)}</div>}
              </div></button>;
          })}
        </div>
      </Card>
      <Card className="p-4 h-fit">
        <h2 className="font-bold mb-3">{(()=>{ const c=grid.find(x=>x.key===selKey); return c?jDate(c.date):''; })()}</h2>
        <div className="space-y-2">
          {(byDay[selKey]||[]).length?byDay[selKey].map(p=><div key={p.id} className="bg-white/[.04] rounded-xl p-3 space-y-2">
            <div className="flex items-center justify-between gap-2">
              <div className="text-sm font-medium truncate">{p.order_title||p.type}</div><Badge s={p.status} map={SCHED_STATUS}/></div>
            <div className="text-[11px] text-slate-400 flex items-center gap-1"><Ic n="clock" c="w-3 h-3"/>{jTime(p.publish_at)} · @{p.page_username}{admin&&p.customer_name?' · '+p.customer_name:''}</div>
            {p.caption&&<div className="text-xs text-slate-400 line-clamp-2">{p.caption}</div>}
            <div className="flex flex-wrap gap-1.5 pt-1">
              {(p.user_id===user.id||isBoss)&&p.status!=='published'&&
                <Button variant="ghost" className="!px-2.5 !py-1 !text-[11px]" onClick={()=>setEdit({id:p.id,publishAt:toLocalInput(p.publish_at),caption:p.caption||''})}><Ic n="pencil" c="w-3 h-3"/>جابه‌جایی</Button>}
              {p.user_id===user.id&&p.status==='scheduled'&&
                <Button variant="danger" className="!px-2.5 !py-1 !text-[11px]" onClick={()=>act(()=>api.del('/calendar/'+p.id),'حذف شد')}><Ic n="trash" c="w-3 h-3"/>حذف</Button>}
              {isBoss&&p.status==='scheduled'&&
                <Button variant="ghost" className="!px-2.5 !py-1 !text-[11px]" onClick={()=>act(()=>api.post('/calendar/'+p.id+'/manual-ready'),'اعلام انتشار دستی شد')}><Ic n="megaphone" c="w-3 h-3"/>انتشار دستی</Button>}
              {isBoss&&['scheduled','manual_ready'].includes(p.status)&&
                <Button variant="success" className="!px-2.5 !py-1 !text-[11px]" onClick={()=>act(()=>api.post('/calendar/'+p.id+'/publish'),'انتشار ثبت شد')}>ثبت انتشار</Button>}
            </div></div>)
          :<div className="text-xs text-slate-500 py-6 text-center">برای این روز محتوایی زمان‌بندی نشده</div>}
        </div>
      </Card>
    </div>
    <Modal open={!!edit} onClose={()=>setEdit(null)} title="جابه‌جایی تاریخ و ساعت انتشار">
      {edit&&<div className="space-y-4">
        <Input label="تاریخ و ساعت" type="datetime-local" value={edit.publishAt} onChange={e=>setEdit({...edit,publishAt:e.target.value})}/>
        <Ta label="کپشن" value={edit.caption} onChange={e=>setEdit({...edit,caption:e.target.value})}/>
        <Button className="w-full" onClick={saveEdit}>ذخیره تغییرات</Button></div>}
    </Modal>
  </div>);
}

/* ═══════════ ۱۸) اشتراک و پرداخت ═══════════ */
function Subscription({query}){
  const [me,setMe]=useState(null); const [plans,setPlans]=useState([]); const [gw,setGw]=useState(false);
  const [busy,setBusy]=useState(null);
  const load=()=>api.get('/subscriptions/me').then(setMe).catch(()=>{});
  useEffect(()=>{
    load();
    api.get('/plans').then(setPlans).catch(()=>{});
    api.get('/config').then(c=>setGw(c.gatewayEnabled)).catch(()=>{});
    if(query.get('pay')==='success') toast('پرداخت با موفقیت انجام شد 🎉');
    if(query.get('pay')==='fail') toast('پرداخت انجام نشد یا لغو شد','error');
  },[]);
  if(!me) return <div className="flex justify-center py-20"><Spinner/></div>;
  const cur=me.current;
  const daysLeft=cur&&cur.status==='active'?Math.max(0,Math.ceil((new Date(cur.expires_at)-Date.now())/86400000)):0;
  const buyGateway=async plan=>{ setBusy('g'+plan.id);
    try{ const r=await api.post('/subscriptions/checkout',{planId:plan.id}); location.href=r.redirectUrl; }
    catch(e){ toast(e.message,'error'); setBusy(null); } };
  const buyManual=async plan=>{ setBusy('m'+plan.id);
    try{ await api.post('/subscriptions/request-manual',{planId:plan.id}); toast('درخواست ثبت شد؛ پس از واریز، ادمین تأیید می‌کند'); load(); }
    catch(e){ toast(e.message,'error'); } setBusy(null); };
  return (<div>
    <PageTitle title="اشتراک" sub="خرید یا تمدید پلن؛ قیمت‌ها از پنل مدیریت تنظیم می‌شوند"/>
    <Card className="p-5 mb-6 border-cyan-400/20">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div><div className="font-bold flex items-center gap-2 flex-wrap">وضعیت فعلی:
          {cur?<span className={'inline-flex rounded-full border border-white/10 px-2.5 py-0.5 text-[11px] '+(SUB_BADGE[cur.status]||'')}>
            {cur.plan_title} — {cur.status==='active'?'فعال':cur.status==='expired'?'منقضی':cur.status}</span>
          :<span className="text-slate-400 text-sm">بدون اشتراک</span>}</div>
          {cur&&cur.status==='active'&&<div className="text-xs text-slate-400 mt-1">{faNum(daysLeft)} روز باقی‌مانده · پایان: {jDate(cur.expires_at)}</div>}
        </div>
        {cur&&cur.status==='active'&&<div className="w-full sm:w-56 h-1.5 bg-white/10 rounded-full overflow-hidden">
          <div className="h-full bg-gradient-to-l from-violet-500 to-cyan-400" style={{width:Math.min(100,(daysLeft/cur.duration_days)*100)+'%'}}></div></div>}
      </div>
    </Card>
    <div className="grid md:grid-cols-3 gap-4">
      {plans.map(p=>{
        const isCurrent=cur&&cur.plan_id===p.id&&cur.status==='active';
        const usedTrial=p.code==='trial'&&me.hadTrial;
        return <Card key={p.id} className={'p-5 flex flex-col relative overflow-hidden '+(p.code==='pro'?'border-violet-400/50 shadow-glow':'')}>
          {p.code==='pro'&&<div className="absolute top-0 inset-x-0 h-1 bg-gradient-to-l from-violet-500 to-cyan-400"></div>}
          <div className="font-bold text-lg flex items-center gap-2">{p.code==='pro'&&<Ic n="sparkles" c="w-4 h-4 text-violet-300"/>}{p.title}</div>
          <div className="mt-2 text-2xl font-extrabold bg-gradient-to-l from-cyan-300 to-violet-300 bg-clip-text text-transparent">
            {p.price_toman===0?'رایگان':faNum(p.price_toman)+' تومان'}</div>
          <div className="text-xs text-slate-400 mt-1">{faNum(p.duration_days)} روزه</div>
          <ul className="mt-4 space-y-2 flex-1">
            {(Array.isArray(p.features)?p.features:[]).map((fx,i)=><li key={i} className="flex items-start gap-2 text-sm text-slate-300">
              <Ic n="check" c="w-4 h-4 text-emerald-400 shrink-0 mt-0.5"/>{fx}</li>)}
          </ul>
          <div className="mt-5 space-y-2">
            {gw&&!isCurrent&&!usedTrial&&<Button className="w-full" variant={p.code==='pro'?'primary':'outline'} loading={busy==='g'+p.id} onClick={()=>buyGateway(p)}>
              <Ic n="credit"/>پرداخت آنلاین {cur&&cur.status==='active'?'(تمدید)':''}</Button>}
            {!isCurrent&&!usedTrial&&<Button className="w-full" variant="ghost" loading={busy==='m'+p.id} onClick={()=>buyManual(p)}>
              <Ic n="send"/>ثبت درخواست (پرداخت دستی)</Button>}
            {isCurrent&&<Button className="w-full" disabled>پلن فعلی شما</Button>}
            {usedTrial&&<Button className="w-full" disabled>آزمایشی استفاده شده</Button>}
          </div>
        </Card>; })}
    </div>
    {me.payments&&me.payments.length>0&&<div className="mt-6">
      <h2 className="font-bold mb-3">درخواست‌های پرداخت</h2>
      <Card className="divide-y divide-white/5">
        {me.payments.map(pa=><div key={pa.id} className="flex flex-wrap items-center justify-between gap-2 p-4">
          <div className="text-sm">{pa.plan_title} · {faNum(pa.amount)} تومان</div>
          <div className="text-xs text-slate-400">{pa.method==='manual'?'پرداخت دستی':'درگاه آنلاین'} · {jDate(pa.created_at)}</div>
          <Badge s={pa.status} map={PAY_STATUS}/></div>)}
      </Card></div>}
    <div className="mt-6">
      <h2 className="font-bold mb-3">تاریخچه اشتراک‌ها</h2>
      <Card className="divide-y divide-white/5">
        {me.history.map(h=><div key={h.id} className="flex flex-wrap items-center justify-between gap-2 p-4">
          <div className="text-sm">{h.plan_title}</div>
          <div className="text-xs text-slate-400">{jDate(h.starts_at)} تا {jDate(h.expires_at)}</div>
          <span className={'inline-flex rounded-full border border-white/10 px-2.5 py-0.5 text-[11px] '+(SUB_BADGE[h.status]||'')}>
            {h.status==='active'?'فعال':h.status==='expired'?'منقضی':h.status}</span></div>)}
        {!me.history.length&&<div className="p-6 text-center text-sm text-slate-500">سابقه‌ای وجود ندارد</div>}
      </Card>
    </div>
  </div>);
}

/* ═══════════ ۱۹) اعلان‌ها ═══════════ */
function Notifications(){
  const [data,setData]=useState(null);
  const load=()=>api.get('/notifications').then(setData).catch(()=>setData({rows:[],unread:0}));
  useEffect(()=>{ load(); },[]);
  const readAll=async()=>{ await api.post('/notifications/read-all'); toast('همه خوانده شد'); load(); };
  if(!data) return <div className="flex justify-center py-20"><Spinner/></div>;
  return (<div>
    <PageTitle title="اعلان‌ها" sub={data.unread?faNum(data.unread)+' خوانده‌نشده':''}>
      <Button variant="ghost" onClick={readAll} disabled={!data.unread}>خواندن همه</Button></PageTitle>
    <div className="space-y-2">
      {data.rows.length?data.rows.map(n=><Card key={n.id} className={'p-4 flex gap-3 '+(!n.read?'border-cyan-400/30 bg-cyan-400/[.04]':'')}>
        <div className="w-9 h-9 rounded-xl bg-violet-600/20 flex items-center justify-center shrink-0"><Ic n="bell" c="w-4 h-4 text-cyan-300"/></div>
        <div className="min-w-0 flex-1"><div className="text-sm font-medium">{n.title}</div>
          {n.body&&<div className="text-xs text-slate-400 mt-1">{n.body}</div>}
          <div className="text-[10px] text-slate-500 mt-1">{jDate(n.created_at)} · {jTime(n.created_at)}</div></div>
        {!n.read&&<span className="w-2 h-2 rounded-full bg-cyan-400 shrink-0 mt-2"></span>}
      </Card>):<Card><Empty text="اعلانی ندارید"/></Card>}
    </div>
  </div>);
}

/* ═══════════ ۲۰) پنل مدیریت ═══════════ */
function AdminDashboard(){
  const [d,setD]=useState(null);
  useEffect(()=>{ api.get('/admin/stats').then(setD).catch(()=>{}); },[]);
  if(!d) return <div className="flex justify-center py-20"><Spinner/></div>;
  const cards=[
    {l:'مشتریان',v:faNum(d.users),i:'users'},{l:'اشتراک‌های فعال',v:faNum(d.active_subs),i:'credit'},
    {l:'سفارش‌های در انتظار',v:faNum(d.pending_orders),i:'clipboard'},{l:'درآمد (تومان)',v:faNum(d.revenue),i:'tag'}];
  return (<div>
    <PageTitle title="داشبورد مدیریت" sub="نمای کلی کسب‌وکار"/>
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-6">
      {cards.map(c=><Card key={c.l} className="p-4">
        <div className="flex items-center justify-between"><div className="text-[11px] text-slate-400">{c.l}</div><Ic n={c.i} c="w-4 h-4 text-cyan-400"/></div>
        <div className="text-2xl font-extrabold mt-2 bg-gradient-to-l from-cyan-300 to-violet-300 bg-clip-text text-transparent">{c.v}</div>
      </Card>)}
    </div>
    {d.pending_payments>0&&<Card className="p-4 mb-6 border-amber-400/30 bg-amber-500/5 flex items-center justify-between gap-3">
      <div className="text-sm text-amber-200">{faNum(d.pending_payments)} درخواست پرداخت در انتظار تأیید</div>
      <Link to="/admin/payments"><Button variant="outline" className="!py-1.5">بررسی</Button></Link></Card>}
    <Card className="p-5">
      <div className="flex items-center justify-between mb-3"><h2 className="font-bold">آخرین سفارش‌ها</h2>
      <Link to="/admin/orders" className="text-xs text-cyan-300 hover:underline">همه</Link></div>
      <div className="space-y-2">
        {d.recent.map(o=><Link key={o.id} to={'/admin/orders/'+o.id} className="flex flex-wrap items-center justify-between gap-2 p-2.5 rounded-xl hover:bg-white/5 transition">
          <div className="min-w-0"><div className="text-sm truncate">{o.title}</div>
          <div className="text-[11px] text-slate-400">{o.customer_name} · {ORDER_TYPES[o.type]||o.type} · {jDate(o.created_at)}</div></div>
          <Badge s={o.status}/></Link>)}
      </div></Card>
  </div>);
}

function AdminOrders(){
  const {user}=useAuth();
  const [rows,setRows]=useState(null); const [status,setStatus]=useState('');
  const [experts,setExperts]=useState([]); const [modal,setModal]=useState(null); const [form,setForm]=useState({});
  const isBoss=['super_admin','content_admin'].includes(user.role);
  const load=()=>api.get('/admin/orders'+(status?'?status='+status:'')).then(setRows).catch(()=>setRows([]));
  useEffect(()=>{ load();
    if(isBoss) api.get('/admin/experts').then(r=>setExperts(r.filter(x=>['editor','designer'].includes(x.role)))).catch(()=>{});
  },[status]);
  const doAction=async()=>{
    try{
      if(modal.type==='assign') await api.post('/admin/orders/'+modal.order.id+'/assign',{expertId:form.expertId});
      if(modal.type==='reject') await api.post('/admin/orders/'+modal.order.id+'/reject',{note:form.note});
      toast(modal.type==='assign'?'تخصیص انجام شد':'سفارش رد شد'); setModal(null); load();
    }catch(e){ toast(e.message,'error'); } };
  if(rows===null) return <div className="flex justify-center py-20"><Spinner/></div>;
  return (<div>
    <PageTitle title={isBoss?'مدیریت سفارش‌ها':'سفارش‌های من (کارشناس)'} sub="وضعیت، تخصیص و پیگیری"/>
    {isBoss&&<div className="flex flex-wrap gap-2 mb-4">
      <button onClick={()=>setStatus('')} className={'rounded-full border px-3 py-1 text-xs transition '+(!status?'bg-cyan-400/20 border-cyan-400/50 text-cyan-200':'border-white/10 text-slate-400 hover:text-white')}>همه</button>
      {Object.keys(ORDER_STATUS).map(k=><button key={k} onClick={()=>setStatus(k)}
        className={'rounded-full border px-3 py-1 text-xs transition '+(status===k?'bg-cyan-400/20 border-cyan-400/50 text-cyan-200':'border-white/10 text-slate-400 hover:text-white')}>{ORDER_STATUS[k].label}</button>)}
    </div>}
    <div className="space-y-2">
      {rows.length?rows.map(o=><Card key={o.id} className="p-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <Link to={'/admin/orders/'+o.id} className="min-w-0 flex-1 group">
            <div className="text-sm font-medium group-hover:text-cyan-300 transition truncate">{o.title}</div>
            <div className="text-[11px] text-slate-400 mt-0.5">{o.customer_name} · {ORDER_TYPES[o.type]||o.type}{o.page_username?' · @'+o.page_username:''} · {faNum(o.files_count)} فایل · {jDate(o.created_at)}</div>
          </Link>
          <div className="flex items-center gap-2 flex-wrap">
            {o.expert_name&&<span className="text-[11px] text-slate-300 bg-white/5 rounded-lg px-2 py-1">کارشناس: {o.expert_name}</span>}
            <Badge s={o.status}/>
            {isBoss&&['pending','assigned'].includes(o.status)&&
              <Button variant="outline" className="!px-3 !py-1.5 !text-xs" onClick={()=>{setForm({expertId:experts[0]?experts[0].id:''});setModal({type:'assign',order:o});}}><Ic n="usercog" c="w-3.5 h-3.5"/>تخصیص</Button>}
            {isBoss&&o.status==='pending'&&
              <Button variant="danger" className="!px-3 !py-1.5 !text-xs" onClick={()=>{setForm({note:''});setModal({type:'reject',order:o});}}>رد</Button>}
            <Link to={'/admin/orders/'+o.id} className="p-2 text-slate-500 hover:text-cyan-300 transition"><Ic n="chevL" c="w-4 h-4"/></Link>
          </div></div></Card>)
      :<Card className="p-8 text-center text-sm text-slate-500">سفارشی در این وضعیت وجود ندارد</Card>}
    </div>
    <Modal open={!!modal} onClose={()=>setModal(null)} title={modal&&modal.type==='assign'?'تخصیص به کارشناس':'رد سفارش'}>
      {modal&&modal.type==='assign'?<div className="space-y-4">
        <Select label="کارشناس" value={form.expertId||''} onChange={e=>setForm({...form,expertId:e.target.value})}>
          {experts.map(x=><option key={x.id} value={x.id}>{x.full_name} — {x.role==='editor'?'تدوینگر':'طراح'}</option>)}</Select>
        <Button className="w-full" onClick={doAction}>ثبت تخصیص</Button></div>
      :<div className="space-y-4"><Ta label="دلیل رد" value={form.note||''} onChange={e=>setForm({...form,note:e.target.value})}/>
        <Button variant="danger" className="w-full" onClick={doAction}>رد سفارش</Button></div>}
    </Modal>
  </div>);
}

function AdminUsers(){
  const {user}=useAuth();
  const [rows,setRows]=useState(null); const [q,setQ]=useState('');
  const canBlock=['super_admin','content_admin'].includes(user.role);
  const load=query=>api.get('/admin/users?q='+encodeURIComponent(query||'')).then(setRows).catch(()=>setRows([]));
  useEffect(()=>{ load(''); },[]);
  const block=async u=>{ try{ await api.post('/admin/users/'+u.id+'/block',{blocked:!u.is_blocked});
    toast(u.is_blocked?'رفع مسدودی انجام شد':'کاربر مسدود شد'); load(q); }catch(e){ toast(e.message,'error'); } };
  if(rows===null) return <div className="flex justify-center py-20"><Spinner/></div>;
  return (<div>
    <PageTitle title="کاربران" sub={faNum(rows.length)+' مشتری'}>
      <Input placeholder="جستجوی نام یا ایمیل…" className="!w-56" value={q} onChange={e=>setQ(e.target.value)}
        onKeyDown={e=>{ if(e.key==='Enter') load(q); }}/></PageTitle>
    <Card className="overflow-x-auto">
      <table className="w-full text-sm min-w-[760px]">
        <thead><tr className="text-right text-[11px] text-slate-400 border-b border-white/10">
          <th className="p-4 font-medium">کاربر</th><th className="p-4 font-medium">پلن</th>
          <th className="p-4 font-medium">پایان اشتراک</th><th className="p-4 font-medium">سفارش‌ها</th>
          <th className="p-4 font-medium">ثبت‌نام</th>{canBlock&&<th className="p-4 font-medium">عملیات</th>}</tr></thead>
        <tbody className="divide-y divide-white/5">
          {rows.map(u=><tr key={u.id} className={u.is_blocked?'opacity-50':''}>
            <td className="p-4"><div className="font-medium">{u.full_name}</div><div className="text-xs text-slate-400" dir="ltr">{u.email}</div></td>
            <td className="p-4">{u.sub_status?<span className={'inline-flex rounded-full border border-white/10 px-2.5 py-0.5 text-[11px] '+(SUB_BADGE[u.sub_status]||'')}>
              {u.plan_title} · {u.sub_status==='active'?'فعال':u.sub_status==='expired'?'منقضی':u.sub_status}</span>
              :<span className="text-slate-500 text-xs">—</span>}</td>
            <td className="p-4 text-xs text-slate-300">{u.expires_at?jDate(u.expires_at):'—'}</td>
            <td className="p-4 text-xs">{faNum(u.orders_count)}</td>
            <td className="p-4 text-xs text-slate-400">{jDate(u.created_at)}</td>
            {canBlock&&<td className="p-4"><Button variant="ghost" className="!px-2.5 !py-1 !text-xs" onClick={()=>block(u)}>
              <Ic n={u.is_blocked?'shieldcheck':'shieldx'} c="w-3.5 h-3.5"/>{u.is_blocked?'رفع مسدودی':'مسدودسازی'}</Button></td>}
          </tr>)}
        </tbody></table>
    </Card>
  </div>);
}

function AdminPayments(){
  const {user}=useAuth();
  const [rows,setRows]=useState(null);
  const load=()=>api.get('/admin/payments').then(setRows).catch(()=>setRows([]));
  useEffect(()=>{ if(user.role==='super_admin') load(); else setRows([]); },[]);
  const act=async(id,kind)=>{ try{ await api.post('/admin/payments/'+id+'/'+kind); toast(kind==='confirm'?'پرداخت تأیید و اشتراک فعال شد':'رد شد'); load(); }catch(e){ toast(e.message,'error'); } };
  if(rows===null) return <div className="flex justify-center py-20"><Spinner/></div>;
  if(user.role!=='super_admin') return <Card><Empty text="دسترسی غیرمجاز"/></Card>;
  return (<div>
    <PageTitle title="مدیریت پرداخت‌ها" sub="تأیید پرداخت‌های دستی پس از واریز"/>
    <Card className="divide-y divide-white/5">
      {rows.length?rows.map(pa=><div key={pa.id} className="flex flex-wrap items-center justify-between gap-2 p-4">
        <div className="min-w-0">
          <div className="text-sm font-medium">{pa.user_name} — {pa.plan_title}</div>
          <div className="text-[11px] text-slate-400" dir="ltr">{pa.user_email}</div>
          <div className="text-[11px] text-slate-400 mt-0.5">{pa.method==='manual'?'پرداخت دستی':'درگاه آنلاین'} · {jDate(pa.created_at)}</div>
        </div>
        <div className="flex items-center gap-2 flex-wrap">
          <span className="text-sm font-bold text-cyan-300">{faNum(pa.amount)} تومان</span>
          <Badge s={pa.status} map={PAY_STATUS}/>
          {pa.status==='pending'&&<React.Fragment>
            <Button variant="success" className="!px-3 !py-1.5 !text-xs" onClick={()=>act(pa.id,'confirm')}><Ic n="check" c="w-3.5 h-3.5"/>تأیید واریز</Button>
            <Button variant="danger" className="!px-3 !py-1.5 !text-xs" onClick={()=>act(pa.id,'reject')}>رد</Button>
          </React.Fragment>}
        </div>
      </div>):<Empty text="پرداختی ثبت نشده"/>}
    </Card>
  </div>);
}

function AdminPlans(){
  const {user}=useAuth();
  const [plans,setPlans]=useState(null);
  const load=()=>api.get('/admin/plans').then(r=>setPlans(r.map(p=>({...p,featuresText:(p.features||[]).join('\n')})))).catch(()=>setPlans([]));
  useEffect(()=>{ if(user.role==='super_admin') load(); else setPlans([]); },[]);
  const setPlan=(i,patch)=>setPlans(l=>l.map((x,xi)=>xi===i?{...x,...patch}:x));
  const save=async p=>{ try{
    await api.put('/admin/plans/'+p.id,{title:p.title,price_toman:+p.price_toman,duration_days:+p.duration_days,
      max_pages:+p.max_pages,max_orders_per_period:+p.max_orders_per_period,max_file_size_mb:+p.max_file_size_mb,
      features:p.featuresText.split('\n').map(s=>s.trim()).filter(Boolean),is_active:p.is_active,sort:+p.sort});
    toast('پلن ذخیره شد');
  }catch(e){ toast(e.message,'error'); } };
  if(plans===null) return <div className="flex justify-center py-20"><Spinner/></div>;
  if(user.role!=='super_admin') return <Card><Empty text="دسترسی غیرمجاز"/></Card>;
  return (<div>
    <PageTitle title="پلن‌ها و قیمت‌گذاری" sub="قیمت، مدت و محدودیت‌ها بلافاصله اعمال می‌شوند"/>
    <div className="grid lg:grid-cols-3 gap-4">
      {plans.map((p,i)=><Card key={p.id} className="p-5 space-y-3">
        <div className="flex items-center justify-between">
          <Input className="!w-40" value={p.title} onChange={e=>setPlan(i,{title:e.target.value})}/>
          <label className="flex items-center gap-2 text-xs text-slate-300 cursor-pointer">
            <input type="checkbox" checked={p.is_active} onChange={e=>setPlan(i,{is_active:e.target.checked})} className="accent-cyan-400 w-4 h-4"/>فعال</label>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <Input label="قیمت (تومان)" type="number" dir="ltr" value={p.price_toman} onChange={e=>setPlan(i,{price_toman:e.target.value})}/>
          <Input label="مدت (روز)" type="number" dir="ltr" value={p.duration_days} onChange={e=>setPlan(i,{duration_days:e.target.value})}/>
          <Input label="حداکثر پیج" type="number" dir="ltr" value={p.max_pages} onChange={e=>setPlan(i,{max_pages:e.target.value})}/>
          <Input label="سفارش/دوره" type="number" dir="ltr" value={p.max_orders_per_period} onChange={e=>setPlan(i,{max_orders_per_period:e.target.value})}/>
          <Input label="حجم فایل (MB)" type="number" dir="ltr" value={p.max_file_size_mb} onChange={e=>setPlan(i,{max_file_size_mb:e.target.value})}/>
          <Input label="ترتیب نمایش" type="number" dir="ltr" value={p.sort} onChange={e=>setPlan(i,{sort:e.target.value})}/>
        </div>
        <Ta label="ویژگی‌ها (هر خط یک ویژگی)" rows={5} value={p.featuresText} onChange={e=>setPlan(i,{featuresText:e.target.value})}/>
        <Button className="w-full" onClick={()=>save(plans[i])}>ذخیره تغییرات</Button>
      </Card>)}
    </div>
  </div>);
}

function AdminExperts(){
  const {user}=useAuth();
  const [rows,setRows]=useState(null); const [open,setOpen]=useState(false); const [busy,setBusy]=useState(false);
  const [f,setF]=useState({fullName:'',email:'',password:'',role:'editor',specialty:''});
  const load=()=>api.get('/admin/experts').then(setRows).catch(()=>setRows([]));
  useEffect(()=>{ load(); },[]);
  const create=async e=>{ e.preventDefault(); setBusy(true);
    try{ await api.post('/admin/experts',f); toast('حساب کارشناس ساخته شد');
      setOpen(false); setF({fullName:'',email:'',password:'',role:'editor',specialty:''}); load(); }
    catch(err){ toast(err.message,'error'); } finally{ setBusy(false); } };
  if(rows===null) return <div className="flex justify-center py-20"><Spinner/></div>;
  return (<div>
    <PageTitle title="تیم و کارشناسان" sub="حساب جداگانه برای هر نقش با دسترسی نقش‌محور">
      {user.role==='super_admin'&&<Button onClick={()=>setOpen(true)}><Ic n="plus"/>کارشناس جدید</Button>}</PageTitle>
    <div className="grid md:grid-cols-2 gap-3">
      {rows.map(x=><Card key={x.id} className="p-4 flex items-center justify-between gap-3">
        <div className="min-w-0"><div className="font-medium truncate">{x.full_name}</div>
          <div className="text-xs text-slate-400" dir="ltr">{x.email}</div>
          <div className="text-[11px] text-slate-400 mt-1">{ROLE_LABELS[x.role]}{x.specialty?' · '+x.specialty:''} · عضویت {jDate(x.created_at)}</div></div>
        <div className="text-xs text-cyan-300 shrink-0">{faNum(x.active_orders)} سفارش فعال</div>
      </Card>)}
    </div>
    <Modal open={open} onClose={()=>setOpen(false)} title="ساخت حساب کارشناس">
      <form onSubmit={create} className="space-y-4">
        <Input label="نام و نام خانوادگی" required value={f.fullName} onChange={e=>setF({...f,fullName:e.target.value})}/>
        <Input label="ایمیل" type="email" dir="ltr" required value={f.email} onChange={e=>setF({...f,email:e.target.value})}/>
        <Input label="رمز عبور اولیه" required value={f.password} onChange={e=>setF({...f,password:e.target.value})}/>
        <Select label="نقش" value={f.role} onChange={e=>setF({...f,role:e.target.value})}>
          {['editor','designer','content_admin','support'].map(r=><option key={r} value={r}>{ROLE_LABELS[r]}</option>)}</Select>
        <Input label="تخصص (اختیاری)" placeholder="مثلاً تدوین ریلز" value={f.specialty} onChange={e=>setF({...f,specialty:e.target.value})}/>
        <Button className="w-full" loading={busy} type="submit">ساخت حساب</Button>
      </form></Modal>
  </div>);
}

function AdminSettings(){
  const {user}=useAuth();
  const [size,setSize]=useState(''); const [mimes,setMimes]=useState(''); const [ready,setReady]=useState(false);
  useEffect(()=>{ if(user.role!=='super_admin'){ setReady(true); return; }
    api.get('/admin/settings').then(r=>{ setSize(String(r['storage.max_file_size_mb']??''));
      setMimes((r['storage.allowed_mime']||[]).join('\n')); setReady(true); }).catch(()=>setReady(true)); },[]);
  const saveSize=async()=>{ try{ await api.put('/admin/settings/storage.max_file_size_mb',{value:+size}); toast('ذخیره شد'); }catch(e){ toast(e.message,'error'); } };
  const saveMimes=async()=>{ try{ await api.put('/admin/settings/storage.allowed_mime',{value:mimes.split('\n').map(s=>s.trim()).filter(Boolean)}); toast('ذخیره شد'); }catch(e){ toast(e.message,'error'); } };
  if(!ready) return <div className="flex justify-center py-20"><Spinner/></div>;
  if(user.role!=='super_admin') return <Card><Empty text="دسترسی غیرمجاز"/></Card>;
  return (<div>
    <PageTitle title="تنظیمات فضای ذخیره‌سازی" sub="روی همه پلن‌ها اعمال می‌شود"/>
    <div className="grid md:grid-cols-2 gap-4">
      <Card className="p-5 space-y-4">
        <div className="flex items-center gap-2 font-bold"><Ic n="settings" c="w-4 h-4 text-cyan-300"/>حداکثر حجم فایل</div>
        <Input label="مگابایت" type="number" dir="ltr" value={size} onChange={e=>setSize(e.target.value)}/>
        <p className="text-[11px] text-slate-500">سقف نهایی = کمترین مقدار بین این عدد و سقف پلن کاربر</p>
        <Button onClick={saveSize}>ذخیره</Button></Card>
      <Card className="p-5 space-y-4">
        <div className="font-bold">انواع فایل مجاز (MIME)</div>
        <Ta rows={8} dir="ltr" value={mimes} onChange={e=>setMimes(e.target.value)}/>
        <p className="text-[11px] text-slate-500">هر خط یک MIME؛ فایل خارج از لیست در آپلود رد می‌شود</p>
        <Button onClick={saveMimes}>ذخیره</Button></Card>
    </div>
  </div>);
}

function AdminNotify(){
  const [users,setUsers]=useState(null); const [f,setF]=useState({userId:'',title:'',body:''}); const [busy,setBusy]=useState(false);
  useEffect(()=>{ api.get('/admin/users').then(setUsers).catch(()=>setUsers([])); },[]);
  const send=async e=>{ e.preventDefault(); setBusy(true);
    try{ await api.post('/admin/notify',f); toast('اعلان ارسال شد'); setF({userId:'',title:'',body:''}); }
    catch(err){ toast(err.message,'error'); } finally{ setBusy(false); } };
  if(users===null) return <div className="flex justify-center py-20"><Spinner/></div>;
  return (<div>
    <PageTitle title="ارسال اعلان" sub="به یک کاربر خاص یا همه مشتریان"/>
    <Card className="p-5 max-w-lg">
      <form onSubmit={send} className="space-y-4">
        <Select label="گیرنده" value={f.userId} onChange={e=>setF({...f,userId:e.target.value})}>
          <option value="">همه مشتریان</option>
          {users.map(u=><option key={u.id} value={u.id}>{u.full_name} — {u.email}</option>)}</Select>
        <Input label="عنوان" required value={f.title} onChange={e=>setF({...f,title:e.target.value})}/>
        <Ta label="متن (اختیاری)" value={f.body} onChange={e=>setF({...f,body:e.target.value})}/>
        <Button type="submit" loading={busy}><Ic n="send"/>ارسال</Button>
      </form></Card>
  </div>);
}

/* ═══════════ ۲۱) مسیریابی اصلی ═══════════ */
function renderCustomer(seg){
  const p='/'+seg.join('/');
  if(p==='/dashboard') return <Dashboard/>;
  if(p==='/pages') return <Pages/>;
  if(p==='/upload') return <Upload/>;
  if(p==='/orders') return <Orders/>;
  if(p==='/orders/new') return <NewOrder/>;
  if(seg[0]==='orders'&&seg[1]) return <OrderDetail id={seg[1]}/>;
  if(p==='/calendar') return <CalendarPage/>;
  if(p==='/notifications') return <Notifications/>;
  return <Redirect to="/dashboard"/>;
}
function renderAdmin(seg){
  const p='/admin'+(seg.length>1?'/'+seg.slice(1).join('/'):'');
  if(p==='/admin') return <AdminDashboard/>;
  if(p==='/admin/orders') return <AdminOrders/>;
  if(seg[1]==='orders'&&seg[2]) return <OrderDetail id={seg[2]} admin/>;
  if(p==='/admin/calendar') return <CalendarPage admin/>;
  if(p==='/admin/users') return <AdminUsers/>;
  if(p==='/admin/payments') return <AdminPayments/>;
  if(p==='/admin/plans') return <AdminPlans/>;
  if(p==='/admin/experts') return <AdminExperts/>;
  if(p==='/admin/settings') return <AdminSettings/>;
  if(p==='/admin/notify') return <AdminNotify/>;
  if(p==='/admin/notifications') return <Notifications/>;
  return <Redirect to="/admin"/>;
}
function App(){
  const {user,ready}=useAuth();
  const {path,query}=useRoute();
  if(!ready) return <div className="min-h-screen flex items-center justify-center"><Spinner/></div>;
  const seg=path.split('/').filter(Boolean);
  if(path==='/login'||path==='/register'){
    if(user) return <Redirect to={homeFor(user.role)}/>;
    return path==='/login'?<Login/>:<Register/>;
  }
  if(!user) return <Redirect to="/login"/>;
  if(seg.length===0) return <Redirect to={homeFor(user.role)}/>;
  if(seg[0]==='admin'){
    if(!ADMIN_ROLES.includes(user.role)) return <Redirect to="/dashboard"/>;
    if((user.role==='editor'||user.role==='designer')&&seg.length===1) return <Redirect to="/admin/orders"/>;
    return <Shell>{renderAdmin(seg)}</Shell>;
  }
  if(path==='/subscription') return <Shell><Subscription query={query}/></Shell>;
  if(user.role!=='customer') return <Redirect to={homeFor(user.role)}/>;
  return <Shell>{renderCustomer(seg)}</Shell>;
}

function Root(){ return <AuthProvider><ToastHost/><App/></AuthProvider>; }
ReactDOM.createRoot(document.getElementById('root')).render(<Root/>);
</script>
</body>
</html>
AY_HTML_EOF

echo "── ۲/۳ بررسی صحت ──"
for f in package.json .env.example .gitignore docker-compose.yml README.md server.js public/index.html; do
  [ -s "$f" ] && echo "✔ $f" || { echo "✖ $f مشکل دارد!"; exit 1; }
done
if command -v node >/dev/null 2>&1; then
  node --check server.js && echo "✔ server.js از تست نحو (node --check) پاس شد"
else
  echo "⚠ Node نصب نیست؛ بررسی نحو رد شد (برای اجرای پروژه به Node 18+ نیاز دارید)"
fi
grep -q '</html>' public/index.html && echo "✔ index.html کامل است"

echo "── ۳/۳ ساخت ZIP ──"
cd ..
rm -f adminyar.zip
if command -v zip >/dev/null 2>&1; then
  zip -r adminyar.zip adminyar -x "adminyar/node_modules/*" "adminyar/uploads/*" "adminyar/.env" > /dev/null
elif command -v powershell.exe >/dev/null 2>&1; then
  powershell.exe -NoProfile -Command "Compress-Archive -Path 'adminyar' -DestinationPath 'adminyar.zip' -Force"
else
  tar czf adminyar.tar.gz adminyar
  echo "ℹ zip پیدا نشد؛ به‌جای آن adminyar.tar.gz ساخته شد"
fi
echo ""
echo "════════════════════════════════════════"
echo "✔ تمام شد!"
[ -f adminyar.zip ] && echo "  فایل ZIP: $(pwd)/adminyar.zip"
[ -f adminyar.tar.gz ] && echo "  فایل TAR.GZ: $(pwd)/adminyar.tar.gz"
echo "  اجرای پروژه:"
echo "    cd adminyar && docker compose up -d"
echo "    npm install && npm start   →  http://localhost:4000"
echo "════════════════════════════════════════"