import { describe, expect, it } from 'vitest';
import { protectPersonalData, maskPersonalIds } from '../src/description';
import { maskPersonalPhones } from '../src/phones';

// OrbiJob 14.1: Brazilian personal data in listing texts. A mobile number (DDD + 9 digits starting with 9) and a CPF belong to a person; a company's landline or an
// institutional line is public business information; dates, hours, amounts, CBO codes, CEP and CNPJ are never touched.
const mask = (s: string) => protectPersonalData(s, 'BR');

describe('Brazilian telephone numbers', () => {
  it('masks mobile numbers in every common way of writing them', () => {
    expect(mask('Contato: (62) 99999-9999')).toBe('Contato: [tel.]');
    expect(mask('Chamar no (62)99999-9999 hoje')).toBe('Chamar no [tel.] hoje');
    expect(mask('WhatsApp 62 9 9999-9999 (Maria)')).toBe('WhatsApp [tel.] (Maria)');
    expect(mask('Chamar 62 99999-9999')).toBe('Chamar [tel.]');
    expect(mask('Whats: +55 62 99999-9999')).toBe('Whats: [tel.]');
    expect(mask('Falar com Dr. Carlos pelo (11) 98888-7777')).toBe('Falar com Dr. Carlos pelo [tel.]');
  });
  it('masks a landline when a person is named or nothing says it is the company line; keeps the company line', () => {
    expect(mask('Falar com Maria no (62) 3333-4444')).toBe('Falar com Maria no [tel.]');
    expect(mask('Ligue para a central: (62) 3333-4444 (nosso RH)')).toBe('Ligue para a central: (62) 3333-4444 (nosso RH)');
    expect(mask('Fale conosco pelo (62) 3333-4444')).toBe('Fale conosco pelo (62) 3333-4444');
    expect(mask('Prefeitura de Goiânia (62) 3524-1000')).toBe('Prefeitura de Goiânia (62) 3524-1000');
    expect(mask('Falar com Maria na recepção (62) 3333-4444')).toBe('Falar com Maria na recepção (62) 3333-4444');
  });
  it('never touches dates, hours, amounts, CBO codes, CEP, CNPJ, references or a bare run of digits', () => {
    for (const t of [
      'Salário R$ 3.500,00 + VR 25,00 por dia, CBO 2236-60 e CEP 74000-000',
      'Vaga 2023-07-10, horário 08:00 às 17:00, ref 12345678',
      'CNPJ 12.345.678/0001-90',
      'Das 08 às 17 horas, 44 horas semanais, 13 9999-9999 nao',
      'Código 62999999999 do sistema',
      'Experiência de 06 meses (2 a 3 anos) em 12/10/2026',
    ]) expect(mask(t), t).toBe(t);
  });
  it('is idempotent', () => {
    const once = mask('Contato: (62) 99999-9999 ou Maria (11) 3333-4444');
    expect(mask(once)).toBe(once);
  });
  it('masks a +55 mobile and keeps the rest of the text', () => {
    expect(maskPersonalPhones('Mobile: +5562999999999 para candidatos', 'BR')).toBe('Mobile: [tel.] para candidatos');
  });
});

describe('Brazilian personal tax number (CPF)', () => {
  it('masks a formatted CPF and eleven digits right after the word CPF', () => {
    expect(maskPersonalIds('CPF 123.456.789-09 do responsável')).toBe('CPF [CPF] do responsável');
    expect(maskPersonalIds('CPF: 12345678909')).toBe('CPF: [CPF]');
    expect(maskPersonalIds('cpf n. 12345678909.')).toBe('cpf n. [CPF].');
    expect(maskPersonalIds('Envie o número 123.456.789-09 para o RH')).toBe('Envie o número [CPF] para o RH');
  });
  it('leaves company numbers and other eleven-digit codes alone', () => {
    expect(maskPersonalIds('CNPJ 12.345.678/0001-90')).toBe('CNPJ 12.345.678/0001-90');
    expect(maskPersonalIds('PIS 12345678909')).toBe('PIS 12345678909');
    expect(maskPersonalIds('versão 1.234.567.890-12')).toBe('versão 1.234.567.890-12');
  });
});
