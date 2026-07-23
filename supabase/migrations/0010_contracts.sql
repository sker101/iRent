-- 0010_contracts.sql

-- Add contract and lease date columns to bookings
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS lease_start timestamptz,
  ADD COLUMN IF NOT EXISTS lease_end timestamptz,
  ADD COLUMN IF NOT EXISTS tenant_contract_url text,
  ADD COLUMN IF NOT EXISTS landlord_contract_url text;

-- Add house rules column to properties
ALTER TABLE properties
  ADD COLUMN IF NOT EXISTS house_rules text;

-- Create contracts storage bucket
INSERT INTO storage.buckets (id, name, public) 
VALUES ('contracts', 'contracts', true)
ON CONFLICT (id) DO NOTHING;

-- RLS for contracts bucket
CREATE POLICY "Public contract viewing"
ON storage.objects FOR SELECT
USING ( bucket_id = 'contracts' );

CREATE POLICY "Users can upload contracts"
ON storage.objects FOR INSERT
WITH CHECK ( bucket_id = 'contracts' AND auth.role() = 'authenticated' );

CREATE POLICY "Users can update contracts"
ON storage.objects FOR UPDATE
USING ( bucket_id = 'contracts' AND auth.role() = 'authenticated' );

CREATE POLICY "Users can delete contracts"
ON storage.objects FOR DELETE
USING ( bucket_id = 'contracts' AND auth.role() = 'authenticated' );
