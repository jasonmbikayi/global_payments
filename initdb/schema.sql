-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    name TEXT,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Payment methods linked to users
CREATE TABLE payment_methods (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    stripe_id TEXT NOT NULL,
    brand TEXT,
    last4 TEXT,
    exp_month INTEGER,
    exp_year INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Transactions between users
CREATE TABLE transactions (
    id SERIAL PRIMARY KEY,
    sender_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recipient_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount NUMERIC(12,2) NOT NULL,
    currency TEXT NOT NULL,
    stripe_payment_intent TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'completed', 'failed')),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes to speed up common lookups
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_payment_methods_user_id ON payment_methods(user_id);
CREATE INDEX idx_transactions_sender_id ON transactions(sender_id);
CREATE INDEX idx_transactions_recipient_id ON transactions(recipient_id);-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    name TEXT,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Payment methods linked to users
CREATE TABLE payment_methods (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    stripe_id TEXT NOT NULL,
    brand TEXT,
    last4 TEXT,
    exp_month INTEGER,
    exp_year INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Transactions between users
CREATE TABLE transactions (
    id SERIAL PRIMARY KEY,
    sender_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recipient_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount NUMERIC(12,2) NOT NULL,
    currency TEXT NOT NULL,
    stripe_payment_intent TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'completed', 'failed')),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert demo users
INSERT INTO users (email, name, password_hash) VALUES
  ('jason@example.com', 'Jason', '$2b$10$8Xk0ipM3kYHkHz2cI7bN4uA7XtVZJ7z5VZy1uqyYxkczs4OByg12u'), -- password: alice123
  ('william@example.com', 'William', '$2b$10$8Xk0ipM3kYHkHz2cI7bN4uA7XtVZJ7z5VZy1uqyYxkczs4OByg12u'); -- password: alice123

-- Add payment methods for Alice (Stripe test IDs)
INSERT INTO payment_methods (user_id, stripe_id, brand, last4, exp_month, exp_year) VALUES
  (1, 'pm_card_visa', 'Visa', '4242', 12, 2030),
  (1, 'pm_card_mastercard', 'Mastercard', '4444', 11, 2031);

-- Add one transaction between Alice and Bob
INSERT INTO transactions (sender_id, recipient_id, amount, currency, stripe_payment_intent, status) VALUES
  (1, 2, 25.00, 'usd', 'pi_test_12345', 'completed'),
  (2, 1, 15.00, 'usd', 'pi_test_12345', 'completed');

-- Indexes to speed up common lookups
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_payment_methods_user_id ON payment_methods(user_id);
CREATE INDEX idx_transactions_sender_id ON transactions(sender_id);
CREATE INDEX idx_transactions_recipient_id ON transactions(recipient_id);
