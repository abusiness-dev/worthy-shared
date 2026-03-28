-- Crea tutti i tipi enum per il database Worthy

CREATE TYPE trust_level AS ENUM ('new', 'contributor', 'trusted', 'banned');

CREATE TYPE user_role AS ENUM ('user', 'moderator', 'admin');

CREATE TYPE verification_status AS ENUM ('unverified', 'verified', 'mattia_reviewed');

CREATE TYPE verdict AS ENUM ('steal', 'worthy', 'fair', 'meh', 'not_worthy');

CREATE TYPE market_segment AS ENUM ('ultra_fast', 'fast', 'premium_fast', 'mid_range');

CREATE TYPE scan_type AS ENUM ('barcode', 'label', 'manual', 'search');

CREATE TYPE report_reason AS ENUM ('wrong_composition', 'wrong_price', 'wrong_brand', 'duplicate', 'other');

CREATE TYPE report_status AS ENUM ('pending', 'confirmed', 'rejected');

CREATE TYPE duplicate_status AS ENUM ('pending', 'confirmed_duplicate', 'not_duplicate');

CREATE TYPE audit_action AS ENUM ('insert', 'update', 'delete');

CREATE TYPE price_source AS ENUM ('user', 'scraper', 'affiliate_feed');
