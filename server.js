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
