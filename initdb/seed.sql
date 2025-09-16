-- seed.sql

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
  (1, 2, 25.00, 'usd', 'pi_test_12345', 'completed');

