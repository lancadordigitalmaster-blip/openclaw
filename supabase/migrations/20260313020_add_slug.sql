-- Adiciona coluna slug derivada do client_name
ALTER TABLE proposals ADD COLUMN IF NOT EXISTS slug text;

-- Popula slug para todos os registros existentes
UPDATE proposals
SET slug = lower(regexp_replace(
  translate(
    translate(
      translate(
        translate(
          translate(lower(client_name),
            'áàãâä','aaaaa'),
          'éèêë','eeee'),
        'íìîï','iiii'),
      'óòõôö','ooooo'),
    'úùûü','uuuu'),
  '[^a-z0-9]+', '-', 'g'))
WHERE client_name IS NOT NULL AND slug IS NULL;

-- Índice para lookup eficiente
CREATE INDEX IF NOT EXISTS proposals_slug_idx ON proposals(slug);
