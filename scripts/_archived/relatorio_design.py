#!/usr/bin/env python3
"""
Relatório Diário de Design — Wolf Agency
Cron: b2f95e3a-7c4d-4a1b-8e6f-9d0c1b2a3e4f
Executa às 22h BRT.
"""
import os
import sys
import json
import requests
from datetime import datetime, timedelta
import time

# Configurações
CLICKUP_API_TOKEN = os.getenv("CLICKUP_API_TOKEN", "pk_3138195_20ML6OGADSAAXFV5S4S2PONONA5X3UGP")
LISTAS = {
    "Producao DSGN": "901306028132",
    "Nucleo Criativo": "901306028133"
}
FIELD_DESIGN = "b9b3676c-f119-48cf-851d-8ebd83e5011f"

# Mapeamento índice → nome | meta_diaria
# índice 0-based no campo value
DESIGNERS = {
    1: {"nome": "Eliedson", "meta": 8},
    2: {"nome": "Rodrigo Bispo", "meta": None},
    3: {"nome": "Leoneli", "meta": 12},
    4: {"nome": "Felipe", "meta": None},
    5: {"nome": "Levi", "meta": 2},
    6: {"nome": "Pedro", "meta": 17},
    7: {"nome": "Rodrigo Web", "meta": None},
    11: {"nome": "Abilio", "meta": 14}
}

# Calcular timestamps (America/Sao_Paulo)
# hoje 00:00 BRT em Unix ms
# agora em Unix ms
def get_timestamps():
    from datetime import datetime, timezone, timedelta
    # Fuso America/Sao_Paulo = UTC-3
    tz_offset = timedelta(hours=-3)
    agora = datetime.now(timezone.utc) + tz_offset
    hoje_inicio = agora.replace(hour=0, minute=0, second=0, microsecond=0)
    hoje_inicio_utc = hoje_inicio - tz_offset
    hoje_fim_utc = datetime.now(timezone.utc)
    hoje_inicio_ms = int(hoje_inicio_utc.timestamp() * 1000)
    hoje_fim_ms = int(hoje_fim_utc.timestamp() * 1000)
    return hoje_inicio_ms, hoje_fim_ms

def fetch_tasks(list_id, params):
    url = f"https://api.clickup.com/api/v2/list/{list_id}/task"
    headers = {"Authorization": CLICKUP_API_TOKEN}
    response = requests.get(url, headers=headers, params=params)
    if response.status_code != 200:
        print(f"Erro na lista {list_id}: {response.status_code} {response.text}")
        return []
    data = response.json()
    return data.get("tasks", [])

def get_designer_index(task):
    custom_fields = task.get("custom_fields", [])
    for field in custom_fields:
        if field.get("id") == FIELD_DESIGN:
            value = field.get("value")
            if value is not None:
                # valor pode ser índice inteiro ou string
                try:
                    return int(value)
                except:
                    return None
    return None

def main():
    hoje_inicio_ms, hoje_fim_ms = get_timestamps()
    print(f"Hoje início: {hoje_inicio_ms} ({datetime.fromtimestamp(hoje_inicio_ms/1000)})")
    print(f"Hoje fim:    {hoje_fim_ms} ({datetime.fromtimestamp(hoje_fim_ms/1000)})")
    
    # PASSO 1 — FINALIZADAS HOJE POR DESIGNER
    contagem_finalizadas = {idx: 0 for idx in DESIGNERS}
    for list_name, list_id in LISTAS.items():
        params = {
            "statuses[]": "finalizada",
            "date_closed_gt": hoje_inicio_ms,
            "date_closed_lt": hoje_fim_ms,
            "include_closed": "true",
            "subtasks": "false"
        }
        tasks = fetch_tasks(list_id, params)
        for task in tasks:
            idx = get_designer_index(task)
            if idx is not None and idx in DESIGNERS:
                contagem_finalizadas[idx] += 1
    
    # PASSO 2 — ATRASADAS COM MOTIVO
    atrasadas_equipe = []
    atrasadas_cliente = []
    atrasadas_bloqueadas = []
    for list_name, list_id in LISTAS.items():
        params = {
            "overdue": "true",
            "subtasks": "false"
        }
        tasks = fetch_tasks(list_id, params)
        for task in tasks:
            idx = get_designer_index(task)
            if idx is None:
                continue
            designer_name = DESIGNERS[idx]["nome"] if idx in DESIGNERS else f"Desconhecido ({idx})"
            status = task.get("status", {}).get("status", "").lower()
            # Normalizar remover acentos (simplificado)
            status_norm = status
            due_date = task.get("due_date")
            if due_date:
                due_date_ms = int(due_date)
                atraso_dias = int((hoje_fim_ms - due_date_ms) / 86400000)
            else:
                atraso_dias = 0
            task_info = {
                "id": task.get("id"),
                "name": task.get("name"),
                "designer": designer_name,
                "status": status,
                "atraso_dias": atraso_dias
            }
            # Classificar
            if any(s in status_norm for s in ["apontamentos", "para fazer", "produzindo", "em alteracao", "conferencia interna", "formatos"]):
                atrasadas_equipe.append(task_info)
            elif any(s in status_norm for s in ["aguardando cliente", "enviado ao cliente", "ajuste", "material reprovado"]):
                atrasadas_cliente.append(task_info)
            elif any(s in status_norm for s in ["pausado", "bloqueado", "backlog congelado"]):
                atrasadas_bloqueadas.append(task_info)
            else:
                # padrão equipe
                atrasadas_equipe.append(task_info)
    
    # Ordenar atrasadas equipe por atraso decrescente
    atrasadas_equipe.sort(key=lambda x: x["atraso_dias"], reverse=True)
    
    # Gerar relatório
    hoje_str = datetime.now().strftime("%d/%m")
    linhas = []
    linhas.append("━━━━━━━━━━━━━━━━━━━━━━")
    linhas.append(f"📊 Design Wolf — [{hoje_str}]")
    linhas.append("━━━━━━━━━━━━━━━━━━━━━━")
    linhas.append("✅ FINALIZADAS HOJE")
    
    # Listar designers com finalizações >0 ou meta definida
    for idx, info in DESIGNERS.items():
        nome = info["nome"]
        meta = info["meta"]
        count = contagem_finalizadas.get(idx, 0)
        if count == 0 and meta is None:
            continue
        if meta is None:
            linhas.append(f"  {nome:<15} ⚪  {count}")
        else:
            atingiu = count >= meta
            simbolo = "✅" if atingiu else "❌"
            linhas.append(f"  {nome:<15} {simbolo} {count:>2}/{meta}")
    
    # Totais atrasadas
    total_atrasadas = len(atrasadas_equipe) + len(atrasadas_cliente) + len(atrasadas_bloqueadas)
    linhas.append("")
    linhas.append(f"🔴 TAREFAS ATRASADAS: {total_atrasadas}")
    linhas.append(f"  Atrasadas:   {len(atrasadas_equipe)}")
    linhas.append(f"  Ag. cliente: {len(atrasadas_cliente)}")
    linhas.append(f"  Bloqueadas:  {len(atrasadas_bloqueadas)}")
    
    if atrasadas_equipe:
        linhas.append("")
        linhas.append("⚠️ Mais críticas:")
        for task in atrasadas_equipe[:3]:
            id_curto = task["id"][:8] if task["id"] else "?"
            linhas.append(f"  {task['name']} (#{id_curto}) — {task['atraso_dias']}d — {task['designer']}")
    
    linhas.append("━━━━━━━━━━━━━━━━━━━━━━")
    
    relatorio = "\n".join(linhas)
    print(relatorio)
    
    # Enviar via Telegram (Netto ID: 789352357)
    # Usar a tool message
    # Para fins de debug, vamos salvar em arquivo também
    with open("relatorio_design.txt", "w") as f:
        f.write(relatorio)
    
    return relatorio

if __name__ == "__main__":
    relatorio = main()
    sys.exit(0)