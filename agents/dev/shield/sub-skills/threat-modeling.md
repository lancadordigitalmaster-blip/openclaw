# threat-modeling.md — SHIELD Sub-Skill: Threat Modeling
# Ativa quando: "threat model", "modelagem de ameaças", "risco"

---

## Framework STRIDE

| Letra | Categoria | O que ameaça | Controle |
|-------|-----------|-------------|---------|
| S | Spoofing (falsidade) | Autenticidade | Autenticação forte |
| T | Tampering (adulteração) | Integridade | Assinaturas, checksums |
| R | Repudiation (repúdio) | Não-repúdio | Logs auditáveis imutáveis |
| I | Information Disclosure (vazamento) | Confidencialidade | Criptografia, acesso mínimo |
| D | Denial of Service | Disponibilidade | Rate limiting, redundância |
| E | Elevation of Privilege | Autorização | RBAC, princípio menor privilégio |

---

## Identificação de Ativos Wolf

### Ativos Críticos por Sistema

```markdown
## Ativos — Sistema Wolf Agency

### Dados
- Credenciais de contas de anúncios de clientes (Meta, Google Ads)
- Tokens de API de plataformas (Meta, GA4, Google Ads)
- Dados de performance e resultado de clientes
- Dados pessoais de leads (nome, email, telefone)
- Dados contratuais e financeiros de clientes Wolf
- Credenciais de banco de dados

### Sistemas
- APIs internas de dados (IRIS pipeline)
- Dashboard de clientes
- Sistema de autenticação
- Pipeline de ETL
- ClickUp (dados operacionais)

### Acessos
- Contas de admin do sistema
- Service accounts de integração
- Acessos de colaboradores
- Acessos de clientes (view-only nos dashboards)
```

---

## Aplicação STRIDE por Componente

### Exemplo: API de Dados IRIS

```markdown
## Threat Model — IRIS API

### Componente: Endpoint /api/metrics/{clientId}

**SPOOFING:**
- Ameaça: Atacante forja identidade de outro usuário/cliente
- Probabilidade: Média (se auth fraca)
- Impacto: Alto (acesso a dados de outros clientes)
- Controle: JWT com curta expiração + verificação de ownership

**TAMPERING:**
- Ameaça: Manipulação de dados em trânsito ou no banco
- Probabilidade: Baixa (com HTTPS)
- Impacto: Alto (dados de clientes corrompidos)
- Controle: HTTPS obrigatório, checksums em dados críticos

**REPUDIATION:**
- Ameaça: Usuário nega ter acessado ou modificado dados
- Probabilidade: Baixa
- Impacto: Médio
- Controle: Audit log imutável de todos os acessos

**INFORMATION DISCLOSURE:**
- Ameaça: Vazamento de dados de clientes
- Probabilidade: Média
- Impacto: Crítico (dados de performance, investimentos)
- Controle: RBAC estrito, dados criptografados em repouso, IDOR prevention

**DENIAL OF SERVICE:**
- Ameaça: API sobrecarregada, pipeline travado
- Probabilidade: Baixa
- Impacto: Médio (relatórios atrasados)
- Controle: Rate limiting, timeouts, circuit breaker

**ELEVATION OF PRIVILEGE:**
- Ameaça: Usuário comum acessa dados de admin/outros clientes
- Probabilidade: Média (IDOR é comum)
- Impacto: Alto
- Controle: Verificação de ownership em cada request, RBAC
```

---

## Priorização por Impacto × Probabilidade

```python
from dataclasses import dataclass
from enum import IntEnum

class Score(IntEnum):
    BAIXO = 1
    MEDIO = 2
    ALTO = 3
    CRITICO = 4

@dataclass
class Threat:
    id: str
    name: str
    stride_category: str
    component: str
    impact: Score
    probability: Score
    existing_controls: list[str]

    @property
    def risk_score(self) -> int:
        return self.impact * self.probability

    @property
    def risk_level(self) -> str:
        score = self.risk_score
        if score >= 12: return "CRITICO"
        if score >= 6: return "ALTO"
        if score >= 3: return "MEDIO"
        return "BAIXO"


def prioritize_threats(threats: list[Threat]) -> list[Threat]:
    """Ordena ameaças por score de risco (impacto × probabilidade)."""
    return sorted(threats, key=lambda t: t.risk_score, reverse=True)


# Exemplo de uso
threats = [
    Threat(
        id="T001",
        name="IDOR em endpoint de relatórios",
        stride_category="I",
        component="/api/metrics/{clientId}",
        impact=Score.ALTO,
        probability=Score.MEDIO,
        existing_controls=["JWT auth"],
    ),
    Threat(
        id="T002",
        name="SQL Injection em filtros de busca",
        stride_category="T",
        component="/api/search",
        impact=Score.CRITICO,
        probability=Score.MEDIO,
        existing_controls=[],
    ),
]

prioritized = prioritize_threats(threats)
for t in prioritized:
    print(f"[{t.risk_level}] {t.id}: {t.name} — score {t.risk_score}")
```

---

## Controles por Categoria STRIDE

| Categoria | Controles Wolf |
|-----------|---------------|
| Spoofing | JWT RS256/HS256, MFA para admins, OAuth para terceiros |
| Tampering | HTTPS everywhere, input validation, prepared statements |
| Repudiation | Audit log imutável, timestamps confiáveis, logging estruturado |
| Information Disclosure | Criptografia em repouso (AES-256), RBAC, IDOR prevention, LGPD |
| Denial of Service | Rate limiting, timeouts, circuit breakers, auto-scaling |
| Elevation of Privilege | Menor privilégio, RBAC granular, verificação de ownership |

---

## Template de Threat Model para Sistemas Wolf

```markdown
# Threat Model — [Nome do Sistema]
**Data:** [data]
**Versão:** 1.0
**Autores:** [nomes]
**Revisão:** [data próxima revisão]

## 1. Escopo
[O que está sendo modelado. Diagrama de componentes se possível.]

## 2. Ativos Críticos
| Ativo | Classificação | Localização |
|-------|--------------|------------|
| [ativo] | Crítico/Alto/Médio | [onde está] |

## 3. Atores (quem interage com o sistema)
| Ator | Tipo | Nível de confiança |
|------|------|-------------------|
| Usuário autenticado | Interno | Alto |
| Usuário anônimo | Externo | Zero |
| Service account | Sistema | Médio-Alto |

## 4. Fluxos de Dados
[Descrever principais fluxos: entrada de dados, processamento, saída]

## 5. Ameaças Identificadas (STRIDE)
| ID | Categoria | Componente | Descrição | Impacto | Probabilidade | Score |
|----|-----------|-----------|-----------|---------|--------------|-------|
| T001 | I | /api | IDOR em recursos | Alto | Médio | 6 |

## 6. Priorização
[Ameaças ordenadas por score de risco]

## 7. Controles Planejados
| Ameaça | Controle | Responsável | Prazo |
|--------|---------|-------------|-------|
| T001 | Ownership check em cada endpoint | Dev | Sprint atual |

## 8. Riscos Aceitos
[Ameaças que não serão tratadas agora e por quê]

## 9. Próxima Revisão
[Data — threat model deve ser revisado a cada mudança arquitetural significativa]
```

---

## Quando Fazer Threat Model

| Gatilho | Tipo |
|---------|------|
| Sistema novo sendo projetado | Threat model completo |
| Nova feature com dados sensíveis | Threat model parcial do componente |
| Mudança de infraestrutura | Revisão do threat model existente |
| Incidente de segurança | Revisão forçada |
| Trimestral | Revisão de manutenção |

**Regra Wolf:** Threat model não é auditoria. É feito ANTES de construir, não depois. Problema detectado no design custa 10x menos do que após deploy.
