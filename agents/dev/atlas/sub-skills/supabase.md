# supabase.md — ATLAS Sub-Skill: Supabase
# Ativa quando: "Supabase", "Row Level Security", "RLS", "Supabase Auth"

## Row Level Security — Padrão Wolf

RLS é **obrigatório** em toda tabela exposta via Supabase (client direto ou API). Sem RLS, qualquer usuário autenticado acessa todos os dados.

```sql
-- Ativa RLS na tabela
ALTER TABLE ad_campaigns ENABLE ROW LEVEL SECURITY;

-- Regra: sem policy explícita = nenhum acesso (padrão seguro)
-- Sempre adicionar policies explícitas para SELECT, INSERT, UPDATE, DELETE
```

---

## Políticas RLS Padrão Wolf

### By User (usuário acessa só seus próprios dados)
```sql
-- Tabela: profiles (dados do usuário)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- SELECT: usuário vê só o próprio perfil
CREATE POLICY "users_select_own_profile"
  ON profiles FOR SELECT
  USING (auth.uid() = user_id);

-- UPDATE: usuário edita só o próprio perfil
CREATE POLICY "users_update_own_profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

### By Organization (multi-tenant — padrão Wolf)
```sql
-- Função helper — retorna organization_id do usuário atual
CREATE OR REPLACE FUNCTION auth.user_organization_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT organization_id
  FROM users
  WHERE id = auth.uid()
$$;

-- Função helper — retorna role do usuário atual
CREATE OR REPLACE FUNCTION auth.user_role()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT role::text
  FROM users
  WHERE id = auth.uid()
$$;

-- Tabela: ad_campaigns (isolamento por organização)
ALTER TABLE ad_campaigns ENABLE ROW LEVEL SECURITY;

-- SELECT: qualquer membro da org vê campanhas da org
CREATE POLICY "org_members_select_campaigns"
  ON ad_campaigns FOR SELECT
  USING (
    organization_id = auth.user_organization_id()
    AND deleted_at IS NULL
  );

-- INSERT: apenas admin/owner podem criar campanhas
CREATE POLICY "org_admins_insert_campaigns"
  ON ad_campaigns FOR INSERT
  WITH CHECK (
    organization_id = auth.user_organization_id()
    AND auth.user_role() IN ('owner', 'admin')
  );

-- UPDATE: apenas admin/owner podem editar
CREATE POLICY "org_admins_update_campaigns"
  ON ad_campaigns FOR UPDATE
  USING (
    organization_id = auth.user_organization_id()
    AND auth.user_role() IN ('owner', 'admin')
  )
  WITH CHECK (
    organization_id = auth.user_organization_id()
  );

-- DELETE (soft): apenas owner pode deletar
CREATE POLICY "org_owners_delete_campaigns"
  ON ad_campaigns FOR DELETE
  USING (
    organization_id = auth.user_organization_id()
    AND auth.user_role() = 'owner'
  );
```

### Service Role — Bypass de RLS (uso restrito)
```typescript
// NUNCA exponha a service role key no cliente

// lib/supabase-admin.ts — uso apenas no servidor
import { createClient } from '@supabase/supabase-js'

export const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,  // server-only
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  }
)

// Uso: operações de admin que precisam bypassar RLS
// Ex: criar usuário, sync com API externa, jobs de cron
```

---

## Políticas RLS Completas — Sistema Wolf

```sql
-- ============================================================
-- ORGANIZATIONS
-- ============================================================
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "members_select_own_org"
  ON organizations FOR SELECT
  USING (id = auth.user_organization_id());

CREATE POLICY "owners_update_org"
  ON organizations FOR UPDATE
  USING (
    id = auth.user_organization_id()
    AND auth.user_role() = 'owner'
  );

-- ============================================================
-- USERS
-- ============================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "org_members_select_users"
  ON users FOR SELECT
  USING (
    organization_id = auth.user_organization_id()
    AND deleted_at IS NULL
  );

CREATE POLICY "admins_insert_users"
  ON users FOR INSERT
  WITH CHECK (
    organization_id = auth.user_organization_id()
    AND auth.user_role() IN ('owner', 'admin')
  );

CREATE POLICY "users_update_own_or_admin"
  ON users FOR UPDATE
  USING (
    organization_id = auth.user_organization_id()
    AND (id = auth.uid() OR auth.user_role() IN ('owner', 'admin'))
  );

-- ============================================================
-- AD_ACCOUNTS
-- ============================================================
ALTER TABLE ad_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "org_members_select_accounts"
  ON ad_accounts FOR SELECT
  USING (organization_id = auth.user_organization_id());

CREATE POLICY "admins_manage_accounts"
  ON ad_accounts FOR ALL
  USING (
    organization_id = auth.user_organization_id()
    AND auth.user_role() IN ('owner', 'admin')
  );
```

---

## Supabase Storage

```typescript
// lib/storage.ts

import { supabase } from './supabase-client'

// Buckets: public (URLs públicas sem auth) vs private (requer signed URL)
// Configurar em: Supabase Dashboard > Storage > Buckets

// Upload de arquivo
export async function uploadFile(
  bucket: 'public-assets' | 'private-reports',
  path: string,                  // ex: "organizations/uuid/logo.png"
  file: File | Blob,
  contentType: string
): Promise<string> {
  const { data, error } = await supabase.storage
    .from(bucket)
    .upload(path, file, {
      contentType,
      upsert: true,              // sobrescreve se existir
    })

  if (error) throw error

  if (bucket === 'public-assets') {
    // URL pública permanente
    const { data: urlData } = supabase.storage
      .from(bucket)
      .getPublicUrl(data.path)
    return urlData.publicUrl
  } else {
    // URL assinada com expiração (para relatórios privados)
    const { data: signedData, error: signedError } = await supabase.storage
      .from(bucket)
      .createSignedUrl(data.path, 60 * 60)  // 1 hora

    if (signedError) throw signedError
    return signedData.signedUrl
  }
}

// Delete arquivo
export async function deleteFile(
  bucket: string,
  paths: string[]
): Promise<void> {
  const { error } = await supabase.storage
    .from(bucket)
    .remove(paths)
  if (error) throw error
}
```

### RLS para Storage (policies no Dashboard):
```sql
-- Bucket: private-reports
-- Apenas membros da org podem acessar arquivos da org
-- (path format: organizations/{orgId}/reports/{filename})

CREATE POLICY "org_members_read_own_reports"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'private-reports'
    AND (storage.foldername(name))[2] = auth.user_organization_id()::text
  );
```

---

## Realtime Subscriptions

```typescript
// hooks/use-campaign-realtime.ts

import { useEffect } from 'react'
import { supabase } from '../lib/supabase-client'
import type { AdCampaign } from '../types'

export function useCampaignRealtime(
  organizationId: string,
  onUpdate: (campaign: AdCampaign) => void
) {
  useEffect(() => {
    const channel = supabase
      .channel(`campaigns:${organizationId}`)
      .on(
        'postgres_changes',
        {
          event: '*',           // INSERT, UPDATE, DELETE
          schema: 'public',
          table: 'ad_campaigns',
          filter: `organization_id=eq.${organizationId}`,
        },
        (payload) => {
          if (payload.eventType === 'UPDATE' || payload.eventType === 'INSERT') {
            onUpdate(payload.new as AdCampaign)
          }
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [organizationId, onUpdate])
}
```

---

## Edge Functions — Quando Usar

Use Edge Functions quando precisar de:
- Webhook receiver (Meta, Stripe, etc.) — lógica próxima ao banco
- Processar dados antes de inserir (validação complexa, enriquecimento)
- Scheduled jobs sem infraestrutura extra
- Autenticação customizada

NÃO use Edge Functions para:
- Lógica de negócio principal (use sua API Next.js/Node.js)
- Jobs de longa duração (> 2 segundos) — use BullMQ
- Código com muitas dependências NPM (bundle size limitado)

```typescript
// supabase/functions/meta-webhook/index.ts

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req: Request) => {
  const signature = req.headers.get('x-hub-signature-256')

  // Valida assinatura do webhook Meta
  if (!verifyMetaSignature(await req.clone().text(), signature)) {
    return new Response('Unauthorized', { status: 401 })
  }

  const body = await req.json()

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // Processa evento do Meta
  await supabase.from('meta_webhook_events').insert({
    event_type: body.object,
    payload: body,
    received_at: new Date().toISOString(),
  })

  return new Response(JSON.stringify({ ok: true }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
```

---

## Checklist Supabase

- [ ] RLS habilitado em TODAS as tabelas expostas
- [ ] Policies explícitas para SELECT, INSERT, UPDATE, DELETE
- [ ] Funções helper `auth.user_organization_id()` e `auth.user_role()` criadas
- [ ] Service role key NUNCA exposta no client (apenas server-side)
- [ ] Buckets de Storage configurados (public vs private)
- [ ] RLS de Storage policies configuradas
- [ ] Realtime habilitado apenas nas tabelas que precisam
- [ ] Edge Functions com validação de auth/assinatura
- [ ] PITR habilitado (plano Pro+)
- [ ] Policies testadas com diferentes roles (owner, admin, viewer)
