# USAJOBS API: what the owner has to do (nothing was requested by the assistant)

USAJOBS (US federal jobs, every profession: nurses, physicians, engineers, trades, administration) is the one large source whose terms **explicitly allow what OrbiJob needs**
(`https://developer.usajobs.gov/guides/terms-of-service`, read 2026-10-16): Public Data "may be copied, stored, reformatted, adapted, analyzed, published, redistributed" for lawful commercial or
noncommercial purposes, with no advance approval; attribution is encouraged (identify USAJOBS, link to the current official announcement, say that the product is not operated or endorsed by OPM);
rate limits apply; presenting modified data as official is forbidden. The only missing piece is a **free API key**, which the terms say must be requested with "current and accurate registration
and contact information", so it has to be requested by the owner.

## Steps (owner)

1. Open `https://developer.usajobs.gov/` → "Request API Key". Fill in the owner's e-mail, an organization name (Lucksrei / OrbiJob) and the description: "free job-search app; reads the public search
   API a few times a day, stores title, agency, location, salary range and summary, shows them with a link to the official announcement on usajobs.gov, never applies for anyone".
2. The key arrives by e-mail. Do not paste it in a chat or in Git.
3. Store it as a **Worker secret / GitHub environment secret** the same way `ORBIJOB_SYNC_WORKER_KEY` is stored (the assistant can wire `USAJOBS_API_KEY` and the e-mail used as `User-Agent`).
4. Tell the assistant: it then builds the connector on the snapshot shell (paged search, `ResultsPerPage` 500, fields `PositionURI`, `PositionTitle`, `OrganizationName`,
   `PositionLocation`, `PositionRemuneration`, `PublicationStartDate`, `ApplicationCloseDate`; closed announcements refused by `ApplicationCloseDate`), tests it on a real response,
   previews, imports and prepares the guarded publication file.

Questions about credentials: `access@usajobs.gov`.
