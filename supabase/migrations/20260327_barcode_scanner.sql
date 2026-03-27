-- Add EAN barcode column to perfumes table for barcode scanner feature
ALTER TABLE perfumes ADD COLUMN IF NOT EXISTS ean TEXT;
CREATE INDEX IF NOT EXISTS idx_perfumes_ean ON perfumes(ean);
