// Edge Function: gerenciar-funcionarios
// Publicar SOMENTE no Supabase de testes até validar as permissões.
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'npm:@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const publishableKey = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') || '{}').default;
const secretKey = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') || '{}').default;
if (!supabaseUrl || !publishableKey || !secretKey) throw Error('Variáveis de ambiente Supabase ausentes');

const admin = createClient(supabaseUrl, secretKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const allowedOrigins = new Set([
  'https://gustavosellerpro.github.io',
  ...(Deno.env.get('ALLOWED_ORIGINS') || '').split(',').map(x => x.trim()).filter(Boolean),
]);
function headersFor(origin: string | null) {
  const local = origin && /^http:\/\/(?:localhost|127\.0\.0\.1):\d+$/.test(origin);
  const trusted = !!origin && (allowedOrigins.has(origin) || !!local);
  return {
    'Access-Control-Allow-Origin': trusted ? origin! : '',
    'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
    'Content-Type': 'application/json; charset=utf-8',
  };
}
serve(async (req) => {
  const origin = req.headers.get('origin');
  const headers = headersFor(origin);
  const json = (payload: object, status = 200) => new Response(JSON.stringify(payload), { status, headers });
  if (origin && !headers['Access-Control-Allow-Origin']) return json({ erro: 'Origem não autorizada' }, 403);
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers });
  if (req.method !== 'POST') return json({ erro: 'Método não permitido' }, 405);
  try {
    const authHeader = req.headers.get('authorization') || '';
    const token = authHeader.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!token) return json({ erro: 'Sessão necessária' }, 401);
    const authClient = createClient(supabaseUrl, publishableKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: identity, error: identityError } = await authClient.auth.getUser(token);
    if (identityError || !identity.user) return json({ erro: 'Sessão inválida' }, 401);
    const { data: adminProfile, error: profileError } = await admin.from('usuarios')
      .select('id,cargo,ativo,precisa_trocar_senha')
      .eq('id', identity.user.id).single();
    if (profileError) return json({ erro: 'Não foi possível confirmar permissões' }, 500);
    if (!adminProfile?.ativo || adminProfile.cargo !== 'admin' || adminProfile.precisa_trocar_senha)
      return json({ erro: 'Acesso administrativo negado' }, 403);
    const payload = await req.json().catch(() => ({}));
    if (payload.action === 'listar') {
      const { data, error } = await admin.from('usuarios')
        .select('id,nome,email,cargo,ativo,precisa_trocar_senha')
        .order('nome', { ascending: true }).limit(1000);
      if (error) return json({ erro: 'Não foi possível listar os funcionários' }, 500);
      return json({ usuarios: data || [] });
    }
    if (payload.action === 'resetar') {
      const id = String(payload.user_id || '');
      const senha = String(payload.nova_senha || '');
      if (!/^[0-9a-f-]{36}$/i.test(id) || senha.length < 12 || senha.length > 128)
        return json({ erro: 'Dados inválidos. Senha temporária deve ter entre 12 e 128 caracteres.' }, 400);
      if (id === identity.user.id) return json({ erro: 'Não é permitido redefinir a própria senha por esta tela' }, 403);
      const { data: employee, error: employeeError } = await admin.from('usuarios')
        .select('id,ativo,precisa_trocar_senha').eq('id', id).single();
      if (employeeError || !employee?.ativo) return json({ erro: 'Funcionário inexistente ou inativo' }, 404);
      // Bloquear acesso aos dados internos antes de alterar a senha.
      const { error: flagError } = await admin.from('usuarios')
        .update({ precisa_trocar_senha: true }).eq('id', id);
      if (flagError) return json({ erro: 'Não foi possível bloquear o primeiro acesso' }, 500);
      const { error: passwordError } = await admin.auth.admin.updateUserById(id, { password: senha });
      if (passwordError) {
        // Restaura a marcação anterior se o Auth falhar.
        await admin.from('usuarios')
          .update({ precisa_trocar_senha: employee.precisa_trocar_senha }).eq('id', id);
        return json({ erro: 'Não foi possível redefinir a senha; tente novamente' }, 500);
      }
      return json({ sucesso: true });
    }
    return json({ erro: 'Ação inválida' }, 400);
  } catch (e) {
    console.error('Erro administrativo:', e instanceof Error ? e.name : 'desconhecido');
    return json({ erro: 'Erro interno na função' }, 500);
  }
});
