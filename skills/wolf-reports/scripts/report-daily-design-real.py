#!/usr/bin/env python3
"""
Relatório Diário de Design — Wolf Agency
Dados REAIS via API ClickUp
Envia para o grupo Wolf | Reports
"""

import os
import sys
import requests
from datetime import datetime, timezone
import pytz

# ─── CONFIG ─────────────────────────────────────────────────────────────────────
CLICKUP_TOKEN = os.getenv('CLICKUP_API_TOKEN', '')
LISTAS = ['901306028132', '901306028133']  # Producao DSGN + Nucleo Criativo
TELEGRAM_GROUP_ID = '-1003823242231'  # Wolf | Reports (ajustar se necessário)
TELEGRAM_BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN', '')

# Custom Field Design
FIELD_ID = 'b9b3676c-f119-48cf-851d-8ebd83e5011f'

# Mapeamento: índice → nome do designer (0-based, conforme API ClickUp)
MAPEAMENTO = {
    1: 'Eliedson',
    2: 'Rodrigo Bispo',
    3: 'Leoneli',
    4: 'Felipe',
    5: 'Levi',
    6: 'Pedro',
    7: 'Rodrigo Web',
    11: 'Abilio'
}

# Metas diárias por designer (None = freelancer, sem meta fixa)
METAS = {
    'Eliedson': 8,
    'Rodrigo Bispo': None,
    'Leoneli': 12,
    'Felipe': None,
    'Levi': 2,
    'Pedro': 17,
    'Rodrigo Web': None,
    'Abilio': 14
}

# ─── FUNÇÕES ────────────────────────────────────────────────────────────────────

def get_timestamps_brt():
    """Retorna timestamps de início e fim do dia em BRT"""
    brt = pytz.timezone('America/Sao_Paulo')
    agora = datetime.now(brt)
    hoje_inicio = agora.replace(hour=0, minute=0, second=0, microsecond=0)
    return int(hoje_inicio.timestamp() * 1000), int(agora.timestamp() * 1000)


def get_finalizadas_hoje(lista_id, hoje_inicio_ms, hoje_fim_ms):
    """Busca tarefas finalizadas hoje na lista"""
    url = f'https://api.clickup.com/api/v2/list/{lista_id}/task'
    params = {
        'statuses[]': 'finalizada',
        'date_closed_gt': hoje_inicio_ms,
        'date_closed_lt': hoje_fim_ms,
        'include_closed': 'true'
    }
    headers = {'Authorization': CLICKUP_TOKEN}
    
    try:
        resp = requests.get(url, params=params, headers=headers, timeout=30)
        resp.raise_for_status()
        return resp.json().get('tasks', [])
    except Exception as e:
        print(f'Erro ao buscar finalizadas: {e}', file=sys.stderr)
        return []


def get_atrasadas(lista_id):
    """Busca tarefas atrasadas (overdue)"""
    url = f'https://api.clickup.com/api/v2/list/{lista_id}/task'
    params = {'overdue': 'true', 'subtasks': 'false'}
    headers = {'Authorization': CLICKUP_TOKEN}
    
    try:
        resp = requests.get(url, params=params, headers=headers, timeout=30)
        resp.raise_for_status()
        return resp.json().get('tasks', [])
    except Exception as e:
        print(f'Erro ao buscar atrasadas: {e}', file=sys.stderr)
        return []


def extrair_designer(task):
    """Extrai nome do designer do custom field"""
    for field in task.get('custom_fields', []):
        if field.get('id') == FIELD_ID:
            idx = field.get('value')
            if idx is not None and idx in MAPEAMENTO:
                return MAPEAMENTO[idx]
    return None


def classificar_status(status_str):
    """Classifica status em grupos"""
    status_lower = status_str.lower().replace('ã', 'a').replace('é', 'e').replace('í', 'i').replace('ó', 'o').replace('ú', 'u')
    
    grupo_equipe = ['apontamentos', 'para fazer', 'produzindo', 'em alteracao', 'conferencia interna', 'formatos', 'alteracao']
    grupo_cliente = ['aguardando cliente', 'enviado ao cliente', 'ajuste', 'material reprovado', 'aguardando aprovacao']
    grupo_bloqueado = ['pausado', 'bloqueado', 'backlog congelado']
    
    for s in grupo_equipe:
        if s in status_lower:
            return 'equipe'
    for s in grupo_cliente:
        if s in status_lower:
            return 'cliente'
    for s in grupo_bloqueado:
        if s in status_lower:
            return 'bloqueado'
    
    return 'equipe'  # default


def calcular_dias_atraso(due_date_ms, agora_ms):
    """Calcula dias de atraso"""
    if not due_date_ms:
        return 0
    # Converte pra int se for string
    try:
        due_date_int = int(due_date_ms)
        if due_date_int <= 0:
            return 0
        return round((agora_ms - due_date_int) / 86400000)
    except (ValueError, TypeError):
        return 0


def contar_finalizadas_por_designer(finalizadas):
    """Conta finalizações por designer"""
    contagem = {}
    for task in finalizadas:
        designer = extrair_designer(task)
        if designer:
            contagem[designer] = contagem.get(designer, 0) + 1
    return contagem


def analisar_atrasadas(atrasadas, agora_ms):
    """Analisa tarefas atrasadas por categoria"""
    equipe = []
    cliente = []
    bloqueado = []
    
    for task in atrasadas:
        designer = extrair_designer(task)
        if not designer:
            continue  # ignora sem designer
        
        status = task.get('status', {}).get('status', '')
        categoria = classificar_status(status)
        dias_atraso = calcular_dias_atraso(task.get('due_date'), agora_ms)
        
        item = {
            'nome': task.get('name', 'Sem nome'),
            'id': task.get('id', 'unknown'),
            'designer': designer,
            'dias_atraso': dias_atraso
        }
        
        if categoria == 'equipe':
            equipe.append(item)
        elif categoria == 'cliente':
            cliente.append(item)
        else:
            bloqueado.append(item)
    
    return equipe, cliente, bloqueado


def formatar_status_designer(atual, meta):
    """Formata status com emoji"""
    if meta is None:
        return f'⚪ {atual}'  # sem meta
    if atual >= meta:
        return f'✅ {atual}/{meta}'
    return f'❌ {atual}/{meta}'


def montar_relatorio(contagem_designers, equipe_atrasadas, cliente_atrasadas, bloqueadas_atrasadas):
    """Monta texto do relatório"""
    agora = datetime.now(pytz.timezone('America/Sao_Paulo'))
    data_str = agora.strftime('%d/%m')
    
    linhas = []
    linhas.append('━━━━━━━━━━━━━━━━━━━━━━')
    linhas.append(f'📊 Design Wolf — {data_str}')
    linhas.append('━━━━━━━━━━━━━━━━━━━━━━')
    linhas.append('✅ FINALIZADAS HOJE')
    
    # Ordena designers: primeiro com meta batida, depois os outros
    designers_ordenados = sorted(
        contagem_designers.keys(),
        key=lambda d: (METAS.get(d) is None, -contagem_designers.get(d, 0))
    )
    
    for designer in designers_ordenados:
        atual = contagem_designers.get(designer, 0)
        meta = METAS.get(designer)
        status = formatar_status_designer(atual, meta)
        linhas.append(f'  {designer + ":":<15} {status}')
    
    linhas.append('')
    
    total_atrasadas = len(equipe_atrasadas) + len(cliente_atrasadas) + len(bloqueadas_atrasadas)
    linhas.append(f'🔴 TAREFAS ATRASADAS: {total_atrasadas}')
    linhas.append(f'  Atrasadas (equipe):   {len(equipe_atrasadas)}')
    linhas.append(f'  Ag. cliente:          {len(cliente_atrasadas)}')
    linhas.append(f'  Bloqueadas:           {len(bloqueadas_atrasadas)}')
    
    # Top 3 críticas (maior atraso, grupo equipe)
    if equipe_atrasadas:
        linhas.append('')
        linhas.append('⚠️ Mais críticas:')
        top3 = sorted(equipe_atrasadas, key=lambda x: -x['dias_atraso'])[:3]
        for item in top3:
            id_curto = item['id'][-8:] if len(item['id']) > 8 else item['id']
            linhas.append(f'  {item["nome"][:40]} ({id_curto}) — {item["dias_atraso"]}d — {item["designer"]}')
    
    linhas.append('━━━━━━━━━━━━━━━━━━━━━━')
    linhas.append('')
    linhas.append('_Cobrar Atendimento — nunca Designer_')
    
    return '\n'.join(linhas)


def enviar_telegram(mensagem, chat_id):
    """Envia mensagem via Telegram Bot API"""
    if not TELEGRAM_BOT_TOKEN:
        print('TELEGRAM_BOT_TOKEN não configurado', file=sys.stderr)
        return False
    
    url = f'https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage'
    data = {
        'chat_id': chat_id,
        'text': mensagem,
        'parse_mode': 'Markdown'
    }
    
    try:
        resp = requests.post(url, json=data, timeout=30)
        resp.raise_for_status()
        print(f'✅ Enviado para {chat_id}')
        return True
    except Exception as e:
        print(f'Erro ao enviar Telegram: {e}', file=sys.stderr)
        return False


# ─── MAIN ───────────────────────────────────────────────────────────────────────

def main():
    if not CLICKUP_TOKEN:
        print('❌ CLICKUP_API_TOKEN não configurado no .env', file=sys.stderr)
        sys.exit(1)
    
    print('📊 Relatório Diário de Design — Wolf Agency')
    print('=' * 50)
    
    # Timestamps
    hoje_inicio_ms, hoje_fim_ms = get_timestamps_brt()
    print(f'Período: {hoje_inicio_ms} até {hoje_fim_ms}')
    
    # Buscar finalizadas de todas as listas
    todas_finalizadas = []
    for lista_id in LISTAS:
        print(f'Buscando finalizadas na lista {lista_id}...')
        finalizadas = get_finalizadas_hoje(lista_id, hoje_inicio_ms, hoje_fim_ms)
        todas_finalizadas.extend(finalizadas)
        print(f'  → {len(finalizadas)} tarefas')
    
    # Buscar atrasadas de todas as listas
    todas_atrasadas = []
    for lista_id in LISTAS:
        print(f'Buscando atrasadas na lista {lista_id}...')
        atrasadas = get_atrasadas(lista_id)
        todas_atrasadas.extend(atrasadas)
        print(f'  → {len(atrasadas)} tarefas')
    
    # Contar por designer
    contagem = contar_finalizadas_por_designer(todas_finalizadas)
    print(f'\nDesigners com finalizações: {len(contagem)}')
    
    # Analisar atrasadas
    equipe, cliente, bloqueado = analisar_atrasadas(todas_atrasadas, hoje_fim_ms)
    print(f'Atrasadas: {len(equipe)} equipe, {len(cliente)} cliente, {len(bloqueado)} bloqueado')
    
    # Montar relatório
    relatório = montar_relatorio(contagem, equipe, cliente, bloqueado)
    
    # Imprimir relatório (o cron captura e envia via Telegram)
    print('\n' + relatório)
    print('\n✅ Relatório concluído')
    print(f'\n---GROUP_ID:{TELEGRAM_GROUP_ID}---')


if __name__ == '__main__':
    main()
