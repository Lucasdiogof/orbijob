# Recuperação de senha por código de 6 dígitos

O app não usa mais link/deep link/PKCE na recuperação: e-mail → `resetPasswordForEmail` → código de 6 dígitos → `verifyOTP(type: recovery)` → nova senha (`updateUser`).

## Configuração do projeto Supabase (`rpmlfxwebnlxnwadyvle`) — feita pelo dono

1. Dashboard → Authentication → Emails → Templates → **Reset Password**: cole o conteúdo de `recovery-email.html` (só `{{ .Token }}`, sem `{{ .ConfirmationURL }}`). Assunto sugerido: `Seu código de recuperação do OrbiJob`.
2. Authentication → Sign In / Providers → Email: **Email OTP Length = 6** (padrão) e **Email OTP Expiration = 3600**.
3. Teste: peça o código no app com um e-mail de teste e confira que o e-mail traz só os 6 dígitos.

Alternativa por API (token pessoal `sbp_…` em `SUPABASE_ACCESS_TOKEN`, nunca no repositório):

```bash
curl -X PATCH "https://api.supabase.com/v1/projects/rpmlfxwebnlxnwadyvle/config/auth" \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" -H "Content-Type: application/json" \
  -d "$(python -c 'import json;print(json.dumps({"mailer_templates_recovery_content":open("docs/auth/recovery-email.html").read(),"mailer_subjects_recovery":"Seu código de recuperação do OrbiJob","mailer_otp_length":6,"mailer_otp_exp":3600}))')"
```

Limite do Supabase: um e-mail de recuperação por minuto por usuário; o app espera 60 s para reenviar.
