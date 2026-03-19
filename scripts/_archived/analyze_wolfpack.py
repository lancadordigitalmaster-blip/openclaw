#!/usr/bin/env python3
import json

with open("/tmp/wolfpack_ads.json") as f:
    d = json.load(f)

ads = d.get("data", [])
results = []

for c in ads:
    spend = float(c.get("spend", 0))
    if spend < 20:
        continue
    conv = 0
    cpconv = 0
    for a in c.get("actions", []):
        if a["action_type"] == "onsite_conversion.messaging_conversation_started_7d":
            conv = int(a["value"])
    for a in c.get("cost_per_action_type", []):
        if a["action_type"] == "onsite_conversion.messaging_conversation_started_7d":
            cpconv = float(a["value"])
    results.append({
        "campanha": c.get("campaign_name", "")[:55],
        "ad": c.get("ad_name", "")[:45],
        "gasto": spend,
        "alcance": int(c.get("reach", 0)),
        "ctr": float(c.get("ctr", 0)),
        "freq": float(c.get("frequency", 0)),
        "conv": conv,
        "cpconv": cpconv,
    })

print("=== TOP CRIATIVOS — CONVERSAS ===")
conv_ads = sorted([r for r in results if r["conv"] > 0], key=lambda x: x["conv"], reverse=True)
for r in conv_ads[:10]:
    efic = "CAMPIAO" if r["cpconv"] < 10 else "BOM" if r["cpconv"] < 15 else "OK"
    print(f"[{efic}] {r['conv']} conv | R${r['cpconv']:.2f}/conv | CTR {r['ctr']:.2f}% | R${r['gasto']:.0f} gasto")
    print(f"  Ad: {r['ad']}")
    print(f"  Camp: {r['campanha']}")
    print()

print("=== TOP CRIATIVOS — CTR ===")
ctr_ads = sorted([r for r in results if r["alcance"] > 300], key=lambda x: x["ctr"], reverse=True)
for r in ctr_ads[:8]:
    print(f"CTR {r['ctr']:.2f}% | R${r['gasto']:.0f} | {r['conv']} conv | freq {r['freq']:.2f}")
    print(f"  Ad: {r['ad']}")
    print(f"  Camp: {r['campanha']}")
    print()

# Agrupado por campanha
print("=== TOP CAMPANHAS (consolidado) ===")
camp_data = {}
for r in results:
    k = r["campanha"]
    if k not in camp_data:
        camp_data[k] = {"gasto": 0, "conv": 0}
    camp_data[k]["gasto"] += r["gasto"]
    camp_data[k]["conv"] += r["conv"]

camps = []
for nome, d in camp_data.items():
    cpp = round(d["gasto"] / d["conv"], 2) if d["conv"] > 0 else 0
    camps.append({"nome": nome, "gasto": d["gasto"], "conv": d["conv"], "cpp": cpp})

camps.sort(key=lambda x: x["conv"], reverse=True)
for c in camps[:10]:
    label = "REATIVAR" if c["cpp"] > 0 and c["cpp"] < 12 else "AVALIAR" if c["cpp"] < 20 else "PAUSAR"
    print(f"[{label}] {c['conv']} conv | R${c['cpp']:.2f}/conv | R${c['gasto']:.0f} total")
    print(f"  {c['nome']}")
    print()

total = sum(r["gasto"] for r in results)
total_conv = sum(r["conv"] for r in results)
print(f"TOTAL INVESTIDO: R${total:.2f} | CONVERSAS: {total_conv}")
