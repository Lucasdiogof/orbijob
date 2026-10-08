import { describe, expect, it } from 'vitest';
import seed from '../../data/occupations.seed.json';
import { expandTerms, resolveOccupation, type Occupation } from '../src/occupations';

const occs = seed.occupations as unknown as Occupation[];
const top = (q: string) => resolveOccupation(q, occs)[0]?.occupation.id;
const ids = (q: string) => resolveOccupation(q, occs).map((m) => m.occupation.id);

describe('occupation resolver', () => {
  it.each([
    ['pedreiro', 'bricklayer'], ['albañil', 'bricklayer'], ['Maurer', 'bricklayer'],
    ['Fisioterapeuta pélvica', 'physio-pelvic'], ['Beckenboden Physiotherapeutin', 'physio-pelvic'],
    ['pintor residencial', 'house-painter'], ['house painter', 'house-painter'],
    ['eletricista', 'electrician'], ['电工', 'electrician'], ['電気工事士', 'electrician'],
    ['enfermeiro', 'nurse'], ['간호사', 'nurse'], ['Flutter Developer', 'software-dev'],
    ['teacher', 'teacher'], ['motorista', 'driver'], ['سائق', 'driver'],
  ])('%s -> %s', (q, id) => expect(top(q)).toBe(id));

  it('keeps electrician and electrical engineer apart', () => {
    expect(top('engenheiro eletricista')).toBe('electrical-engineer');
    expect(ids('engenheiro eletricista')).not.toContain('electrician');
    expect(ids('electrical engineer')).not.toContain('electrician');
  });
  it('keeps residential painter and visual artist apart', () => {
    expect(ids('artista plástico')).toEqual(['visual-artist']);
    expect(ids('pintor residencial')).not.toContain('visual-artist');
  });
  it('keeps bricklayer and civil engineer apart', () => {
    expect(ids('engenheiro civil')).toEqual(['civil-engineer']);
  });
  it('keeps pelvic physio and gynecologist apart', () => {
    expect(ids('médico ginecologista')).toEqual(['gynecologist']);
    expect(ids('fisioterapeuta pélvica')).not.toContain('gynecologist');
  });
  it('returns nothing for unknown professions (caller falls back to keyword search)', () => {
    expect(resolveOccupation('astronauta lunar', occs)).toEqual([]);
  });
  it('expands to multilingual synonyms', () => {
    const t = expandTerms(occs.find((o) => o.id === 'bricklayer')!);
    expect(t).toEqual(expect.arrayContaining(['pedreiro', 'bricklayer', 'albañil', 'maçon']));
  });
  it('seed data is sane: unique ids, 4-digit ISCO, no invented ESCO URIs', () => {
    expect(new Set(occs.map((o) => o.id)).size).toBe(occs.length);
    for (const o of occs) { expect(o.isco08).toMatch(/^\d{4}$/); expect(o.escoUri).toBeNull(); }
  });
});
