# Get on Board — permission status (2026-10-14)

**Status: published on the owner's decision (6.0), growth frozen, permission NOT confirmed.**

## Evidence re-read on 2026-10-14
- Public API reference (`/api-doc.html`): "Public API — open to anyone ... no authentication required". No sentence on storage, caching or republication.
- Terms of Service (`/about/tos`, re-read): the prohibitions on "copying or permitting automatic downloading" of platform content, on training models and on republishing are written for **Customers** (paying companies, section 7); the opening says that anyone who registers or uses the Platform is bound by the Terms. GoB may throttle API calls. The incorporated Platform Policies / Job Moderation Policy were not available.
- robots.txt: no restriction (6.0 note). Conclusion: **neither granted nor denied; no explicit restriction on a non-customer reading the public API, but no grant to store and redisplay either.**

## Conservative, reversible measure applied
- The stored-catalogue ceiling of the source was lowered from 1,500 to **600** (= what is stored today), so the source **cannot grow**; it keeps refreshing/closing the 600 it has. (`worker/src/sources.ts`, `catalogue: 600`.)
- Nothing else collected, no new fields, no salary, only title/company/place/description with "Jobs via Get on Board" and a link to the listing.

## Recommendation
1. Send the request below (owner, from marketing@lucksrei.com). Not sent by us.
2. If GoB refuses, or does not answer and the owner prefers zero risk: **unpublish** (reversible, immediate): `update public.job_sources set can_redistribute = false where id = 'getonboard';` — the app stops showing it at once; data stays stored but hidden. To publish again use `scripts/supabase/ops/publish_source.sql`.
3. If GoB agrees, raise `catalogue` back (up to their limit) and record the answer here.

## Request (EN / ES) — draft, to be sent by the owner
> Hello, OrbiJob (https://github.com/Lucasdiogof/orbijob) is a free job-search app by Lucksrei. It reads the public Get on Board API (categories/jobs) twice a day, one request every two seconds, stores title, company, place and description of the listings, shows them with "Jobs via Get on Board" and a link to each listing on getonbrd.com, and never applies on anyone's behalf. May we keep doing so? We will stop immediately on request. Contact: marketing@lucksrei.com

> Hola, OrbiJob (https://github.com/Lucasdiogof/orbijob) es una app gratuita de búsqueda de empleo de Lucksrei. Lee la API pública de Get on Board (categories/jobs) dos veces al día, una solicitud cada dos segundos, guarda título, empresa, lugar y descripción de las ofertas, las muestra con "Jobs via Get on Board" y un enlace a cada oferta en getonbrd.com, y nunca postula en nombre de nadie. ¿Podemos seguir haciéndolo? Dejaremos de hacerlo de inmediato si lo piden. Contacto: marketing@lucksrei.com
