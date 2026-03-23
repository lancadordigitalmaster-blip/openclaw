#!/usr/bin/env python3
"""Cria campanha Andromeda Gabriela em act_553368457476412 (conta com permissao API)"""

import subprocess, json, os

# Carregar .env central
for line in open(os.path.expanduser("~/.openclaw/.env")):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1); os.environ.setdefault(k, v)

META_TOKEN = os.environ.get("META_ADS_ACCESS_TOKEN", "")
ACCOUNT = os.environ.get("META_AD_ACCOUNT_FORLAN", "act_553368457476412")
PAGE_ID = os.environ.get("META_PAGE_ID", "111242098624806")
IG_ID = os.environ.get("META_INSTAGRAM_ACTOR_ID", "17841407489358706")
GABI_WPP = os.environ.get("GABI_WHATSAPP", "5573999788860")

def api_post(endpoint, data_dict):
    cmd = ["curl", "-s", "-X", "POST", f"https://graph.facebook.com/v21.0/{endpoint}"]
    for k, v in data_dict.items():
        cmd += ["-d", f"{k}={v}"]
    result = subprocess.check_output(cmd)
    return json.loads(result)

# ─── STEP 1: Campanha CBO ────────────────────────────────────────────────────
print("=== [1/3] CAMPANHA ===")
camp = api_post(f"{ACCOUNT}/campaigns", {
    "name": "21/03 | Andromeda | Gabriela | CBO",
    "objective": "OUTCOME_ENGAGEMENT",
    "status": "PAUSED",
    "buying_type": "AUCTION",
    "special_ad_categories": "[]",
    "daily_budget": "6000",   # R$60/dia em centavos
})
camp_id = camp.get("id")
if not camp_id:
    print("ERRO campanha:", camp)
    exit(1)
print(f"  Campanha: {camp_id}")

# ─── STEP 2: 3 Adsets ────────────────────────────────────────────────────────
targeting = json.dumps({
    "age_min": 25, "age_max": 55,
    "geo_locations": {"countries": ["BR"]},
    "publisher_platforms": ["instagram"],
    "instagram_positions": ["stream", "story", "explore", "reels"]
})

promoted_obj = json.dumps({"page_id": PAGE_ID})

adsets_def = [
    "Gabriela | Imobiliario + Agencias",
    "Gabriela | Empresarios",
    "Gabriela | Varejo + Vendas",
]

print("\n=== [2/3] ADSETS ===")
adset_ids = []
for name in adsets_def:
    r = api_post(f"{ACCOUNT}/adsets", {
        "name": name,
        "campaign_id": camp_id,
        "optimization_goal": "CONVERSATIONS",
        "billing_event": "IMPRESSIONS",
        "bid_strategy": "LOWEST_COST_WITH_BID_CAP",
        "bid_amount": "2000",
        "destination_type": "WHATSAPP",
        "promoted_object": promoted_obj,
        "targeting": targeting,
        "status": "PAUSED",
    })
    as_id = r.get("id")
    if not as_id:
        print(f"  ERRO adset {name}:", r)
        adset_ids.append(None)
    else:
        print(f"  {name}: {as_id}")
        adset_ids.append(as_id)

# ─── STEP 3: Criativos + Ads (2 por adset) ───────────────────────────────────
creatives_per_adset = [
    # Adset 0 — Imob + Agencias
    [
        ("AdsValidado02", "60c4f597879bef0e7e8e78a168b662f9",
         "Solicite seu orcamento",
         "Seu produto e bom, mas o marketing nao acompanha?\n\nA Wolf estrutura sua estrategia de marketing do zero — trafego, criativos e funil completo.\n\nSolicite um orcamento sem compromisso"),
        ("AdsValidado", "7e3ccb28d33541d0e4a931b23b3adb2c",
         "Contrate agora mesmo",
         "Chega de ter dor de cabeca com marketing.\nTenha uma equipe especializada trabalhando para seu negocio!\n\nAgilidade + Qualidade + Custo beneficio\n\nPeca seu orcamento"),
    ],
    # Adset 1 — Empresarios
    [
        ("Feed4", "92223eb2fdcc6e4a20e07c07ef37db2a",
         "Solicite seu orcamento",
         "Voce nao perde clientes por falta de talento!\nPerde porque ninguem consegue entregar tudo sozinho.\n\nDesign + Trafego + Estrategia\nTudo em um so lugar.\n\nSolicite um orcamento"),
        ("Estrutura", "54c890aa021c785fcd2c3f374ef5df71",
         "Quero crescer com estrutura",
         "Crescer exige estrutura.\nMas montar uma equipe de marketing inteira custa caro.\n\nA Wolf e sua agencia completa: estrategia, trafego, design e execucao.\n\nPeca seu orcamento sem compromisso"),
    ],
    # Adset 2 — Varejo + Vendas
    [
        ("Ads14", "675ab4a99dea1cad062c228f3de4cab3",
         "Quero aumentar minhas vendas",
         "Estruturamos marketing que gera clientes reais para empresas que querem escalar\n\nEstrategia + Criatividade + Execucao\nTudo em um so lugar.\n\nFale com nossa consultora agora"),
        ("AdsValidado02", "60c4f597879bef0e7e8e78a168b662f9",
         "Solicite seu orcamento",
         "Seu produto e bom, mas o marketing nao acompanha?\n\nA Wolf estrutura sua estrategia de marketing do zero — trafego, criativos e funil completo.\n\nSolicite um orcamento sem compromisso"),
    ],
]

print("\n=== [3/3] CRIATIVOS + ADS ===")
ads_created = []
for i, (as_id, creatives) in enumerate(zip(adset_ids, creatives_per_adset)):
    if not as_id:
        print(f"  Adset {i} sem ID — pulando")
        continue
    adset_name = adsets_def[i]
    for cr_name, image_hash, titulo, copy in creatives:
        oss = json.dumps({
            "page_id": PAGE_ID,
            "instagram_user_id": IG_ID,
            "link_data": {
                "link": f"https://api.whatsapp.com/send?phone={GABI_WPP}",
                "message": copy,
                "name": titulo,
                "image_hash": image_hash,
                "call_to_action": {
                    "type": "WHATSAPP_MESSAGE",
                    "value": {"app_destination": "WHATSAPP"}
                }
            }
        })
        # Criar criativo
        cr = api_post(f"{ACCOUNT}/adcreatives", {
            "name": f"Gabi | {cr_name} | {adset_name[:20]}",
            "object_story_spec": oss,
        })
        cr_id = cr.get("id")
        if not cr_id:
            err = cr.get('error', {}).get('message', str(cr))
            print(f"  CRIATIVO ERRO {cr_name}: {err[:80]}")
            continue
        # Criar ad
        ad = api_post(f"{ACCOUNT}/ads", {
            "name": f"Gabi | {adset_name[:25]} | {cr_name}",
            "adset_id": as_id,
            "creative": json.dumps({"creative_id": cr_id}),
            "status": "PAUSED",
        })
        ad_id = ad.get("id")
        if not ad_id:
            err = ad.get('error', {}).get('message', str(ad))
            print(f"  AD ERRO {cr_name}: {err[:80]}")
        else:
            print(f"  OK  | {adset_name[:30]} | {cr_name} → ad={ad_id}")
            ads_created.append({"adset": adset_name, "creative": cr_name, "ad_id": ad_id, "cr_id": cr_id})

# ─── RESUMO FINAL ────────────────────────────────────────────────────────────
print(f"""
╔══════════════════════════════════════════════╗
║  CAMPANHA ANDROMEDA GABRIELA — CRIADA ✅     ║
╚══════════════════════════════════════════════╝
  Conta:     {ACCOUNT}
  Campanha:  {camp_id}
  Adsets:    {len([a for a in adset_ids if a])} criados
  Ads:       {len(ads_created)} criados (PAUSADOS)
  Budget:    R$60/dia (CBO)
  WPP:       Gabriela ({GABI_WPP})
  Status:    PAUSADA — aguardando ativacao por Netto
""")
