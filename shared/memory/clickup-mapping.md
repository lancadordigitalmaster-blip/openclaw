# ClickUp — Mapeamento Completo Wolf Agency
**Atualizado:** 2026-03-11 | **Autor:** Claude Code (mapeamento real via API)

---

## ESTRUTURA

```
Space: Marketing (90131750758)
  └── Folder: Produção de Conteúdo 📄 (90133240928)
        ├── Lista: Produção DSGN   (901306028132)  ← principal, 148 tasks
        └── Lista: Núcleo Criativo (901306028133)  ← onboardings/mensal, 38 tasks
```

---

## LISTA 01 — Produção DSGN (`901306028132`)

**Uso:** produção diária de materiais (posts, carrosseis, arte, etc.)
**Tasks ativas:** ~148

### Fluxo de Status

```
backlog congelado
apontamentos
para fazer        ← entrada padrão de nova demanda
produzindo        ← designer em execução
conferência interna ← revisão interna antes de enviar
em alteração      ← cliente pediu mudança (loop detectável)
formatos          ← adaptação de formatos (loop detectável)
enviado ao cliente ← aguardando aprovação
ajuste            ← ajuste pós-aprovação
aguardando cliente ← cliente tem pendência
pausado / bloqueado ← impedimento externo
material reprovado ← reprovação definitiva
finalizada        ← concluída ✅
```

**Loop de revisão:** qualquer retorno de `conferência interna` ou `enviado ao cliente` → `em alteração`

### Custom Fields — Produção DSGN

| Campo | Field ID | Tipo | Obrigatório |
|-------|----------|------|-------------|
| **Design** | `b9b3676c-f119-48cf-851d-8ebd83e5011f` | drop_down | ✅ SIM |
| **Atendimento** | `00e6513e-ef48-4262-aa2f-1288f8ebed72` | drop_down | ✅ SIM |
| **Clientes** | `ce9180ff-92ad-4e7f-bf6d-557b86ceb4cd` | drop_down | Recomendado |
| **Origem da demanda** | `d0737af0-61b0-4a5e-96bc-6cb90f95e048` | drop_down | Recomendado |
| **Tipo de cliente** | `d2849a3b-b352-4d09-b09d-d5088b46e257` | drop_down | Recomendado |
| **Código** | `4bc56acd-c465-4e6d-af88-a4f2a26568d7` | number | — |
| **Data de postagem** | `27648bbf-96eb-4796-9084-78b1ceb41d2f` | date | — |
| **Data limite de aprovação** | `32993afa-df2a-4e7a-a5fb-cb273996aab7` | date | — |
| **Prazo de alteração** | `04df0c16-fc2c-4a35-abce-4b8aed0516a1` | date | — |
| **Data de envio ao cliente** | `e132d9c4-b0b3-4713-97fb-a876f197e95c` | date | — |
| **Hora entrada conferência** | `c3eb122e-2f62-4ffa-8d89-d6ac5192d060` | date | — |
| **Publicação** | `ca45eafe-12f7-4e85-adb0-4185c9c6a20d` | drop_down | — |
| **Link** | `09ade2e1-05a8-4e12-aca6-9aa361f12a38` | url | — |
| **Drive** | `8d75267d-a625-432b-b7f6-9f079c59460f` | url | — |
| Qual tipologia do produto? | `48e1b932-8dcd-4a2c-a32e-700b00c689a0` | text | — |
| Referências | `5a6860a4-eadc-40f2-a5f2-437ce7d435df` | attachment | — |
| Imagens do projeto | `14ff14f8-ca41-46d4-ac26-54ce777ec517` | attachment | — |
| Imagem referência | `57c8b46f-f2f2-4b11-9658-311320b30460` | attachment | — |
| Logo | `90a9d9e1-9cd1-4cc7-9ff8-a4abc4ffffac` | attachment | — |
| 💵 Valor | `63360f3c-bd9c-407e-9d79-b08ad00d8e66` | currency | — |
| Mensais a partir de | `485baed5-690b-4848-9c7a-e1b6cdf72b92` | currency | — |
| Entrada parcelada | `4394d9ef-db86-4995-80cc-45916a7da61f` | number | — |
| Sinal a partir de | `eb0d4eec-2518-44f9-afe5-61d6f6dc6416` | currency | — |

### Origem da demanda (d0737af0...)
```
0 = Do zero
1 = Alteração
```

### Tipo de cliente (d2849a3b...)
```
0 = Mensal
1 = Campanha
2 = Entrega única
3 = Sociedade
4 = Interno
```

### Publicação (ca45eafe...)
```
0 = Agendar
```

---

## LISTA 02 — Núcleo Criativo (`901306028133`)

**Uso:** onboarding de novos clientes, identidade visual, planejamento mensal
**Tasks ativas:** ~38

### Fluxo de Status

```
onboarding
reunião e questionário
análise & bpm
níveis de conteúdo
planejamento
captação
produzindo
postagem
análise mensal
pausado
finalizada
```

### Custom Fields — Núcleo Criativo

| Campo | Field ID | Tipo |
|-------|----------|------|
| **Atendimento** | `00e6513e-ef48-4262-aa2f-1288f8ebed72` | drop_down |
| **Clientes** | `ce9180ff-92ad-4e7f-bf6d-557b86ceb4cd` | drop_down |
| Status (interno) | `41a6d2d1-624f-40c8-b9e4-7471b3ab4abb` | drop_down |
| ⚡ Status ativo | `4c27c8ac-c9b2-4a7a-b1be-d21bfe91e430` | drop_down |

*Nota: campo Design não existe no Núcleo Criativo — foco em processo, não produção diária.*

---

## MAPEAMENTO DESIGNERS (campo Design)

| orderindex | Nome |
|-----------|------|
| 0 | Bruno |
| 1 | Eliedson |
| 2 | Rodrigo |
| 3 | Leoneli |
| 4 | Felipe |
| 5 | Levi |
| 6 | Pedro |
| 7 | Rodrigo Web |
| 8 | Lucas |
| 9 | Matheus |
| 10 | Vinicius |
| 11 | Abilio |

---

## MAPEAMENTO ATENDIMENTO (campo Atendimento)

| orderindex | Nome | Grupo [ATD] individual | WhatsApp LID |
|-----------|------|----------------------|--------------|
| 0 | Mirelli | `120363404935864783@g.us` | `13714451353700@lid` |
| 1 | Mariana | — | `92093242445946@lid` |
| 2 | Natiely | — | `161693254590603@lid` |
| 5 | Sindy | `120363407446292610@g.us` | `245509558141125@lid` |
| 6 | Thalita | `120363423988334642@g.us` | `87794147926245@lid` |
| 7 | Marina | — | ⚠️ não encontrado |
| 8 | Cibele | — | `129549719363720@lid` |
| 9 | Yasmin | — | ⚠️ não encontrado |
| 10 | Matheus | — | ⚠️ não encontrado |
| 12 | Gabriela | — | `110080716451960@lid` |

**Fallback quando sem grupo individual:** `120363163709134922@g.us` ([ATD] Gestão de Atendimento)

---

## MAPEAMENTO GRUPOS WHATSAPP DESIGNERS

| Designer | Grupo [DSG] | Group JID |
|----------|------------|-----------|
| Leoneli | [DSG] Leoneli | `120363043442238725@g.us` |
| Eliedson | [DSG] Eliedson | `120363274461250260@g.us` |
| Rodrigo | [DSG] Rodrigo | `120363298195368310@g.us` |
| Pedro | [DSG] Pedro | `120363307941400545@g.us` |
| Abilio | [DSG] Abilio | `120363424995440614@g.us` |

---

## METAS DIÁRIAS DE PRODUÇÃO

| Designer | Meta/dia |
|----------|---------|
| Pedro | 17 |
| Leoneli | 12 |
| Abilio | 14 |
| Eliedson | 8 |
| Levi | 2 |

---

## ESTRUTURA DE TAREFA (campos reais via API)

```json
{
  "id": "86ag2w999",
  "name": "Cliente - Tipo de material - Código",
  "status": { "status": "para fazer" },
  "due_date": "1773212400000",
  "assignees": [{ "username": "Nome Designer" }],
  "custom_fields": [
    { "id": "b9b3676c-...", "name": "Design", "value": 1 },
    { "id": "00e6513e-...", "name": "Atendimento", "value": 5 },
    { "id": "ce9180ff-...", "name": "Clientes", "value": 17 }
  ]
}
```

**Atenção:** `assignees` é quem está atribuído (pode diferir do campo Design). Para identificar o designer responsável, use o campo **Design** (drop_down orderindex).

---

## MAPEAMENTO COMPLETO CLIENTES (campo Clientes — ce9180ff...)

| idx | Cliente | idx | Cliente | idx | Cliente |
|-----|---------|-----|---------|-----|---------|
| 0 | Bfabriani | 1 | Ludmilia | 2 | Descanso do guerreiro |
| 3 | Mixbar | 4 | Jales Jhoson | 5 | Leonardo Alves |
| 6 | Shel Guima | 7 | Dowton | 8 | Fernando Nazario |
| 9 | Rodrigo | 10 | Fabiano Lorite | 11 | Odonni |
| 12 | Danylo Maia | 13 | Rose Life | 14 | Kaique Andrade |
| 15 | Breno Pokarbet | 16 | Sinho Ferrary | 17 | A culpa de quem |
| 18 | O maestro | 19 | Karen Danielles | 20 | Gravo Music |
| 21 | Fernando Hayne | 22 | Danilo Holzer | 23 | Raul Dourado |
| 24 | Ricardo Modonesi | 25 | Ivanete | 26 | Douglas Aquino |
| 27 | Nail Collor | 28 | 01 milhão | 29 | Milshows |
| 30 | Henrique Trust | 31 | Breno Melo | 32 | Fabiano Gois |
| 33 | Luis Sniper | 34 | Yuri Nogueira | 35 | Felipe Costa |
| 36 | Pedro Porto | 37 | Danilo Luziano | 38 | Clash Node |
| 39 | Felipe Linhatti | 40 | Thiago Aquino | 41 | Gustavo Machado |
| 42 | Igor Camargo | 43 | Marcio [Luiz] | 44 | Victor Lima |
| 45 | Mikael | 46 | Igor Xoption | 47 | Julio |
| 48 | Philip Eua | 49 | Kauã Araujo | 50 | Favoretti |
| 51 | Dodo Huanna | 52 | Kriss | 53 | Jinna Corrego |
| 54 | Celio | 55 | Alisson Tudibão | 56 | Samuel |
| 57 | Franklin Jorran | 58 | Tondimas | 59 | My cash |
| 60 | Marlo Vieira | 61 | Thiago Netto | 62 | Fernanda I Salão |
| 63 | Piticas | 64 | Moura | 65 | Dan |
| 66 | Alisson Martins | 67 | Maestro Mycash | 68 | Cleidson |
| 69 | Pedro Ferreira | 70 | Rômulo | 71 | Febracis |
| 72 | Plx | 73 | David Bussines | 74 | William Corretor |
| 75 | Cesar Rod | 76 | Vinicius Porto | 77 | Kleist |
| 78 | Matheus Audi | 79 | Marcos Serra | 80 | Thiago Adv |
| 81 | Jhon Macle | 82 | Infinity [Maestro] | 83 | Marco da Rosa |
| 84 | Everton I Iphone | 85 | Bruno Leonardo | 86 | Marcelinho |
| 87 | Ismael | 88 | Foco | 89 | Cloakup |
| 90 | Rômulo [PlayBroker] | 91 | Jhonatas | 92 | Desata |
| 93 | Digital Tech [Maestro] | 94 | Veloc Broker [Felipe] | 95 | Matheus Viana |
| 96 | Shel Guima [Ozônica] | 97 | Fael [Wavy] | 98 | Jr Representações |
| 99 | Daniel M | 100 | Contatos Online [Vagner Santos] | 101 | Mayk Montalvão |
| 102 | Breno Bana | 103 | Gabriel Lourenço | 104 | Guilherme |
| 105 | Pedro Raphael | 106 | Farmácia Bahia | 107 | Roncada |
| 108 | Jefferson Ricardo | 109 | Josué Zilio | 110 | Solutions |
| 111 | Breno Gabriel | 112 | Yasmin Apple | 113 | Rafael Souza |
| 114 | Bianca Carneiro | 115 | Kris Eletrônico | 116 | Ricardo Toro |
| 117 | CashBroker | 118 | Enzzinho | 119 | Marley Produções |
| 120 | Rasta Chinela | 121 | Wolf Pack | 122 | MyLight |
| 123 | Partiu Dirigir | 124 | Companhia do Kaprixxo | 125 | Tupã Saúde |
| 126 | EngeDigital | 127 | Unkave | 128 | Rio Chance |
| 129 | Aurea Capital | 130 | Slim Gumie | 131 | Fênix Digital |
| 132 | Edu e Maraial | 133 | PoolPays | 134 | Marcos Castro |
| 135 | Tradenex | 136 | Pyratas Dev | 137 | Italo e Jean |
| 138 | André Lopes | 139 | Alcateia | 140 | Ipropremium |
| 141 | Thais Terra | 142 | Ionx | 143 | Axion Trade |
| 144 | Haus | 145 | João Leahy | 146 | João Grobman |
| 147 | Almeida Carneiro | 148 | André Qinah | 149 | Pedro Bahia |
| 150 | Erasmo | 151 | Brand Venture | 152 | AsWeb |
| 153 | Luxuria | 154 | Jessica Censato | 155 | Kuarto de eMPREGADA |
| 156 | Estrela Car | 157 | Investcon | 158 | GR Veículos |
| 159 | Gislaine | 160 | Roht | 161 | Raffo Digital |
| 162 | Live Criação | 163 | Lume | 164 | MP8 |
| 165 | William Forlan | 166 | VSQ Digital | 167 | Amália |
| 168 | Thiago Calvacante | 169 | Wagner Rocha | 170 | Orion Broker |
| 171 | DarkScript | 172 | Dm Saúde | 173 | Oral Reabilitar |
| 174 | Slither Pays | 175 | PoolGames | 176 | Haus Imob |
| 177 | Milene | 178 | Las Click Wins | 179 | PoolDiction |
| 180 | Albano | 181 | Torre | 182 | Royal Face |
| 183 | Exitus | 184 | Anhanguera | 185 | Aurea Exclusive |
| 186 | Beach Bar | 187 | Diogo Trader | 188 | TrackFlow |
| 189 | Wolftech | 190 | Pixel Bet | 191 | Banco de Dados |
| 192 | Banco de dados | 193 | Marcas COD SAAS | 194 | Isabela Vieira |
| 195 | Geraldo Pompa | 196 | Kolibri Agência Digital | 197 | Jarley |
| 198 | Pixel Set | 199 | Consulta Aqui | 200 | Tiago |
| 201 | Thais Luz | 202 | Engenharia Cancelier | 203 | Agro China Bra |
| 204 | Ticomia | 205 | Jan Passos | 206 | Agência B Ponto |
| 207 | Keylon | 208 | Wolf Brands | 209 | Althara |
| 210 | Helena Girotto | 211 | JN Veículos | 212 | Junior Nasciemento |
| 213 | Familia Veiculos | 214 | L87 Veiculos | 215 | Dj Neto Nogueira |
| 216 | Campos Plan | 217 | Stark Tecnologia | 218 | Design Smart |
| 219 | ID Digital | 220 | Raíssa | 221 | Im. Criações |
| 222 | Penalty Pays | 223 | B&D | 224 | Jamersson |
| 225 | Italo Martins | 226 | Instituto Milagres | 227 | Esquenta Laje |
| 228 | D3SIGNER E CIA | 229 | Jhessyca | 230 | Biotermic Secrets |

---

## REGRAS OPERACIONAIS

1. **Tarefa bem formada (Produção DSGN):** tem Design + Atendimento + due_date preenchidos
2. **Status OK (meta batida):** `conferência interna`, `enviado ao cliente`, `finalizada`, `ajuste`
3. **Status intermediário (risco de stale):** `produzindo`, `em alteração`, `formatos`
4. **Loop:** retorno para `em alteração` após `conferência interna` ou `enviado ao cliente`
5. **Código da tarefa:** visible no nome (ex: `-86ag2w999`) — usar para localizar no ClickUp
6. **Assignee ≠ Designer field:** usar campo Design para identificar o designer responsável
7. **Núcleo Criativo:** sem campo Design — monitora apenas Atendimento e due_date
