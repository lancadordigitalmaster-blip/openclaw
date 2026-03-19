#!/usr/bin/env python3
"""
guardiao-poll-m13-patch.py — Adiciona tipo_material à verificação de higiene (M01).

Executar UMA VEZ após:
  1. Criar o campo tipo_material no ClickUp
  2. Configurar TIPO_MATERIAL_FIELD_ID em guardiao-produtividade.py

Uso: python3 guardiao-poll-m13-patch.py <TIPO_MATERIAL_FIELD_ID>
Exemplo: python3 guardiao-poll-m13-patch.py abc123-def456-...

ATENÇÃO: Só ativar este patch DEPOIS que o campo existir no ClickUp.
Se ativado antes, TODAS as tarefas existentes vão gerar alerta de higiene.
"""
import os, sys

TARGET = os.path.expanduser("~/openclaw/whatsapp-bridge/guardiao-poll.py")
PATCH_MARKER = "# M13: tipo_material adicionado à higiene"

if len(sys.argv) < 2:
    print("Uso: python3 guardiao-poll-m13-patch.py <TIPO_MATERIAL_FIELD_ID>")
    print("Exemplo: python3 guardiao-poll-m13-patch.py abc123-def456")
    sys.exit(1)

TIPO_MATERIAL_FIELD_ID = sys.argv[1].strip()

if not os.path.exists(TARGET):
    print(f"ERRO: {TARGET} não encontrado")
    sys.exit(1)

with open(TARGET) as f:
    content = f.read()

if PATCH_MARKER in content:
    print("Patch M13 higiene já aplicado — nada a fazer")
    sys.exit(0)

# 1. Adicionar constante TIPO_MATERIAL_FIELD_ID após ATD_FIELD
OLD_CONST = 'ATD_FIELD    = "00e6513e-ef48-4262-aa2f-1288f8ebed72"'
NEW_CONST  = (f'ATD_FIELD    = "00e6513e-ef48-4262-aa2f-1288f8ebed72"\n'
              f'TIPO_MATERIAL_FIELD_ID = "{TIPO_MATERIAL_FIELD_ID}"  '
              f'# M13: tipo_material adicionado à higiene')

if OLD_CONST not in content:
    print("ERRO: constante ATD_FIELD não encontrada — arquivo modificado?")
    sys.exit(1)

content = content.replace(OLD_CONST, NEW_CONST, 1)

# 2. Adicionar tipo_material à função check_hygiene
OLD_HYGIENE = '''def check_hygiene(task):'''

# Localizar o corpo atual da função
# Procura pela linha que verifica designer e adiciona verificação de tipo_material
OLD_HYGIENE_BODY = '''    flags = []
    for f in task.get("custom_fields", []):
        fid = f.get("id")
        val = f.get("value")
        if fid == DESIGN_FIELD and (val is None or val == ""):
            flags.append("sem_designer")
        if fid == ATD_FIELD and (val is None or val == ""):
            flags.append("sem_atendimento")
    if not task.get("due_date"):
        flags.append("sem_data")
    return flags'''

NEW_HYGIENE_BODY = '''    flags = []
    has_designer    = False
    has_atd         = False
    has_tipo        = False
    for f in task.get("custom_fields", []):
        fid = f.get("id")
        val = f.get("value")
        if fid == DESIGN_FIELD:
            if val is None or val == "": flags.append("sem_designer")
            else: has_designer = True
        if fid == ATD_FIELD:
            if val is None or val == "": flags.append("sem_atendimento")
            else: has_atd = True
        if TIPO_MATERIAL_FIELD_ID and fid == TIPO_MATERIAL_FIELD_ID:
            if val is None or val == "": flags.append("sem_tipo_material")
            else: has_tipo = True
    if not task.get("due_date"):
        flags.append("sem_data")
    return flags'''

if OLD_HYGIENE_BODY not in content:
    print("AVISO: corpo original de check_hygiene não encontrado.")
    print("O campo tipo_material NÃO foi adicionado à higiene.")
    print("Adicionar manualmente: verificar se val de TIPO_MATERIAL_FIELD_ID é None → flags.append('sem_tipo_material')")
else:
    content = content.replace(OLD_HYGIENE_BODY, NEW_HYGIENE_BODY, 1)
    print("check_hygiene atualizada com tipo_material")

# 3. Atualizar mensagem de higiene para incluir tipo_material
OLD_HYGIENE_MSG = '''    FLAG_MSG = {
        "sem_designer":    "Designer não atribuído",
        "sem_atendimento": "Atendimento não atribuído",
        "sem_data":        "Data de vencimento não definida",
    }'''

NEW_HYGIENE_MSG = '''    FLAG_MSG = {
        "sem_designer":      "Designer não atribuído",
        "sem_atendimento":   "Atendimento não atribuído",
        "sem_data":          "Data de vencimento não definida",
        "sem_tipo_material": "Tipo de material não preenchido",  # M13
    }'''

if OLD_HYGIENE_MSG in content:
    content = content.replace(OLD_HYGIENE_MSG, NEW_HYGIENE_MSG, 1)
    print("FLAG_MSG atualizado com sem_tipo_material")
else:
    print("AVISO: FLAG_MSG não encontrado — verificar manualmente")

with open(TARGET, "w") as f:
    f.write(content)

print(f"\nPatch M13 higiene aplicado com sucesso em {TARGET}")
print(f"TIPO_MATERIAL_FIELD_ID = {TIPO_MATERIAL_FIELD_ID}")
print("\nPróximos passos:")
print("1. Verificar sintaxe: python3 -m py_compile guardiao-poll.py")
print("2. Preencher retroativamente tipo_material nas tarefas abertas")
print("3. Ativar SILENT_MODE = False em guardiao-produtividade.py")
