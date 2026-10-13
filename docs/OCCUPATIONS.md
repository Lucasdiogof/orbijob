# Profissões multilíngues

**Objetivo:** aceitar qualquer profissão digitada, buscá-la também sob os nomes que ela tem nos outros idiomas do catálogo, sem confundir ocupações vizinhas e sem afirmar equivalência regulatória.

## Estado (OrbiJob 5.0)
Implementado e testado: [ORBIJOB_5_0.md](ORBIJOB_5_0.md) descreve o funcionamento, a medição antes/depois e os limites.

## Camadas
1. **ESCO** (tabela compilada no app): `app/lib/features/search/domain/occupation_labels.g.dart`, gerada por `scripts/build-occupations.mjs` a partir de `scripts/esco-fetch.mjs` (2.942 ocupações baixadas em 2026-10-13; 2.853 mantidas; 31.824 nomes em pt, en, es, de, sv, nl, fr, no máximo 3 por idioma e ocupação, preferidos primeiro). Cada nome de uma ocupação é ligado ao ISCO-08 de 4 dígitos. Filtros: nomes alternativos só se compartilham a palavra-chave do nome preferido; no máximo 4 palavras, sem pontuação; nome compartilhado por mais de 6 ocupações é descartado; nome que é o preferido de exatamente uma ocupação pertence só a ela; rótulos editoriais entre « » são descartados.
2. **Grupos manuais** (`search_synonyms.dart`): radicais para profissões que a ESCO divide em muitas especializações (fisioterap, pflege, eletricista…). Palavras que a pessoa acrescenta ("flutter", "civil") continuam obrigatórias; dois grupos ("fisioterapia" + "pélvica") são exigidos juntos.
3. **Resolvedor** (`search_alternatives.dart`): cada alternativa é uma **lista de partes que precisam estar todas no título**. Falsos amigos ("chef", "controller", "revisor") e palavras curtas nunca valem sozinhos como outra profissão.
4. **Sugestões** (`search_suggestions.dart`): resultado vazio oferece uma busca mais ampla ou grafia parecida; só sugestão, nunca resultado.
5. **Futuro:** embeddings/IA gratuita apenas como sugestão com confirmação do usuário.

## Licença e atribuição
ESCO — European Skills, Competences, Qualifications and Occupations, © União Europeia, https://esco.ec.europa.eu, licença CC BY 4.0. Os nomes foram filtrados e agrupados pelo OrbiJob; a Comissão Europeia não endossa o OrbiJob. A atribuição está no cabeçalho do arquivo gerado, aqui e na página de licenças do app.

## Casos de regressão testados
`app/test/search/search_alternatives_test.dart`: fisioterapia pélvica / pelvic health physiotherapist / Beckenbodenphysiotherapie · desenvolvedor flutter / Flutter-Entwickler · enfermeiro / nurse / Pflegefachkraft · engenheiro civil / civil engineer / Bauingenieur (nunca "qualquer engenheiro") · eletricista / electrician / Elektriker · soldador / welder / Schweißer · "chef" nunca equivale a outra profissão. São exemplos, não uma lista exclusiva.

## Limites
Os nomes não foram revisados por falantes nativos. Um qualificador que precisa de tradução ("truck" em "truck driver") não é traduzido, a menos que a ESCO liste a ocupação qualificada. A correspondência é por trecho no título, sensível a acento (igual ao SQL). Nada aqui diz que um registro profissional, visto ou certificação vale em outro país.
