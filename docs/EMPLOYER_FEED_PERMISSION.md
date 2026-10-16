# Asking an employer for permission to show its offers (draft, NOT sent)

The ATS platforms (Greenhouse, Lever, Ashby, SmartRecruiters, Recruitee, Teamtailor, Workday) expose public job boards, but none states a licence to store and republish a customer's postings
(see `docs/SOURCES_13_0.md` §2). The postings belong to the employer. Where an employer or institution (a hospital group, a university, a retailer, a bank, a city) wants its offers in OrbiJob, this
is the request the **owner** can send from their own address. The assistant does not send anything.

## Template (English; translate to the employer's language)

> Subject: Permission to show your public job offers in OrbiJob
>
> Hello,
>
> OrbiJob (https://github.com/Lucasdiogof/orbijob, by Lucksrei) is a free job-search app for every profession, in Portuguese, English and Spanish. Your careers site publishes its offers
> through <platform> at <public board URL>.
>
> With your written permission, OrbiJob would read that public board a few times a day (one request every two seconds), store the title, the place, the contract type and the description of each
> open offer, and show it with "Jobs via <employer name>" and a link to the offer's own page on your site, where candidates apply. OrbiJob never applies on anyone's behalf, never edits the text,
> does not keep candidates' data on your platform and stops showing an offer when it leaves your board. We will stop completely on your request, and remove everything we stored.
>
> May we do this? A reply to this e-mail is enough.
>
> <name>, <contact>

## What a "yes" unlocks (the owner records it, then the assistant implements)

1. The employer's board slug (for example `boards.greenhouse.io/<slug>`), its platform, and the written answer, kept in `docs/` as the evidence of permission.
2. A declarative entry per employer and a connector on the shared snapshot shell (`worker/src/connectors/snapshot.ts`): one request per board, field mapping, attribution text naming the employer.
3. The usual route: fixture from the real board, tests, preview, import, quality review, then the owner's guarded publication.

## Do not

* integrate a board "because the endpoint answers";
* write to several employers on the owner's behalf;
* accept an employer's reply that only covers viewing, not storing and showing.
