-- initdb/02-schema.sql
BEGIN;

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS citext;

-- =========================
-- Users
-- =========================
CREATE TABLE IF NOT EXISTS users (
  id                uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  email             citext UNIQUE NOT NULL,
  name              text,
  password_hash     text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS users_email_idx ON users (email);

-- =========================
-- Payment Methods
-- =========================
CREATE TABLE IF NOT EXISTS payment_methods (
  id                uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider          text NOT NULL,
  stripe_id       text NOT NULL,
  brand             text,
  last4             text CHECK (last4 ~ '^[0-9]{2,4}$'),
  exp_month         int  CHECK (exp_month BETWEEN 1 AND 12),
  exp_year          int  CHECK (exp_year >= extract(year from now())::int - 1),
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider, stripe_id)
);

CREATE INDEX IF NOT EXISTS payment_methods_user_idx ON payment_methods (user_id);

-- =========================
-- Accounts (Wallets)
-- =========================
CREATE TABLE IF NOT EXISTS accounts (
  id                uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           uuid REFERENCES users(id) ON DELETE SET NULL,
  currency          char(3) NOT NULL,
  balance_minor     bigint NOT NULL DEFAULT 0,
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, currency)
);

CREATE INDEX IF NOT EXISTS accounts_user_currency_idx ON accounts (user_id, currency);

-- =========================
-- Enums
-- =========================
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tx_kind') THEN
    CREATE TYPE tx_kind AS ENUM ('P2P_TRANSFER', 'FUNDING', 'WITHDRAWAL', 'REFUND', 'ADJUSTMENT');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tx_status') THEN
    CREATE TYPE tx_status AS ENUM ('PENDING', 'PROCESSING', 'SUCCEEDED', 'FAILED', 'CANCELED');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'entry_type') THEN
    CREATE TYPE entry_type AS ENUM ('DEBIT', 'CREDIT');
  END IF;
END $$;

-- =========================
-- Transactions
-- =========================
CREATE TABLE IF NOT EXISTS transactions (
  id                uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  kind              tx_kind NOT NULL,
  sender_id         uuid REFERENCES users(id) ON DELETE SET NULL,
  recipient_id      uuid REFERENCES users(id) ON DELETE SET NULL,
  currency          char(3) NOT NULL,
  amount            bigint NOT NULL CHECK (amount > 0),
  status            tx_status NOT NULL DEFAULT 'PENDING',
  provider          text,
  provider_ref      text,
  provider_details  jsonb,
  metadata          jsonb,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CHECK (sender_id IS DISTINCT FROM recipient_id)
);

CREATE INDEX IF NOT EXISTS transactions_from_idx ON transactions (sender_id, created_at);
CREATE INDEX IF NOT EXISTS transactions_to_idx ON transactions (recipient_id, created_at);
CREATE INDEX IF NOT EXISTS transactions_status_idx ON transactions (status);
CREATE INDEX IF NOT EXISTS transactions_stripe_idx ON transactions (provider, provider_ref);

-- =========================
-- Ledger Entries
-- =========================
CREATE TABLE IF NOT EXISTS ledger_entries (
  id                uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  tx_id             uuid NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  account_id        uuid NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
  currency          char(3) NOT NULL,
  amount      bigint NOT NULL CHECK (amount > 0),
  entry_type        entry_type NOT NULL,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ledger_tx_idx ON ledger_entries (tx_id);
CREATE INDEX IF NOT EXISTS ledger_account_idx ON ledger_entries (account_id, created_at);

-- =========================
-- Webhooks & Idempotency
-- =========================
CREATE TABLE IF NOT EXISTS webhook_events (
  id                uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  provider          text NOT NULL,
  event_id          text NOT NULL,
  received_at       timestamptz NOT NULL DEFAULT now(),
  payload           jsonb NOT NULL,
  processed_at      timestamptz,
  UNIQUE (provider, event_id)
);

CREATE TABLE IF NOT EXISTS idempotency_keys (
  key               text PRIMARY KEY,
  created_at        timestamptz NOT NULL DEFAULT now(),
  last_seen_at      timestamptz NOT NULL DEFAULT now(),
  response_body     jsonb
);

-- =========================
-- KYC
-- =========================
CREATE TABLE IF NOT EXISTS kyc_profiles (
  id                uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status            text NOT NULL,
  provider          text,
  provider_ref      text,
  data              jsonb,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id)
);

-- =========================
-- Functions & Triggers
-- =========================

-- Function: update balance after ledger entry insert
CREATE OR REPLACE FUNCTION update_account_balance()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.entry_type = 'CREDIT' THEN
    UPDATE accounts
    SET balance_minor = balance_minor + NEW.amount
    WHERE id = NEW.account_id;
  ELSIF NEW.entry_type = 'DEBIT' THEN
    UPDATE accounts
    SET balance_minor = balance_minor - NEW.amount
    WHERE id = NEW.account_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: after insert on ledger_entries
DROP TRIGGER IF EXISTS trg_update_balance ON ledger_entries;
CREATE TRIGGER trg_update_balance
AFTER INSERT ON ledger_entries
FOR EACH ROW
EXECUTE FUNCTION update_account_balance();

-- Function: maintain updated_at columns
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to relevant tables
DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_payment_methods_updated_at ON payment_methods;
CREATE TRIGGER trg_payment_methods_updated_at
BEFORE UPDATE ON payment_methods
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_transactions_updated_at ON transactions;
CREATE TRIGGER trg_transactions_updated_at
BEFORE UPDATE ON transactions
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_kyc_profiles_updated_at ON kyc_profiles;
CREATE TRIGGER trg_kyc_profiles_updated_at
BEFORE UPDATE ON kyc_profiles
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

COMMIT;
  amount      bigint NOT NULL CHECK (amount > 0),
  entry_type        entry_type NOT NULL,
  created_at        timestamptz NOT NULL DEFAULT now()
); 