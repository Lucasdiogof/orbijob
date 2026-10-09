# OrbiJob — validação das primeiras fontes reais

Status em **2026-10-09**. Regra: uma fonte só vira `READY` com (1) resposta real validada contra o esquema, (2) termos/licença lidos e aceitos para armazenar e exibir, (3) gratuidade confirmada. Nada abaixo foi promovido.

## Resultado do teste real desta fase
Comando reproduzível: `node scripts/probe-sources.mjs --out docs/evidence/source-probe-<data>.json` (evidência: [`evidence/source-probe-2026-10-09.json`](evidence/source-probe-2026-10-09.json)).

| Fonte | Autenticação | Escopo | Resultado aqui | Status |
|---|---|---|---|---|
| Himalayas | nenhuma reportada | remoto, global | `EGRESS_BLOCKED` (host fora da allowlist do ambiente) | RESEARCH |
| Jobicy | nenhuma reportada | remoto, global | `EGRESS_BLOCKED` | RESEARCH |
| Greenhouse | nenhuma (board token público) | por empresa | `EGRESS_BLOCKED` | CONDITIONAL |
| Lever | nenhuma (site público) | por empresa | `EGRESS_BLOCKED` (conector e normalização já testados com fixture sintética) | CONDITIONAL |
| Ashby | nenhuma (board público) | por empresa | `EGRESS_BLOCKED` | CONDITIONAL |
| USAJOBS | chave grátis + e-mail | EUA federal | `SKIPPED_NO_KEY` | CONDITIONAL |
| France Travail | OAuth2 (conta grátis) | França | `SKIPPED_NO_KEY` | CONDITIONAL |
| Adzuna | app_id + app_key | 19 países, todas as profissões | `SKIPPED_NO_KEY` | CONDITIONAL |

`EGRESS_BLOCKED` significa que **este ambiente** respondeu "Host not in allowlist"; não diz nada sobre a fonte. Nenhum resultado foi inventado e nenhum conteúdo de vaga foi armazenado.

## Como validar (no seu computador ou em ambiente com rede liberada)
1. Fontes sem chave: `node scripts/probe-sources.mjs` → deve mostrar `SCHEMA_OK`. Use `GREENHOUSE_BOARD`, `LEVER_SITE`, `ASHBY_BOARD` para testar uma empresa real.
2. Com chaves: `USAJOBS_KEY=… USAJOBS_EMAIL=… ADZUNA_APP_ID=… ADZUNA_APP_KEY=… FT_CLIENT_ID=… FT_CLIENT_SECRET=… node scripts/probe-sources.mjs`.
3. Rodar também `node scripts/acceptance.mjs` (8 buscas de aceite, qualquer profissão/país).
4. Ler os termos (links em `data/sources.catalog.json`) e registrar a decisão em `docs/GLOBAL_SOURCES.md`; só então mudar o status.

## Recomendação da primeira fonte
**Adzuna** — única candidata que atende à promessa do produto (qualquer profissão, vários países, inclui ofícios e saúde) com chave gratuita. Condições a conferir: limites padrão (25/min, 250/dia), rótulo "Jobs by Adzuna" com link em cada anúncio, política de cache/armazenamento (não encontrada: se proibir persistir, usar só consulta sob demanda, sem gravar em `jobs`). **Segunda: USAJOBS** (oficial, simples, só EUA federal). ATS por empresa (Greenhouse/Lever/Ashby) e remotos (Himalayas/Jobicy) atendem pouco ofícios/saúde; ficam como complemento.
