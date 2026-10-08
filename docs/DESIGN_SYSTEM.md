# OrbiJob — design system

Material 3 customizado, claro/escuro, responsivo (compacto/médio/expandido), tipografia moderna (a definir pela identidade escolhida), animações discretas, a11y AA.

## Implementado
`ColorScheme.fromSeed` com semente **provisória** (`kProvisionalSeed`, trocar após escolha da identidade), cartões e campos arredondados, tema escuro, tela de busca com estados idle/loading/sem-fonte/erro, largura máxima 720 para tablets/web, testes de contraste de texto e alvo de toque (`meetsGuideline`).

Navegação principal: Início · Explorar · Favoritos · Candidaturas; perfil no cabeçalho. Barra inferior em telas compactas, rail em ≥ 600dp (implementado e testado).

## Identidade
Três propostas refinadas aguardam aprovação: `docs/design/IDENTITY_CONCEPTS.md` e `docs/design/comparison/`. Cada uma traz `tokens.json` (cor claro/escuro, tipografia, espaçamento em múltiplos de 4, forma, movimento, breakpoints) e telas para mobile, tablet e desktop. **Nenhuma foi aplicada ao app.**

**Regras comuns a qualquer proposta (já verificadas nas prévias):** contraste de texto ≥ 4,5:1 e componentes ≥ 3:1 (calculado), alvos de toque ≥ 44–48 px, bottom navigation < 600 dp e navigation rail ≥ 600 dp (painel de detalhe a partir do desktop), estados carregando/vazio/erro/sem fonte integrada, conteúdo de exemplo sempre rotulado como fictício.

## Planejado
Tokens (espaçamento 4/8, raios, elevação), `JobCard`, `FilterSheet`, `MatchBadge` (nota + confiança + justificativas), `StageTimeline`, `SourceAttribution`, `EmptyState`/`ErrorState` reutilizáveis, navegação adaptativa (rail em ≥600dp), RTL (árabe) e fontes CJK. Conceitos de marca: `docs/design/IDENTITY_CONCEPTS.md`.
