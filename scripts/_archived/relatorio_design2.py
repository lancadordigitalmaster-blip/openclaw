#!/usr/bin/env python3
"""
Relatório Diário de Design — Wolf Agency
Usa apenas bibliotecas padrão.
"""
import os
import sys
import json
import urllib.request
import urllib.parse
from datetime import datetime, timezone, timedelta

# Configurações
CLICKUP_API_TOKEN = os.getenv("CLICKUP_API_TOKEN", "pk_3138195_20ML6OGADSAAXFV5S4S2PONONA5X3UGP")
LISTAS = {
    "Producao DSGN": "901306028132",
    "Nucleo Criativo": "901306028133"
}
FIELD_DESIGN = "b9b3676c-f119-48cf-851d-8ebd83e5011f"

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

def make_request(url, params=None):
    headers = {"Authorization": CLICKUP_API_TOKEN}
    if params:
        query = urllib.parse.urlencode(params, doseq=True)
        url = f"{url}?{query}"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req) as response:
            data = response.read()
            encoding = response.info().get_content_charset('utf-8')
            return json.loads(data.decode(encoding))
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code}: {e.reason}")
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"URL Error: {e.reason}")
        sys.exit(1)

def get_timestamps():
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
    data = make_request(url, params)
    return data.get("tasks", [])

def get_designer_index(task):
    custom_fields = task.get("custom_fields", [])
    for field in custom_fields:
        if field.get("id") == FIELD_DESIGN:
            value = field.get("value")
            if value is not None:
                try:
                    return int(value)
                except:
                    return None
    return None

def normalize_status(status):
    s = status.lower()
    # remover acentos simples
    s = s.replace("á", "a").replace("ã", "a").replace("â", "a")
    s = s.replace("é", "e").replace("ê", "e")
    s = s.replace("í", "i")
    s = s.replace("ó", "o").replace("ô", "o").replace("õ", "o")
    s = s.replace("ú", "u")
    s = s.replace("ç", "c")
    return s

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
            status_norm = normalize_status(status)
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
                atrasadas_equipe.append(task_info)
    
    atrasadas_equipe.sort(key=lambda x: x["atraso_dias"], reverse=True)
    
    # Gerar relatório
    hoje_str = datetime.now().strftime("%d/%m")
    linhas = []
    linhas.append("━━━━━━━━━━━━━━━━━━━━━━")
    linhas.append(f"📊 Design Wolf — [{hoje_str}]")
    linhas.append("━━━━━━━━━━━━━━━━━━━━━━")
    linhas.append("✅ FINALIZADAS HOJE")
    
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
    
    # Salvar arquivo
    with open("relatorio_design.txt", "w") as f:
        f.write(relatorio)
    
    return relatorio

if __name__ == "__main__":
    relatorio = main()