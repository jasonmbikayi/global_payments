-- initdb/02-schema.sql
BEGIN;

-- Users
CREATE TABLE IF NOT EXISTS users (
  id                uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  email             citext UNIQUE NOT NULL,
  name              text,
  password_hash     text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS users_email_idx ON users (email);

-- Payment methods (tokenized)
CREATE TABLE IF NOT EXISTS payment_methods (
  id                uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider          text NOT NULL,                -- e.g., 'stripe','adyen'
  provider_id       text NOT NULL,                -- token/id returned by provider
  brand             text,
  last4             text CHECK (last4 ~ '^[0-9]{2,4}$'),
  exp_month         int  CHECK (exp_month BETWEEN 1 AND 12),
  exp_year          int  CHECK (exp_year >= extract(year from now())::int - 1),
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider, provider_id)
);

CREATE INDEX IF NOT EXISTS payment_methods_user_idx ON payment_methods (user_id);

-- Accounts (optional wallet per user/currency)
CREATE TABLE IF NOT EXISTS accounts (
  id                uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           uuid REFERENCES users(id) ON DELETE SET NULL,
  currency          char(3) NOT NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, currency)
);

CREATE INDEX IF NOT EXISTS accounts_user_currency_idx ON accounts (user_id, currency);

-- Enums
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

-- Transactions (intent-level)
CREATE TABLE IF NOT EXISTS transactions (
  id                uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  kind              tx_kind NOT NULL,
  from_user_id      uuid REFERENCES users(id) ON DELETE SET NULL,
  to_user_id        uuid REFERENCES users(id) ON DELETE SET NULL,
  currency          char(3) NOT NULL,
  amount_minor      bigint NOT NULL CHECK (amount_minor > 0),
  status            tx_status NOT NULL DEFAULT 'PENDING',
  provider          text,
  provider_ref      text,
  provider_details  jsonb,
  metadata          jsonb,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CHECK (from_user_id IS DISTINCT FROM to_user_id)
);

CREATE INDEX IF NOT EXISTS transactions_from_idx ON transactions (from_user_id, created_at);
CREATE INDEX IF NOT EXISTS transactions_to_idx ON transactions (to_user_id, created_at);
CREATE INDEX IF NOT EXISTS transactions_status_idx ON transactions (status);
CREATE INDEX IF NOT EXISTS transactions_provider_idx ON transactions (provider, provider_ref);

-- Double-entry ledger
CREATE TABLE IF NOT EXISTS ledger_entries (
  id                uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  tx_id             uuid NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  account_id        uuid NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
  currency          char(3) NOT NULL,
  amount_minor      bigint NOT NULL,
  entry_type        entry_type NOT NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  CHECK (amount_minor > 0)
);

CREATE INDEX IF NOT EXISTS ledger_tx_idx ON ledger_entries (tx_id);
CREATE INDEX IF NOT EXISTS ledger_account_idx ON ledger_entries (account_id, created_at);

-- Webhooks & idempotency
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

-- KYC (optional)
CREATE TABLE IF NOT EXISTS kyc_profiles (
  id                uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status            text NOT NULL,                        -- e.g., 'PENDING','VERIFIED'
  provider          text,
  provider_ref      text,
  data              jsonb,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id)
);

COMMIT;
