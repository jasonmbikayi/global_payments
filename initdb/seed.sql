-- seed.sql

-- Insert demo users
--INSERT INTO users (email, name, password_hash) VALUES
INSERT INTO public.users
(id, email, "name", password_hash, created_at, updated_at)
VALUES(uuid_generate_v4(), '', '', '', now(), now())
  ('jason@example.com', 'Jason', '$2b$10$8Xk0ipM3kYHkHz2cI7bN4uA7XtVZJ7z5VZy1uqyYxkczs4OByg12u'), 
  ('william@example.com', 'William', '$2b$10$8Xk0ipM3kYHkHz2cI7bN4uA7XtVZJ7z5VZy1uqyYxkczs4OByg12u');
-- Add more users as needed


-- Add payment methods for Alice (Stripe test IDs)
-- Replace <USER_ID> with the actual UUID from the users table
--INSERT INTO payment_methods (user_id, provider, stripe_id, brand, last4, exp_month, exp_year) VALUES
--  (<USER_ID>, 'stripe', 'pm_card_visa', 'Visa', '4242', 12, 2030),
--  (<USER_ID>, 'stripe', 'pm_card_mastercard', 'Mastercard', '4444', 11, 2031);
-- Replace <USER_ID> with the actual UUID from the users table
-- You can find the user IDs by querying the users table:
-- SELECT id, email FROM users;

INSERT INTO public.payment_methods(id, user_id, provider, provider_id, brand, last4, exp_month, exp_year, created_at, updated_at)
VALUES(uuid_generate_v4(), ?, '', '', '', '', 0, 0, now(), now()) 
  (1, 'pm_card_visa', 'Visa', '4242', 12, 2030),
  (1, 'pm_card_mastercard', 'Mastercard', '4444', 11, 2031);

-- Add one transaction between Alice and Bob
INSERT INTO public.transactions
(id, kind, from_user_id, to_user_id, currency, amount_minor, status, provider, provider_ref, provider_details, metadata, created_at, updated_at)
VALUES(uuid_generate_v4(), '', ?, ?, '', 0, 'PENDING'::tx_status, '', '', '', '', now(), now())
  (1, 2, 25.00, 'usd', 'pi_test_12345', 'completed');
