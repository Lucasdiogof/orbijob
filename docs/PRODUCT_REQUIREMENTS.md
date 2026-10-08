# OrbiJob — requisitos de produto

**Visão:** plataforma de busca e acompanhamento de vagas para **qualquer profissão**, com cobertura crescente e **transparente** (sem prometer cobertura mundial).

## Missão
Ajudar qualquer pessoa, em qualquer profissão, a encontrar, avaliar e acompanhar oportunidades de emprego pelo mundo, com transparência sobre fontes e cobertura.

## Telas planejadas
Início (resumo, melhores compatibilidades) · Explorar (busca mundial + filtros internacionais) · Favoritos · Candidaturas (histórico/etapas) · Perfil no cabeçalho (currículo, experiências, formação, licenças, preferências) · Detalhe da vaga (compatibilidade 0–100 + confiança + justificativas) · Fluxo de preenchimento assistido (revisão antes de qualquer envio). Hoje: shell de navegação e páginas vazias honestas; Explorar tem busca com estado "sem fonte integrada".

## Princípios
Honestidade de dados (nunca mock como real) · privacidade por padrão · sem candidatura automática · sem burlar CAPTCHA/bloqueios · gratuito no MVP.

## Requisitos funcionais (status real: **tudo planejado, exceto o indicado**)
| ID | Requisito | Status |
|---|---|---|
| F1 | Busca por qualquer profissão com sinônimos multilíngues | resolvedor seed implementado/testado; busca não integrada |
| F2 | Filtros avançados (país, cidade, modalidade, contrato, salário, idioma, data) | planejado |
| F3 | Cartão de vaga com atribuição da fonte e link original | planejado |
| F4 | Estados loading/vazio/erro/sucesso/sem-fonte | sem-fonte, loading, erro, vazio implementados na tela de busca |
| F5 | Perfis profissionais múltiplos (dados, idiomas, experiências, formação, certificações, licenças, competências, currículo PDF, links, preferências, autorização de trabalho informada) | esquema SQL proposto (validado em PGlite) |
| F6 | Ranking 0–100 determinístico + confiança + justificativas | especificado abaixo; não implementado |
| F7 | Favoritos, notas, pesquisas salvas, histórico de visualização | esquema proposto |
| F8 | Candidaturas: canal, data, etapas, entrevistas, propostas, rejeições, retirada, lembretes (status manual) | esquema proposto |
| F9 | Autofill assistido (mobile) / respostas copiáveis (web) | desenho em ARCHITECTURE |
| F10 | UI pt/en/es; vagas e formulários em outros idiomas | l10n pt/en/es iniciado |

## Ranking de compatibilidade (spec)
Pontuação = soma ponderada de critérios **avaliáveis**; critérios sem dado ficam fora do cálculo e reduzem a **confiança** (0–100), exibida separadamente.
Critérios (pesos iniciais sugeridos): competências 25 · experiência/senioridade 20 · especialidade/ocupação (ISCO) 15 · licenças exigidas 10 · formação 5 · idiomas 8 · localização/modalidade 8 · salário 5 · preferências 4.
Regras de segurança: nunca presumir elegibilidade migratória ou profissional; licença exigida e não declarada = **requisito pendente**, não desqualificação; autorização de trabalho só usada se informada; cada ponto referencia a evidência (trecho da vaga × campo do perfil).

## Requisitos não funcionais
A11y (contraste AA, alvos ≥48dp, semântica), desempenho de lista paginada, offline-tolerante para favoritos, i18n, testes automatizados, CI, sem segredos no repositório.

## Fora do escopo do MVP
Candidatura automática, integração de e-mail (arquitetura prevista, exige autorização do usuário), scraping de portais proibidos, IA paga.
