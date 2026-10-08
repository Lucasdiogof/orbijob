# OrbiJob — design system

Material 3 customizado, claro/escuro, responsivo (compacto/médio/expandido), tipografia moderna (a definir pela identidade escolhida), animações discretas, a11y AA.

## Implementado
`ColorScheme.fromSeed` com semente **provisória** (`kProvisionalSeed`, trocar após escolha da identidade), cartões e campos arredondados, tema escuro, tela de busca com estados idle/loading/sem-fonte/erro, largura máxima 720 para tablets/web, testes de contraste de texto e alvo de toque (`meetsGuideline`).

Navegação principal: Início · Explorar · Favoritos · Candidaturas; perfil no cabeçalho. Barra inferior em telas compactas, rail em ≥ 600dp (implementado e testado).

## Identidade
Três propostas aguardam aprovação: `docs/design/IDENTITY_CONCEPTS.md`. Nenhuma foi aplicada.

## Planejado
Tokens (espaçamento 4/8, raios, elevação), `JobCard`, `FilterSheet`, `MatchBadge` (nota + confiança + justificativas), `StageTimeline`, `SourceAttribution`, `EmptyState`/`ErrorState` reutilizáveis, navegação adaptativa (rail em ≥600dp), RTL (árabe) e fontes CJK. Conceitos de marca: `docs/design/IDENTITY_CONCEPTS.md`.
