# OrbiJob — material para o portfólio Lucksrei (rascunho, NÃO publicado)

Nada foi alterado em lucksrei.com. Logo/ícone definitivos, screenshots e links de lojas **ainda não existem** (propostas de identidade aguardam aprovação: `docs/design/IDENTITY_CONCEPTS.md`).

| Campo | PT | EN | ES |
|---|---|---|---|
| Nome | OrbiJob | OrbiJob | OrbiJob |
| Desenvolvedora | Lucksrei | Lucksrei | Lucksrei |
| Descrição curta | Busca, avaliação e acompanhamento de vagas para qualquer profissão, ao redor do mundo. | Search, evaluate and track job opportunities for any profession, around the world. | Busca, evaluación y seguimiento de empleos para cualquier profesión, en todo el mundo. |
| Descrição técnica | App Flutter (Android, iOS, Web/PWA) com Clean Architecture e BLoC; Cloudflare Workers para sincronização e API; Supabase (PostgreSQL, Auth, RLS) para dados; conectores extensíveis com deduplicação; ranking de compatibilidade determinístico e explicável. | Flutter app (Android, iOS, Web/PWA) with Clean Architecture and BLoC; Cloudflare Workers for sync and API; Supabase (PostgreSQL, Auth, RLS) for data; extensible connectors with deduplication; deterministic, explainable compatibility ranking. | App Flutter (Android, iOS, Web/PWA) con Clean Architecture y BLoC; Cloudflare Workers para sincronización y API; Supabase (PostgreSQL, Auth, RLS) para datos; conectores extensibles con deduplicación; ranking de compatibilidad determinista y explicable. |

**Funcionalidades (todas planejadas, exceto indicado):** busca mundial multilíngue · filtros internacionais · compatibilidade 0–100 com confiança · favoritos · currículo e experiências · acompanhamento de candidaturas · preenchimento assistido com revisão do usuário. *Implementado hoje:* navegação, busca com estados honestos, resolvedor de profissões, núcleo dos conectores.

**Stack:** Flutter/Dart, BLoC/Cubit, GetIt, TypeScript, Cloudflare Workers, PostgreSQL, Supabase, GitHub Actions.
**Diferenciais pretendidos:** transparência de fontes e cobertura; qualquer profissão; privacidade (RLS); sem candidatura automática.
**Links:** repositório https://github.com/Lucasdiogof/orbijob · Android/iOS/Web: ainda não disponíveis.
**Pendente:** logo, ícone, screenshots, links de lojas, revisão final dos textos.
