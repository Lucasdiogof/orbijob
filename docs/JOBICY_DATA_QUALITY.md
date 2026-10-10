# Jobicy: qualidade dos dados (Etapa D)

Origem: auditoria da primeira ingestão real (299 vagas, privadas, 2026-10-10). Esta rodada corrige o **código** (conector e app) e
prepara a correção dos **registros já gravados**. Nada foi escrito no Supabase hospedado, nenhuma ingestão rodou, `can_redistribute`
continua `false`.

## 1. O que mudou no código

| Problema auditado | Conector (Worker) | App (Flutter) |
|---|---|---|
| Salário só com um limite (5) | já era gravado assim; agora coberto por teste | "A partir de X" / "Até X" (PT, EN, ES), moeda e período preservados; faixa e valor exato como antes |
| Salário suspeito (Jobicy 152711: USD 168–220 por ano) | `worker/src/salary.ts`: limites por período e razão máx/mín; o par suspeito **não é gravado**; nunca se "corrige" (168 não vira 168.000) | `core/format/salary_check.dart` (mesmos limites): registros antigos suspeitos ficam **ocultos** |
| `Anywhere` vs localização ausente (5) | `Anywhere` explícito é gravado como o marcador `['Anywhere']`; ausente/ilegível continua `[]` | `[]` = "elegibilidade não informada" (nunca "global"); `['Anywhere']` = "qualquer lugar, segundo a fonte" |
| Regiões (EMEA, LATAM, APAC, Europe) | continuam regiões, nunca expandidas | idem; mostram aviso "confira a elegibilidade no anúncio original" |
| Resíduos de Markdown, `\r`, caracteres invisíveis, entidades dupla-codificadas | `worker/src/text.ts` e `description.ts` | `core/format/description_text.dart` (mesmas regras, para registros já gravados) |
| E-mails nas descrições (77–80) | política abaixo | mesma política, aplicada na exibição |
| Países como código (`US`) | — | `core/format/country_names.dart`: nome em PT/EN/ES para ~70 códigos ISO; código desconhecido aparece como está |

### Localização: sem migration
`jobs.geo_restrictions` é `text[] not null default '{}'`. A distinção ausente × `Anywhere` cabe no mesmo campo com o marcador
`Anywhere`, sem alterar o schema. **Migration só seria necessária** se quisermos uma coluna própria (`geo_scope`: `anywhere | countries |
regions | unknown`) para filtrar no banco; hoje nenhum filtro depende disso, então **não foi criada nem aplicada**.

### Política de e-mail nas descrições
* **Fica**: endereço de função/profissional que a própria vaga indica para candidatura ou acessibilidade (`careers@`, `recruiting@`,
  `accommodations@`, `hr.support@`, `privacy@` …). É informação útil e institucional.
* **Mascarado (`[e-mail]`)**: tudo que não se pode mostrar ser de função: nome pessoal (`jane.doe@`), qualquer endereço com dígitos,
  qualquer endereço em provedor gratuito (gmail, outlook …). Padrão seguro: na dúvida, mascara.
* O link do anúncio original é sempre preservado. Dos 80 e-mails dos registros atuais, 5 ocorrências (3 endereços de caixa genérica
  não reconhecida: `nextbit@`, `taops@`, `seeyourself@`) seriam mascaradas.
* Limite conhecido: o reconhecimento é por palavras; uma caixa de função com nome incomum é mascarada (erro para o lado seguro).

## 2. Registros já gravados (299)

O app já mostra os 299 registros corrigidos (salário suspeito oculto, descrição limpa, países nomeados, aviso de elegibilidade).
Para corrigir também o banco existe um **plano somente leitura**:

```
node worker/scripts/jobicy-quality-plan.mjs --out <pasta fora do repositório>
```

Ele lê as linhas pela CLI do Supabase já logada (um `SELECT`), aplica as mesmas regras e gera `quality-fix.sql` + relatório.
**Não executa nada.** Resultado de 2026-10-10 sobre as 299 linhas reais:

* 63 descrições mudariam (perda máxima de 5,3 % do texto, média 1,0 %: quebras de linha, linhas de separação, marcadores);
* 5 e-mails mascarados;
* 5 localizações vazias **sem resolução** (150274, 152785, 152792, 154770, 154773): do banco não dá para saber se são `Anywhere` ou
  ausentes; só se altera com evidência da fonte (`--source-geo arquivo.json` com o `jobGeo` publicado);
* 1 salário que precisa da fonte (152711, 168–220 USD/ano): **não é alterado**.

O SQL gerado é protegido: uma transação; aborta se a tabela não tiver exatamente as 299 linhas do plano; cada `UPDATE` é por
`(source_id, external_id)` **e** `md5` do texto visto no plano (linha editada depois não é tocada); cada `UPDATE` precisa alterar
exatamente o número planejado de linhas ou tudo é desfeito (uma segunda execução também aborta); só `description` (e `geo_restrictions`
com evidência) são escritas, nunca salário nem `can_redistribute`. Testado contra o schema real (PGlite).

**Aplicar exige autorização explícita** (escrita no banco hospedado). Antes: novo plano (para o `md5`/contagem atuais) e backup.
Reversão: o backup guarda as descrições antigas; o plano grava os `md5` anteriores.

## 3. Riscos restantes
* Limites de plausibilidade de salário são heurísticos (amplos de propósito); uma moeda de valor muito baixo pode exigir ajuste.
* Países fora da tabela (~70) aparecem como o código; regiões não listadas aparecem como a fonte escreveu.
* A distinção `Anywhere` × ausente só existe para vagas importadas depois desta mudança, ou corrigidas com evidência da fonte.
* As descrições continuam texto simples (sem negrito/listas formatadas).
