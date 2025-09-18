--
-- PostgreSQL database dump
--

\restrict Q17L8uP9vRSkC0UeggKnekkNg5FSbQLruAj8JDPkhDynBNaGGNgb6mNvN383jis

-- Dumped from database version 17.6 (Debian 17.6-1.pgdg13+1)
-- Dumped by pg_dump version 17.6 (Debian 17.6-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: entry_type; Type: TYPE; Schema: public; Owner: p2papp
--

CREATE TYPE public.entry_type AS ENUM (
    'DEBIT',
    'CREDIT'
);


ALTER TYPE public.entry_type OWNER TO p2papp;

--
-- Name: tx_kind; Type: TYPE; Schema: public; Owner: p2papp
--

CREATE TYPE public.tx_kind AS ENUM (
    'P2P_TRANSFER',
    'FUNDING',
    'WITHDRAWAL',
    'REFUND',
    'ADJUSTMENT'
);


ALTER TYPE public.tx_kind OWNER TO p2papp;

--
-- Name: tx_status; Type: TYPE; Schema: public; Owner: p2papp
--

CREATE TYPE public.tx_status AS ENUM (
    'PENDING',
    'PROCESSING',
    'SUCCEEDED',
    'FAILED',
    'CANCELED'
);


ALTER TYPE public.tx_status OWNER TO p2papp;

--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: p2papp
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_updated_at() OWNER TO p2papp;

--
-- Name: update_account_balance(); Type: FUNCTION; Schema: public; Owner: p2papp
--

CREATE FUNCTION public.update_account_balance() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.update_account_balance() OWNER TO p2papp;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: accounts; Type: TABLE; Schema: public; Owner: p2papp
--

CREATE TABLE public.accounts (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    currency character(3) NOT NULL,
    balance_minor bigint DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.accounts OWNER TO p2papp;

--
-- Name: idempotency_keys; Type: TABLE; Schema: public; Owner: p2papp
--

CREATE TABLE public.idempotency_keys (
    key text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    response_body jsonb
);


ALTER TABLE public.idempotency_keys OWNER TO p2papp;

--
-- Name: kyc_profiles; Type: TABLE; Schema: public; Owner: p2papp
--

CREATE TABLE public.kyc_profiles (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    status text NOT NULL,
    provider text,
    provider_ref text,
    data jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.kyc_profiles OWNER TO p2papp;

--
-- Name: ledger_entries; Type: TABLE; Schema: public; Owner: p2papp
--

CREATE TABLE public.ledger_entries (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tx_id uuid NOT NULL,
    account_id uuid NOT NULL,
    currency character(3) NOT NULL,
    amount bigint NOT NULL,
    entry_type public.entry_type NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ledger_entries_amount_check CHECK ((amount > 0))
);


ALTER TABLE public.ledger_entries OWNER TO p2papp;

--
-- Name: payment_methods; Type: TABLE; Schema: public; Owner: p2papp
--

CREATE TABLE public.payment_methods (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    provider text NOT NULL,
    stripe_id text NOT NULL,
    brand text,
    last4 text,
    exp_month integer,
    exp_year integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT payment_methods_exp_month_check CHECK (((exp_month >= 1) AND (exp_month <= 12))),
    CONSTRAINT payment_methods_exp_year_check CHECK ((exp_year >= ((EXTRACT(year FROM now()))::integer - 1))),
    CONSTRAINT payment_methods_last4_check CHECK ((last4 ~ '^[0-9]{2,4}$'::text))
);


ALTER TABLE public.payment_methods OWNER TO p2papp;

--
-- Name: transactions; Type: TABLE; Schema: public; Owner: p2papp
--

CREATE TABLE public.transactions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    kind public.tx_kind NOT NULL,
    sender_id uuid,
    recipient_id uuid,
    currency character(3) NOT NULL,
    amount bigint NOT NULL,
    status public.tx_status DEFAULT 'PENDING'::public.tx_status NOT NULL,
    provider text,
    provider_ref text,
    provider_details jsonb,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT transactions_amount_check CHECK ((amount > 0)),
    CONSTRAINT transactions_check CHECK ((sender_id IS DISTINCT FROM recipient_id))
);


ALTER TABLE public.transactions OWNER TO p2papp;

--
-- Name: users; Type: TABLE; Schema: public; Owner: p2papp
--

CREATE TABLE public.users (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    email public.citext NOT NULL,
    name text,
    password_hash text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.users OWNER TO p2papp;

--
-- Name: webhook_events; Type: TABLE; Schema: public; Owner: p2papp
--

CREATE TABLE public.webhook_events (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    provider text NOT NULL,
    event_id text NOT NULL,
    received_at timestamp with time zone DEFAULT now() NOT NULL,
    payload jsonb NOT NULL,
    processed_at timestamp with time zone
);


ALTER TABLE public.webhook_events OWNER TO p2papp;

--
-- Data for Name: accounts; Type: TABLE DATA; Schema: public; Owner: p2papp
--

COPY public.accounts (id, user_id, currency, balance_minor, created_at) FROM stdin;
\.


--
-- Data for Name: idempotency_keys; Type: TABLE DATA; Schema: public; Owner: p2papp
--

COPY public.idempotency_keys (key, created_at, last_seen_at, response_body) FROM stdin;
\.


--
-- Data for Name: kyc_profiles; Type: TABLE DATA; Schema: public; Owner: p2papp
--

COPY public.kyc_profiles (id, user_id, status, provider, provider_ref, data, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: ledger_entries; Type: TABLE DATA; Schema: public; Owner: p2papp
--

COPY public.ledger_entries (id, tx_id, account_id, currency, amount, entry_type, created_at) FROM stdin;
\.


--
-- Data for Name: payment_methods; Type: TABLE DATA; Schema: public; Owner: p2papp
--

COPY public.payment_methods (id, user_id, provider, stripe_id, brand, last4, exp_month, exp_year, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: transactions; Type: TABLE DATA; Schema: public; Owner: p2papp
--

COPY public.transactions (id, kind, sender_id, recipient_id, currency, amount, status, provider, provider_ref, provider_details, metadata, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: p2papp
--

COPY public.users (id, email, name, password_hash, created_at, updated_at) FROM stdin;
4082747f-562c-4ac7-b16a-a57286b7a4e8	jasonmbikayi@gmail.com	Jason Mbikayi	$2b$10$LNhFzSg6RiL/6yOdO.GZE.lcQ2nrC8wqECvKxyLsFPJymOmCWX0Y.	2025-09-17 17:54:34.762155+00	2025-09-17 17:54:34.762155+00
4f7c6996-c160-436e-b6cc-3480943f0547	vanessamuamba94@gmail.com	Vanessa Muamba	$2b$10$chjdhJpnSP7hXVjglTg71uGiCdV8MacTvx9cbcdlj9jzNcEoUJOCq	2025-09-17 17:59:15.092052+00	2025-09-17 17:59:15.092052+00
91d63760-1485-46b0-90c8-d184cacbf03d	vanessatest@gmail.com	Vanessa	$2b$10$sNyqg//WQrSYA/HOAt7ukuvsb2cMFTdoOeURRrjA.fgtu4Wo5vlXS	2025-09-17 18:07:37.723125+00	2025-09-17 18:07:37.723125+00
0945f521-bd98-4efd-9cdb-f9f12e702140	jasontest@gmail.com	Jason	$2b$10$OqHN7BPntlwG94udKqrbjOdgf0E7nyS2Ojr/OwnVhZZLnU7T58O9C	2025-09-17 18:07:52.736302+00	2025-09-17 18:07:52.736302+00
\.


--
-- Data for Name: webhook_events; Type: TABLE DATA; Schema: public; Owner: p2papp
--

COPY public.webhook_events (id, provider, event_id, received_at, payload, processed_at) FROM stdin;
\.


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: accounts accounts_user_id_currency_key; Type: CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_user_id_currency_key UNIQUE (user_id, currency);


--
-- Name: idempotency_keys idempotency_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.idempotency_keys
    ADD CONSTRAINT idempotency_keys_pkey PRIMARY KEY (key);


--
-- Name: kyc_profiles kyc_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.kyc_profiles
    ADD CONSTRAINT kyc_profiles_pkey PRIMARY KEY (id);


--
-- Name: kyc_profiles kyc_profiles_user_id_key; Type: CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.kyc_profiles
    ADD CONSTRAINT kyc_profiles_user_id_key UNIQUE (user_id);


--
-- Name: ledger_entries ledger_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.ledger_entries
    ADD CONSTRAINT ledger_entries_pkey PRIMARY KEY (id);


--
-- Name: payment_methods payment_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT payment_methods_pkey PRIMARY KEY (id);


--
-- Name: payment_methods payment_methods_provider_stripe_id_key; Type: CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT payment_methods_provider_stripe_id_key UNIQUE (provider, stripe_id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: webhook_events webhook_events_pkey; Type: CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.webhook_events
    ADD CONSTRAINT webhook_events_pkey PRIMARY KEY (id);


--
-- Name: webhook_events webhook_events_provider_event_id_key; Type: CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.webhook_events
    ADD CONSTRAINT webhook_events_provider_event_id_key UNIQUE (provider, event_id);


--
-- Name: accounts_user_currency_idx; Type: INDEX; Schema: public; Owner: p2papp
--

CREATE INDEX accounts_user_currency_idx ON public.accounts USING btree (user_id, currency);


--
-- Name: ledger_account_idx; Type: INDEX; Schema: public; Owner: p2papp
--

CREATE INDEX ledger_account_idx ON public.ledger_entries USING btree (account_id, created_at);


--
-- Name: ledger_tx_idx; Type: INDEX; Schema: public; Owner: p2papp
--

CREATE INDEX ledger_tx_idx ON public.ledger_entries USING btree (tx_id);


--
-- Name: payment_methods_user_idx; Type: INDEX; Schema: public; Owner: p2papp
--

CREATE INDEX payment_methods_user_idx ON public.payment_methods USING btree (user_id);


--
-- Name: transactions_from_idx; Type: INDEX; Schema: public; Owner: p2papp
--

CREATE INDEX transactions_from_idx ON public.transactions USING btree (sender_id, created_at);


--
-- Name: transactions_status_idx; Type: INDEX; Schema: public; Owner: p2papp
--

CREATE INDEX transactions_status_idx ON public.transactions USING btree (status);


--
-- Name: transactions_stripe_idx; Type: INDEX; Schema: public; Owner: p2papp
--

CREATE INDEX transactions_stripe_idx ON public.transactions USING btree (provider, provider_ref);


--
-- Name: transactions_to_idx; Type: INDEX; Schema: public; Owner: p2papp
--

CREATE INDEX transactions_to_idx ON public.transactions USING btree (recipient_id, created_at);


--
-- Name: users_email_idx; Type: INDEX; Schema: public; Owner: p2papp
--

CREATE INDEX users_email_idx ON public.users USING btree (email);


--
-- Name: kyc_profiles trg_kyc_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: p2papp
--

CREATE TRIGGER trg_kyc_profiles_updated_at BEFORE UPDATE ON public.kyc_profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: payment_methods trg_payment_methods_updated_at; Type: TRIGGER; Schema: public; Owner: p2papp
--

CREATE TRIGGER trg_payment_methods_updated_at BEFORE UPDATE ON public.payment_methods FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: transactions trg_transactions_updated_at; Type: TRIGGER; Schema: public; Owner: p2papp
--

CREATE TRIGGER trg_transactions_updated_at BEFORE UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ledger_entries trg_update_balance; Type: TRIGGER; Schema: public; Owner: p2papp
--

CREATE TRIGGER trg_update_balance AFTER INSERT ON public.ledger_entries FOR EACH ROW EXECUTE FUNCTION public.update_account_balance();


--
-- Name: users trg_users_updated_at; Type: TRIGGER; Schema: public; Owner: p2papp
--

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: accounts accounts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: kyc_profiles kyc_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.kyc_profiles
    ADD CONSTRAINT kyc_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ledger_entries ledger_entries_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.ledger_entries
    ADD CONSTRAINT ledger_entries_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE RESTRICT;


--
-- Name: ledger_entries ledger_entries_tx_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.ledger_entries
    ADD CONSTRAINT ledger_entries_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES public.transactions(id) ON DELETE CASCADE;


--
-- Name: payment_methods payment_methods_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT payment_methods_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: transactions transactions_recipient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: transactions transactions_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: p2papp
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict Q17L8uP9vRSkC0UeggKnekkNg5FSbQLruAj8JDPkhDynBNaGGNgb6mNvN383jis

