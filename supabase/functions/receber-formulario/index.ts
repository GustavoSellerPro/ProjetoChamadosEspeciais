// Seller Pro — Google Forms / Google Sheets -> fila entradas_forms (Supabase de TESTES).
// Webhook privado protegido por FORMS_WEBHOOK_SECRET.
// NÃO criar casos, sellers ou tickets automaticamente.
// Deploy: Edge Functions > receber-formulario; verify_jwt = false SOMENTE nesta função.
import { createClient } from 'npm:@supabase/supabase-js@2.119.0';

type Answers = Record<string, unknown>;
type FormEntry = {
  origem_id?: unknown;
  chave_origem?: unknown; // compatibilidade com scripts anteriores
  enviado_em?: unknown;
  respostas?: unknown;
};

const HISTORICO_SHEET_ID = '1bQZRKsvnFfEjp4BRB4ZGX3nf1U8dTQvoZc9itxGb_Bo';
const NOVO_SHEET_ID = '1ae0KuZWEpgdOmf3ycsRf6ADq5zB_RXcdVtRbP_WAMEQ';

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' },
  });

const clean = (x: unknown) => {
  if (Array.isArray(x)) return x.map(clean).filter(Boolean).join('; ');
  if (x === null || x === undefined) return '';
  return String(x).trim();
};
const normalize = (x: string) => x.normalize('NFD').replace(/[\u0300-\u036f]/g, '')
  .toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();

function answer(respostas: Answers, prefixes: string[]): string {
  const entries = Object.entries(respostas).map(([name, val]) => [normalize(name), clean(val)] as const);
  for (const prefix of prefixes) {
    const pref = normalize(prefix);
    const exact = entries.find(([key, val]) => key === pref && val);
    if (exact) return exact[1];
    const match = entries.find(([key, val]) => key.startsWith(pref) && val);
    if (match) return match[1];
  }
  return '';
}

async function equalSecret(provided: string, expected: string): Promise<boolean> {
  if (!provided || !expected) return false;
  const enc = new TextEncoder();
  const [a, b] = await Promise.all([
    crypto.subtle.digest('SHA-256', enc.encode(provided)),
    crypto.subtle.digest('SHA-256', enc.encode(expected)),
  ]);
  const aa = new Uint8Array(a), bb = new Uint8Array(b);
  let difference = 0;
  for (let i = 0; i < aa.length; i++) difference |= aa[i] ^ bb[i];
  return difference === 0;
}

function prepare(data: FormEntry, allowed: Set<string>) {
  const source = clean(data?.origem_id || data?.chave_origem);
  // chave estável: gsheet:ID_DA_PLANILHA:ID_DA_ABA:LINHA
  const match = /^gsheet:([A-Za-z0-9_-]{12,}):([0-9]+):([1-9][0-9]*)$/.exec(source);
  if (!match) throw Error('Chave de origem inválida');
  if (![HISTORICO_SHEET_ID, NOVO_SHEET_ID].includes(match[1]))
    throw Error('Planilha não cadastrada na Central Seller Pro');
  if (allowed.size && !allowed.has(match[1])) throw Error('Planilha não autorizada');
  const origemTipo = match[1] === HISTORICO_SHEET_ID ? 'historico' : 'novo';
  const raw = data?.respostas;
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw Error('Respostas inválidas');
  const fields = raw as Answers;
  if (Object.keys(fields).length > 80) throw Error('Número excessivo de campos');
  const respostas: Record<string, string> = {};
  for (const [key, value] of Object.entries(fields)) {
    if (!key || key.length > 350) throw Error('Nome de campo inválido');
    const val = clean(value);
    if (val.length > 16000) throw Error('Campo muito longo');
    respostas[key] = val;
  }
  const nome = answer(respostas, ['Nome Completo', 'Seu nome inteiro', 'Nome completo']);
  const mcid = answer(respostas, ['MCID', 'Codigo do vendedor']);
  const resumo = answer(respostas, ['Descricao do Caso', 'Resumo do caso', 'Descricao do chamado', 'Assunto']);
  const sentAt = clean(data.enviado_em);
  const sentDate = sentAt && !Number.isNaN(Date.parse(sentAt)) ? new Date(sentAt) : null;
  const safeDate = sentDate && sentDate.getTime() > Date.UTC(2000, 0, 1)
    && sentDate.getTime() < Date.now() + 24 * 60 * 60 * 1000 ? sentDate.toISOString() : null;
  return {
    origem_id: source,
    origem_tipo: origemTipo,
    status: origemTipo === 'historico' ? 'arquivado' : 'pendente',
    resposta_em: safeDate,
    nome: nome.slice(0, 400) || null,
    mcid: mcid.slice(0, 150) || null,
    resumo: resumo.slice(0, 4000) || null,
    respostas,
    // origem_tipo e status são atribuídos pelo servidor, nunca pelo navegador/Apps Script.
  };
}

Deno.serve(async req => {
  if (req.method !== 'POST') return json({ error: 'Método não permitido' }, 405);
  const secret = Deno.env.get('FORMS_WEBHOOK_SECRET') || '';
  const supplied = req.headers.get('x-forms-webhook-secret') || '';
  if (secret.length < 32 || !(await equalSecret(supplied, secret)))
    return json({ error: 'Não autorizado' }, 401);
  const url = Deno.env.get('SUPABASE_URL') || '';
  const keys = Deno.env.get('SUPABASE_SECRET_KEYS') || '{}';
  let serviceKey = '';
  try { serviceKey = JSON.parse(keys)?.default || ''; } catch { /* fall through */ }
  serviceKey ||= Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
  if (!url || !serviceKey) return json({ error: 'Servidor não configurado' }, 503);
  const length = Number(req.headers.get('content-length') || 0);
  if (length > 256000) return json({ error: 'Requisição muito grande' }, 413);
  let body = '';
  try { body = await req.text(); } catch { return json({ error: 'Falha na leitura' }, 400); }
  if (body.length > 256000) return json({ error: 'Requisição muito grande' }, 413);
  let input: unknown;
  try { input = JSON.parse(body); } catch { return json({ error: 'JSON inválido' }, 400); }
  if (!input || typeof input !== 'object' || Array.isArray(input))
    return json({ error: 'Payload inválido' }, 400);
  const record = input as { entradas?: unknown } & FormEntry;
  const batch = Array.isArray(record.entradas) ? record.entradas : [record];
  if (!batch.length || batch.length > 25) return json({ error: 'Use de 1 a 25 registros por envio' }, 400);
  const allowed = new Set((Deno.env.get('FORMS_ALLOWED_SPREADSHEETS') || '')
    .split(',').map(s => s.trim()).filter(Boolean));
  let prepared;
  try { prepared = batch.map(x => prepare(x as FormEntry, allowed)); }
  catch (err) { return json({ error: (err as Error).message }, 422); }
  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error } = await admin.from('entradas_forms')
    .upsert(prepared, { onConflict: 'origem_id', ignoreDuplicates: true });
  if (error) {
    console.error('Falha ao registrar Forms', error.code);
    return json({ error: 'Falha ao registrar formulário. Verifique a migração 009.' }, 500);
  }
  return json({ ok: true, aceitos: prepared.length, status: 'enviado_à_fila', sem_abertura_automatica: true });
});
