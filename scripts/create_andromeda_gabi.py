#!/usr/bin/env python3
"""Cria campanha Andromeda Gabriela — Wolf Nova 26"""

import os
import json
import subprocess

# Config
META_TOKEN = subprocess.check_output(
    "grep META_ADS_ACCESS_TOKEN /Users/thomasgirotto/.openclaw/.env | head -1 | cut -d= -f2",
    shell=True
).decode().strip()

ACCOUNT = "act_1583430182930723"
PAGE_ID = "111242098624806"
IG_ID = "17841407489358706"
CAMP_ID = "120244861197820409"  # ja criada

# Criativos validados da campanha ancora (LP Whatsapp Mariana)
CREATIVES = {
    "Ads01": "26659315270327446",
    "Ads02": "915548458029206",
    "Ads03": "1453956399708890",
    "Ads04": "2989543541436883",
}

def api_post(endpoint, data):
    data["access_token"] = META_TOKEN
    cmd = ["curl", "-s", "-X", "POST", f"https://graph.facebook.com/v21.0/{endpoint}"]
    for k, v in data.items():
        cmd += ["-d", f"{k}={v}"]
    result = subprocess.check_output(cmd)
    return json.loads(result)

def api_get(endpoint, params):
    params["access_token"] = META_TOKEN
    cmd = ["curl", "-s", "-G", f"https://graph.facebook.com/v21.0/{endpoint}"]
    for k, v in params.items():
        cmd += ["-d", f"{k}={v}"]
    result = subprocess.check_output(cmd)
    return json.loads(result)

targeting = json.dumps({
    "age_min": 25,
    "age_max": 55,
    "geo_locations": {"countries": ["BR"]},
    "publisher_platforms": ["instagram"],
    "instagram_positions": ["stream", "story", "explore", "reels"]
})

adsets_config = [
    ("Gabriela | Imobiliario + Agencias", "AS1"),
    ("Gabriela | Empresarios", "AS2"),
    ("Gabriela | Varejo + Vendas", "AS3"),
]

adset_ids = {}
print("=== CRIANDO ADSETS ===")
for name, key in adsets_config:
    r = api_post(f"{ACCOUNT}/adsets", {
        "name": name,
        "campaign_id": CAMP_ID,
        "optimization_goal": "CONVERSATIONS",
        "billing_event": "IMPRESSIONS",
        "bid_strategy": "LOWEST_COST_WITH_BID_CAP",
        "bid_amount": "2000",
        "destination_type": "WHATSAPP",
        "promoted_object": json.dumps({"page_id": PAGE_ID}),
        "targeting": targeting,
        "status": "PAUSED",
    })
    adset_id = r.get("id", "ERROR")
    adset_ids[key] = adset_id
    print(f"  {key} ({name}): {adset_id}")
    if "error" in r:
        print(f"    ERRO: {r['error']}")

print("\n=== CRIANDO ADS (2 por adset) ===")
# Adset 1: Ads01 + Ads02
# Adset 2: Ads01 + Ads03
# Adset 3: Ads01 + Ads04
adset_creative_map = [
    ("AS1", "Ads01", "Ads02"),
    ("AS2", "Ads01", "Ads03"),
    ("AS3", "Ads01", "Ads04"),
]

created_ads = []
for adset_key, cr_a, cr_b in adset_creative_map:
    adset_id = adset_ids.get(adset_key, "ERROR")
    if adset_id == "ERROR":
        print(f"  Skipping {adset_key} — adset nao criado")
        continue
    for cr_key in [cr_a, cr_b]:
        creative_id = CREATIVES[cr_key]
        ad_name = f"Gabi | {adset_key} | {cr_key}"
        r = api_post(f"{ACCOUNT}/ads", {
            "name": ad_name,
            "adset_id": adset_id,
            "creative": json.dumps({"creative_id": creative_id}),
            "status": "PAUSED",
        })
        ad_id = r.get("id", "ERROR")
        created_ads.append({"name": ad_name, "id": ad_id, "creative": cr_key})
        print(f"  {ad_name}: {ad_id}")
        if "error" in r:
            print(f"    ERRO: {r['error']}")

print("\n=== RESUMO FINAL ===")
print(f"Campanha: {CAMP_ID}")
for k, v in adset_ids.items():
    print(f"  {k}: {v}")
print(f"Ads criados: {len(created_ads)}")
for ad in created_ads:
    print(f"  {ad['name']} ({ad['creative']}): {ad['id']}")
