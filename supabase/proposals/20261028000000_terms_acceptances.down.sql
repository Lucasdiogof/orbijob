-- Rollback of the proposal supabase/proposals/20261028000000_terms_acceptances.sql (the acceptance records are deleted with it).
drop function if exists public.record_terms_acceptance(text, text);
drop table if exists public.terms_acceptances;
drop table if exists ops.legal_versions;
