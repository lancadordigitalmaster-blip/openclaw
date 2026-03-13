-- Add lost_to column to track which competitor won the deal
ALTER TABLE proposals ADD COLUMN IF NOT EXISTS lost_to text;
