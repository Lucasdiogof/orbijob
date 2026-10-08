# Profissões multilíngues

**Objetivo:** aceitar qualquer profissão digitada, mapear para classificação padrão (ISCO-08 / ESCO) e expandir sinônimos por idioma, sem confundir ocupações vizinhas.

## Camadas
1. **Resolvedor determinístico** (`worker/src/occupations.ts`): normaliza (minúsculas, sem acentos), casa por rótulo exato/parcial, aplica *exclusões* (ex.: "engenheiro eletricista" exclui "eletricista"). Texto desconhecido → `[]` e busca por palavra-chave literal (nunca chute).
2. **Seed** `data/occupations.seed.json`: 12 ocupações em pt/en/es/fr/de/it/zh/ja/ko/ar (cobertura parcial por idioma). ISCO-08 de 4 dígitos; `escoUri` **nulo de propósito** (resolver via API ESCO; não inventar URIs).
3. **ESCO/ISCO completo:** importar rótulos multilíngues (ESCO oferece API web e API local EUPL-1.2; **licença dos dados a confirmar**). Sinônimos específicos (ex.: "pedreiro" vs "oficial de alvenaria") entram como camada própria sobre o ESCO.
4. **Futuro:** embeddings/IA gratuita apenas como sugestão com confirmação do usuário.

## Casos de desambiguação testados (23 testes)
pintor residencial ≠ artista plástico · pedreiro ≠ engenheiro civil · fisioterapeuta pélvica ≠ ginecologista · eletricista ≠ engenheiro eletricista · termos em zh/ja/ko/ar.

## Limites
Rótulos não-pt/en/es precisam de revisão por falante nativo. Idiomas e ocupações fora do seed caem no fallback literal. ISCO 4 dígitos é grosseiro (ex.: 2264 cobre todos os fisioterapeutas; a especialidade pélvica vem dos rótulos).
