-- Migration: Update convenience fee from ₹28 to ₹19 in all RPC price calculation functions
-- Created: 2025-12-08

-- Drop existing functions first
DROP FUNCTION IF EXISTS calculate_service_listing_price(NUMERIC);
DROP FUNCTION IF EXISTS calculate_service_detail_price(NUMERIC, BOOLEAN);
DROP FUNCTION IF EXISTS calculate_theater_listing_price(NUMERIC);
DROP FUNCTION IF EXISTS calculate_theater_detail_price(NUMERIC, BOOLEAN);

-- Recreate calculate_service_listing_price function with updated convenience fee
CREATE OR REPLACE FUNCTION calculate_service_listing_price(p_service_price NUMERIC)
RETURNS TABLE(
  service_price NUMERIC,
  convenience_fee NUMERIC,
  transaction_fee NUMERIC,
  total_amount NUMERIC
) AS $$
DECLARE
  v_convenience_fee NUMERIC := 19.00; -- Updated from 28.00 to 19.00
  v_transaction_fee_rate NUMERIC := 0.0354; -- 3.54%
  v_transaction_fee NUMERIC;
  v_total_amount NUMERIC;
BEGIN
  -- Calculate transaction fee
  v_transaction_fee := p_service_price * v_transaction_fee_rate;

  -- Calculate total amount
  v_total_amount := p_service_price + v_convenience_fee + v_transaction_fee;

  -- Apply final rounding to ensure prices end with 49 or 99
  v_total_amount := apply_final_rounding(v_total_amount);

  RETURN QUERY SELECT
    p_service_price,
    v_convenience_fee,
    v_transaction_fee,
    v_total_amount;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Recreate calculate_service_detail_price function (no convenience fee for detail/checkout)
CREATE OR REPLACE FUNCTION calculate_service_detail_price(
  p_service_price NUMERIC,
  p_vendor_has_gst BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(
  service_price NUMERIC,
  transaction_fee NUMERIC,
  gst_amount NUMERIC,
  total_amount NUMERIC
) AS $$
DECLARE
  v_transaction_fee_rate NUMERIC := 0.0354; -- 3.54%
  v_gst_rate NUMERIC := 0.18; -- 18%
  v_transaction_fee NUMERIC;
  v_gst_amount NUMERIC;
  v_total_amount NUMERIC;
BEGIN
  -- Calculate transaction fee
  v_transaction_fee := p_service_price * v_transaction_fee_rate;

  -- Calculate GST if vendor has GST
  v_gst_amount := CASE WHEN p_vendor_has_gst THEN p_service_price * v_gst_rate ELSE 0 END;

  -- Calculate total amount (NO convenience fee for service detail/checkout)
  v_total_amount := p_service_price + v_transaction_fee + v_gst_amount;

  -- Apply final rounding to ensure prices end with 49 or 99
  v_total_amount := apply_final_rounding(v_total_amount);

  RETURN QUERY SELECT
    p_service_price,
    v_transaction_fee,
    v_gst_amount,
    v_total_amount;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Recreate calculate_theater_listing_price function with updated convenience fee
CREATE OR REPLACE FUNCTION calculate_theater_listing_price(p_theater_price NUMERIC)
RETURNS TABLE(
  theater_price NUMERIC,
  convenience_fee NUMERIC,
  transaction_fee NUMERIC,
  total_amount NUMERIC
) AS $$
DECLARE
  v_convenience_fee NUMERIC := 19.00; -- Updated from 28.00 to 19.00
  v_transaction_fee_rate NUMERIC := 0.0354; -- 3.54%
  v_transaction_fee NUMERIC;
  v_total_amount NUMERIC;
BEGIN
  -- Calculate transaction fee
  v_transaction_fee := p_theater_price * v_transaction_fee_rate;

  -- Calculate total amount
  v_total_amount := p_theater_price + v_convenience_fee + v_transaction_fee;

  -- Apply final rounding to ensure prices end with 49 or 99
  v_total_amount := apply_final_rounding(v_total_amount);

  RETURN QUERY SELECT
    p_theater_price,
    v_convenience_fee,
    v_transaction_fee,
    v_total_amount;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Recreate calculate_theater_detail_price function (no convenience fee for detail/checkout)
CREATE OR REPLACE FUNCTION calculate_theater_detail_price(
  p_theater_price NUMERIC,
  p_vendor_has_gst BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(
  theater_price NUMERIC,
  transaction_fee NUMERIC,
  gst_amount NUMERIC,
  total_amount NUMERIC
) AS $$
DECLARE
  v_transaction_fee_rate NUMERIC := 0.0354; -- 3.54%
  v_gst_rate NUMERIC := 0.18; -- 18%
  v_transaction_fee NUMERIC;
  v_gst_amount NUMERIC;
  v_total_amount NUMERIC;
BEGIN
  -- Calculate transaction fee
  v_transaction_fee := p_theater_price * v_transaction_fee_rate;

  -- Calculate GST if vendor has GST
  v_gst_amount := CASE WHEN p_vendor_has_gst THEN p_theater_price * v_gst_rate ELSE 0 END;

  -- Calculate total amount (NO convenience fee for theater detail/checkout)
  v_total_amount := p_theater_price + v_transaction_fee + v_gst_amount;

  -- Apply final rounding to ensure prices end with 49 or 99
  v_total_amount := apply_final_rounding(v_total_amount);

  RETURN QUERY SELECT
    p_theater_price,
    v_transaction_fee,
    v_gst_amount,
    v_total_amount;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
