#!/usr/bin/env python3
"""
GR Veículos — Relatório Diário de Campanhas Meta Ads
Gera relatório do dia anterior e envia para Netto no Telegram
"""

import os
import sys
import json
import urllib.request
import urllib.parse
from datetime import datetime, timedelta
import subprocess

# --- Config ---
TOKEN = os.environ.get("META_TOKEN_GR_VEICULOS", "")
ACCOUNT_ID = os.environ.get("META_ACCOUNT_GR_VEICULOS", "1221676633470141")
API_VERSION = "v19.0"
BASE_URL = f"https://graph.facebook.com/{API_VERSION}"

def api_get(path, params):
    params["access_token"] = TOKEN
    url = f"{BASE_URL}{path}?{urllib.parse.urlencode(params)}"
    with urllib.request.urlopen(url) as r:
        return json.loads(r.read())

def get_insights(since, until):
    return api_get(f"/act_{ACCOUNT_ID}/insights", {
        "fields": "campaign_name,campaign_id,spend,reach,impressions,actions,cost_per_action_type",
        "time_range": json.dumps({"since": since, "until": until}),
        "level": "campaign",
    })

def extract_conv(actions):
    for a in (actions or []):
        if a["action_type"] == "onsite_conversion.messaging_conversation_started_7d":
            return int(a["value"])
    return 0

def extract_cpconv(cost_per_action):
    for a in (cost_per_action or []):
        if a["action_type"] == "onsite_conversion.messaging_conversation_started_7d":
            return float(a["value"])
    return 0.0

def freq(impressoes, alcance):
    return round(impressoes / alcance, 2) if alcance else 0

def taxa_conv(conversas, alcance):
    return round((conversas / alcance) * 100, 2) if alcance else 0

def status_emoji(cpconv):
    if cpconv == 0: return "⚪"
    if cpconv <= 1.50: return "✅"
    if cpconv <= 2.50: return "🟡"
    return "🔴"

def build_report(data, since, until):
    campanhas = []
    for c in data:
        conv = extract_conv(c.get("actions", []))
        cpconv = extract_cpconv(c.get("cost_per_action_type", []))
        gasto = float(c.get("spend", 0))
        alcance = int(c.get("reach", 0))
        impressoes = int(c.get("impressions", 0))
        if conv == 0 and cpconv == 0 and gasto > 0:
            cpconv = round(gasto / 1, 2)  # fallback
        campanhas.append({
            "nome": c["campaign_name"].replace("13.03 |  Engajamento Wpp ", "").strip(),
            "gasto": gasto,
            "alcance": alcance,
            "impressoes": impressoes,
            "conversas": conv,
            "cpconv": cpconv,
            "freq": freq(impressoes, alcance),
            "taxa": taxa_conv(conv, alcance),
        })

    # Ordena por conversas desc
    campanhas.sort(key=lambda x: x["conversas"], reverse=True)

    total_gasto = sum(c["gasto"] for c in campanhas)
    total_conv = sum(c["conversas"] for c in campanhas)
    total_alcance = sum(c["alcance"] for c in campanhas)
    cpconv_medio = round(total_gasto / total_conv, 2) if total_conv else 0

    # Formata datas
    d_since = datetime.strptime(since, "%Y-%m-%d").strftime("%d/%m")
    d_until = datetime.strptime(until, "%Y-%m-%d").strftime("%d/%m/%Y")

    lines = []
    lines.append("🐺 *WOLF AGENCY — RELATÓRIO DE PERFORMANCE*\n")
    lines.append(f"👤 Cliente: *GR Veículos*")
    lines.append(f"🗓 Período: {d_since} a {d_until}")
    lines.append("🎯 Objetivo: Conversas Iniciadas via WhatsApp\n")
    lines.append("━━━━━━━━━━━━━━━━━━━━")
    lines.append("🏆 *CAMPANHAS*")
    lines.append("━━━━━━━━━━━━━━━━━━━━\n")

    for c in campanhas:
        emoji = status_emoji(c["cpconv"])
        lines.append(f"📌 *{c['nome']}* {emoji}")
        lines.append(f"▸ Investimento: R$ {c['gasto']:.2f}")
        lines.append(f"▸ Alcance: {c['alcance']:,} pessoas".replace(",", "."))
        lines.append(f"▸ Impressões: {c['impressoes']:,}".replace(",", "."))
        lines.append(f"▸ Conversas iniciadas: *{c['conversas']}*")
        lines.append(f"▸ Custo por conversa: *R$ {c['cpconv']:.2f}*")
        lines.append(f"▸ Taxa de conversão: {c['taxa']}%\n")

    lines.append("━━━━━━━━━━━━━━━━━━━━")
    lines.append("📦 *CONSOLIDADO DO PERÍODO*")
    lines.append("━━━━━━━━━━━━━━━━━━━━")
    lines.append(f"💰 Total investido: *R$ {total_gasto:.2f}*")
    lines.append(f"👥 Total alcançado: *{total_alcance:,} pessoas*".replace(",", "."))
    lines.append(f"💬 Total de conversas: *{total_conv}*")
    lines.append(f"📉 CPConv médio: *R$ {cpconv_medio:.2f}*\n")

    # Análise automática
    lines.append("━━━━━━━━━━━━━━━━━━━━")
    lines.append("💡 *ANÁLISE WOLF*")
    lines.append("━━━━━━━━━━━━━━━━━━━━")

    if campanhas:
        melhor = campanhas[0]
        lines.append(f"🥇 *{melhor['nome']}* lidera com R$ {melhor['cpconv']:.2f}/conv e taxa de {melhor['taxa']}%")

        alertas = [c for c in campanhas if c["cpconv"] > 3.0 and c["conversas"] > 0]
        for a in alertas:
            lines.append(f"⚠️ *{a['nome']}* com CPConv elevado (R$ {a['cpconv']:.2f}) — revisar criativos")

        freq_alta = [c for c in campanhas if c["freq"] > 2.5]
        for f in freq_alta:
            lines.append(f"🔁 *{f['nome']}* com frequência {f['freq']} — público com sinais de fadiga")

        if not alertas and not freq_alta:
            lines.append("✅ Todas as campanhas dentro dos parâmetros normais")

    lines.append("\n_Relatório gerado automaticamente por Wolf Agency · @wolfpacks_")

    return "\n".join(lines)


def main():
    if not TOKEN:
        print("ERRO: META_TOKEN_GR_VEICULOS não encontrado no ambiente")
        sys.exit(1)

    hoje = datetime.now()

    # Período via modo ou datas customizadas
    modo = sys.argv[1] if len(sys.argv) >= 2 else "daily"

    if modo == "daily":
        ontem = (hoje - timedelta(days=1)).strftime("%Y-%m-%d")
        since = ontem
        until = ontem
    elif modo == "weekly":
        # Semana anterior: seg a dom
        dias_desde_seg = hoje.weekday()  # 0=seg
        ultima_seg = hoje - timedelta(days=dias_desde_seg + 7)
        ultimo_dom = ultima_seg + timedelta(days=6)
        since = ultima_seg.strftime("%Y-%m-%d")
        until = ultimo_dom.strftime("%Y-%m-%d")
    elif modo == "monthly":
        # Mês anterior completo
        primeiro_dia_mes_atual = hoje.replace(day=1)
        ultimo_dia_mes_ant = primeiro_dia_mes_atual - timedelta(days=1)
        primeiro_dia_mes_ant = ultimo_dia_mes_ant.replace(day=1)
        since = primeiro_dia_mes_ant.strftime("%Y-%m-%d")
        until = ultimo_dia_mes_ant.strftime("%Y-%m-%d")
    elif len(sys.argv) >= 3:
        since = sys.argv[1]
        until = sys.argv[2]
    else:
        ontem = (hoje - timedelta(days=1)).strftime("%Y-%m-%d")
        since = ontem
        until = ontem

    print(f"Buscando dados de {since} a {until}...", file=sys.stderr)

    try:
        result = get_insights(since, until)
        data = result.get("data", [])

        if not data:
            report = f"📊 *GR Veículos — {since}*\n\nNenhum dado encontrado para o período. Verifique se as campanhas estiveram ativas."
        else:
            report = build_report(data, since, until)

        print(report)

    except Exception as e:
        print(f"ERRO ao buscar dados da API: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
