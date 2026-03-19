#!/usr/bin/env python3
"""
guardiao-relatorio-cliente-patch.py — Aplicar bloco de produtividade M13 ao relatório mensal.

Executar UMA VEZ após o deploy do M13 para atualizar guardiao-relatorio-cliente.py.
Após aplicar, deletar este arquivo.

Uso: python3 guardiao-relatorio-cliente-patch.py
"""
import os, sys

TARGET = os.path.expanduser("~/openclaw/whatsapp-bridge/guardiao-relatorio-cliente.py")

PATCH_MARKER = "# === M13: bloco de produtividade injetado ==="

# Bloco a inserir ANTES da linha de reset de contadores
OLD = """    # Reset contadores mensais após envio"""

NEW = """    # === M13 — Bloco de produtividade por cliente ===============================
    # === M13: bloco de produtividade injetado ===
    if ok:
        # Buscar dados de produtividade do mês por cliente (via atendentes)
        prod_lines = []
        atendentes_data = memory.get("atendentes", {})
        designers_data  = memory.get("designers", {})

        # Produção total do mês
        total_d_pts = sum(
            r.get("productivity", {}).get("points_month", 0)
            for r in designers_data.values()
        )
        total_d_qty = sum(
            r.get("productivity", {}).get("deliveries_month", 0)
            for r in designers_data.values()
        )
        total_a_pts = sum(
            r.get("productivity", {}).get("points_month", 0)
            for r in atendentes_data.values()
        )

        if total_d_qty > 0 or total_a_pts > 0:
            prod_lines += [
                "",
                "📦 *Produção do Mês*",
                f"• Entregas totais (designers): {total_d_qty} · {round(total_d_pts)}pts",
                f"• Briefings totais (atendimento): {round(total_a_pts)}pts",
            ]

        # Top 3 designers por pontuação
        top_designers = sorted(
            [(n, r.get("productivity", {}).get("points_month", 0))
             for n, r in designers_data.items()],
            key=lambda x: -x[1]
        )[:3]
        if top_designers and top_designers[0][1] > 0:
            prod_lines.append("")
            prod_lines.append("🎨 *Top Designers do Mês*")
            medals = ["🥇", "🥈", "🥉"]
            for i, (n, pts) in enumerate(top_designers):
                if pts == 0: continue
                prod_lines.append(f"{medals[i]} *{n}* — {round(pts)}pts")

        # Top 3 atendentes por pontuação
        top_atd = sorted(
            [(n, r.get("productivity", {}).get("points_month", 0),
              r.get("productivity", {}).get("quality_rate", 1.0))
             for n, r in atendentes_data.items()],
            key=lambda x: -x[1]
        )[:3]
        if top_atd and top_atd[0][1] > 0:
            prod_lines.append("")
            prod_lines.append("👥 *Top Atendimento do Mês*")
            medals = ["🥇", "🥈", "🥉"]
            for i, (n, pts, q) in enumerate(top_atd):
                if pts == 0: continue
                q_pct = int(q * 100 / 1.2 * 100)
                prod_lines.append(f"{medals[i]} *{n}* — {round(pts)}pts · qual. {q_pct}%")

        if prod_lines:
            msg_parts += prod_lines

    # Reset contadores mensais após envio"""

if not os.path.exists(TARGET):
    print(f"ERRO: {TARGET} não encontrado")
    sys.exit(1)

with open(TARGET) as f:
    content = f.read()

if PATCH_MARKER in content:
    print("Patch já aplicado — nada a fazer")
    sys.exit(0)

if OLD not in content:
    print("ERRO: Ponto de injeção não encontrado. O arquivo pode ter sido modificado.")
    print("Injetar manualmente o bloco de produtividade antes da linha de reset.")
    sys.exit(1)

content2 = content.replace(OLD, NEW, 1)
with open(TARGET, "w") as f:
    f.write(content2)

print(f"Patch M13 aplicado com sucesso em {TARGET}")
print("Deletar este arquivo após confirmar que o relatório funciona.")
