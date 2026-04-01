#!/usr/bin/env python3
"""Cria ads Andromeda Gabriela — reutiliza imagens, troca WPP para Gabriela"""

import subprocess, json, os

# Carregar .env central
for line in open(os.path.expanduser("~/.openclaw/.env")):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1); os.environ.setdefault(k, v)

META_TOKEN = os.environ.get("META_ADS_ACCESS_TOKEN", "")
ACCOUNT = os.environ.get("META_AD_ACCOUNT_WOLF26", "act_1583430182930723")
PAGE_ID = os.environ.get("META_PAGE_ID", "111242098624806")
IG_ID = os.environ.get("META_INSTAGRAM_ACTOR_ID", "17841407489358706")
GABI_WPP = os.environ.get("GABI_WHATSAPP", "5573999788860")

# Adsets criados
ADSETS = {
    "AS1_Imob_Agencias":  "120244861216910409",
    "AS2_Empresarios":    "120244861217210409",
    "AS3_Varejo_Vendas":  "120244861217810409",
}

# Criativos base — pegar imagens dos top performers e adaptar para Gabriela
# Selecionando os 2 melhores por adset baseado no historico
CREATIVES_TO_CREATE = [
    # (adset_key, ad_name, image_hash, titulo, copy)
    # ADSET 1 — Imob + Agencias
    ("AS1_Imob_Agencias", "Gabi | Imob+Ag | AdsV02",
     "60c4f597879bef0e7e8e78a168b662f9",
     "Solicite seu orcamento",
     "Seu produto e bom, mas o marketing nao acompanha?\n\nA Wolf estrutura sua estrategia de marketing do zero — trafego, criativos e funil completo.\n\nSolicite um orcamento sem compromisso"),
    ("AS1_Imob_Agencias", "Gabi | Imob+Ag | AdsV",
     "7e3ccb28d33541d0e4a931b23b3adb2c",
     "Contrate agora mesmo",
     "Chega de ter dor de cabeca com marketing.\nTenha uma equipe especializada trabalhando para seu negocio!\n\nAgilidade + Qualidade + Custo beneficio\n\nPeca seu orcamento"),
    # ADSET 2 — Empresarios
    ("AS2_Empresarios", "Gabi | Emp | Feed4",
     "92223eb2fdcc6e4a20e07c07ef37db2a",
     "Solicite seu orcamento",
     "Voce nao perde clientes por falta de talento!\nPerde porque ninguem consegue entregar tudo sozinho.\n\nDesign + Trafego + Estrategia\nTudo em um so lugar.\n\nSolicite um orcamento"),
    ("AS2_Empresarios", "Gabi | Emp | Estrutura",
     "54c890aa021c785fcd2c3f374ef5df71",
     "Quero crescer com estrutura",
     "Crescer exige estrutura.\nMas montar uma equipe de marketing inteira custa caro.\n\nA Wolf e sua agencia completa: estrategia, trafego, design e execucao.\n\nPeca seu orcamento sem compromisso"),
    # ADSET 3 — Varejo + Vendas
    ("AS3_Varejo_Vendas", "Gabi | Varejo | Ads14",
     "675ab4a99dea1cad062c228f3de4cab3",
     "Quero aumentar minhas vendas",
     "Estruturamos marketing que gera clientes reais para empresas que querem escalar\n\nEstrategia + Criatividade + Execucao\nTudo em um so lugar.\n\nFale com nossa consultora agora"),
    ("AS3_Varejo_Vendas", "Gabi | Varejo | AdsV02",
     "60c4f597879bef0e7e8e78a168b662f9",
     "Solicite seu orcamento",
     "Seu produto e bom, mas o marketing nao acompanha?\n\nA Wolf estrutura sua estrategia de marketing do zero — trafego, criativos e funil completo.\n\nSolicite um orcamento sem compromisso"),
]

def api_post(endpoint, data_dict):
    cmd = ["curl", "-s", "-X", "POST", f"https://graph.facebook.com/v21.0/{endpoint}"]
    for k, v in data_dict.items():
        cmd += ["-d", f"{k}={v}"]
    result = subprocess.check_output(cmd)
    return json.loads(result)

results = []
print("=== CRIANDO CRIATIVOS + ADS PARA GABRIELA ===\n")

for adset_key, ad_name, image_hash, titulo, copy in CREATIVES_TO_CREATE:
    adset_id = ADSETS[adset_key]

    # Montar object_story_spec
    oss = {
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
    }

    # Criar criativo
    cr = api_post(f"{ACCOUNT}/adcreatives", {
        "name": f"{ad_name} | Gabriela",
        "object_story_spec": json.dumps(oss),
        "degrees_of_freedom_spec": json.dumps({"creative_features_spec": {"standard_enhancements": {"enroll_status": "OPT_OUT"}}})
    })

    cr_id = cr.get("id", "ERROR")
    if "error" in cr:
        err_msg = cr['error'].get('error_user_msg', cr['error'].get('message', str(cr['error'])))
        print(f"  CRIATIVO ERRO — {ad_name}: {err_msg}")
        results.append({"ad": ad_name, "status": "ERROR_CREATIVE", "detail": err_msg})
        continue

    print(f"  Criativo OK — {ad_name}: {cr_id}")

    # Criar ad
    ad = api_post(f"{ACCOUNT}/ads", {
        "name": ad_name,
        "adset_id": adset_id,
        "creative": json.dumps({"creative_id": cr_id}),
        "status": "PAUSED",
    })

    ad_id = ad.get("id", "ERROR")
    if "error" in ad:
        err_msg = ad['error'].get('error_user_msg', ad['error'].get('message', str(ad['error'])))
        print(f"  AD ERRO — {ad_name}: {err_msg}")
        results.append({"ad": ad_name, "creative_id": cr_id, "status": "ERROR_AD", "detail": err_msg})
    else:
        print(f"  Ad OK — {ad_name}: {ad_id}")
        results.append({"ad": ad_name, "creative_id": cr_id, "ad_id": ad_id, "status": "OK"})

print("\n=== RESUMO ===")
ok = [r for r in results if r["status"] == "OK"]
err = [r for r in results if r["status"] != "OK"]
print(f"Criados: {len(ok)}/{len(results)}")
for r in ok:
    print(f"  OK  | {r['ad']} | ad_id={r['ad_id']}")
for r in err:
    print(f"  ERR | {r['ad']} | {r['detail'][:80]}")
