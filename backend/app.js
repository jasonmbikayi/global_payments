// server/app.js
require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const session = require('express-session');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

const app = express();
app.use(bodyParser.json());

// Session middleware
app.use(
  session({
    secret: process.env.SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
  })
);

// Postgres connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// ---------- Middleware ----------
function ensureAuth(req, res, next) {
  if (req.session && req.session.userId) return next();
  return res.status(401).json({ ok: false, error: 'unauthenticated' });
}

// ---------- Auth Routes ----------

// ---------- register API ----------
app.post('/api/register', async (req, res) => {
  const { email, password, name } = req.body;
  if (!email || !password)
    return res.json({ ok: false, error: 'missing fields' });

  try {
    const hash = await bcrypt.hash(password, 10);
    const result = await pool.query(
      'INSERT INTO users (email, name, password_hash) VALUES ($1, $2, $3) RETURNING id, email, name',
      [email, name, hash]
    );
    const user = result.rows[0];
    req.session.userId = user.id;
    res.json({ ok: true, user });
  } catch (err) {
    res.json({ ok: false, error: err.message });
  }
});

// ---------- Login API ----------
app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password)
    return res.json({ ok: false, error: 'missing fields' });

  try {
    const result = await pool.query(
      'SELECT id, email, name, password_hash FROM users WHERE email=$1',
      [email]
    );
    const user = result.rows[0];
    if (!user) return res.json({ ok: false, error: 'invalid credentials' });

    const match = await bcrypt.compare(password, user.password_hash);
    if (!match) return res.json({ ok: false, error: 'invalid credentials' });

    req.session.userId = user.id;
    res.json({
      ok: true,
      user: { id: user.id, email: user.email, name: user.name },
    });
  } catch (err) {
    res.json({ ok: false, error: err.message });
  }
});

// ---------- Logout API ----------
app.post('/api/auth/logout', (req, res) => {
  req.session.destroy();
  res.json({ ok: true });
});

// ---------- Get current user ----------
app.get('/api/me', ensureAuth, async (req, res) => {
  const result = await pool.query(
    'SELECT id, email, name FROM users WHERE id=$1',
    [req.session.userId]
  );
  res.json({ ok: true, user: result.rows[0] });
});

// ---------- Payments api ----------
app.post('/api/payment_methods', ensureAuth, async (req, res) => {
  const { number, exp, cvc } = req.body;
  if (!number || !exp || !cvc)
    return res.json({ ok: false, error: 'missing card details' });

  try {
    // Convert MM/YY
    const [expMonth, expYearShort] = exp.split('/');
    const expYear = 2000 + Number(expYearShort);

    // Create PaymentMethod in Stripe
    const pm = await stripe.paymentMethods.create({
      type: 'card',
      card: {
        number,
        exp_month: Number(expMonth),
        exp_year: expYear,
        cvc,
      },
    });

    // Save in DB
    const result = await pool.query(
      `INSERT INTO payment_methods (user_id, stripe_id, brand, last4, exp_month, exp_year)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, stripe_id, brand, last4, exp_month, exp_year`,
      [
        req.session.userId,
        pm.id,
        pm.card.brand,
        pm.card.last4,
        pm.card.exp_month,
        pm.card.exp_year,
      ]
    );

    res.json({ ok: true, paymentMethod: result.rows[0] });
  } catch (err) {
    res.json({ ok: false, error: err.message });
  }
});

// ---------- trasnfer API ----------
app.post('/api/transfer', ensureAuth, async (req, res) => {
  const { recipientEmail, amount, currency, paymentMethodId } = req.body;

  try {
    const sender = await pool.query(
      'SELECT id, email FROM users WHERE id=$1',
      [req.session.userId]
    );
    const recipient = await pool.query(
      'SELECT id, email FROM users WHERE email=$1',
      [recipientEmail]
    );

    if (!recipient.rows.length)
      return res.json({ ok: false, error: 'recipient not found' });

    const pm = await pool.query(
      'SELECT * FROM payment_methods WHERE id=$1 AND user_id=$2',
      [paymentMethodId, req.session.userId]
    );
    if (!pm.rows.length)
      return res.json({ ok: false, error: 'payment method not found' });

    // Charge sender
    const pi = await stripe.paymentIntents.create({
      amount: Math.round(amount * 100),
      currency: (currency || 'usd').toLowerCase(),
      payment_method: pm.rows[0].stripe_id,
      confirm: true,
      off_session: true,
      capture_method: 'automatic',
    });

    // Save transaction
    const tx = await pool.query(
      `INSERT INTO transactions (sender_id, recipient_id, amount, currency, stripe_payment_intent, status)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, sender_id, recipient_id, amount, currency, status, stripe_payment_intent`,
      [
        sender.rows[0].id,
        recipient.rows[0].id,
        amount,
        currency || 'usd',
        pi.id,
        'completed',
      ]
    );

    res.json({ ok: true, transaction: tx.rows[0] });
  } catch (err) {
    res.json({
      ok: false,
      error: err.raw ? err.raw.message : err.message,
    });
  }
});

// ---------- Admin ----------
app.get('/api/admin/transactions', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT t.id, u1.email as sender, u2.email as recipient, t.amount, t.currency, t.status, t.stripe_payment_intent
       FROM transactions t
       JOIN users u1 ON t.sender_id = u1.id
       JOIN users u2 ON t.recipient_id = u2.id
       ORDER BY t.id DESC`
    );
    res.json({ ok: true, transactions: result.rows });
  } catch (err) {
    res.json({ ok: false, error: err.message });
  }
});

// ---------- Start ----------
app.listen(3001, () => console.log('This server up and is listening on port 3001'));
module.exports = app; // for testing 
// ---------- End ----------
// 