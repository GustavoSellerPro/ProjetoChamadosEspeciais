import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'npm:@supabase/supabase-js@2';

const url = Deno.env.get('SUPABASE_URL')!;
const publicKey = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS')!)['default'];
const secretKey = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS')!)['default'];
const admin = createClient(url, secretKey, { auth: { autoRefreshToken: false, persistSession: false } });
const headers = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*', // restringir ao domínio real na produção
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info'
};
function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), { status, headers });
}
serve(async req => {
  if (req.method === 'OPTIONS') return new Response(null, {headers});
  if (req.method !== 'POST') return json({erro: 'Método não permitido'}, 405);
  try {
    const token = req.headers.get('Authorization')?.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!token) return json({erro: 'Faça login primeiro'}, 401);
    const authClient = createClient(url, publicKey, { auth: {persistSession:false, autoRefreshToken:false} });
    const {data:{user}, error:authError} = await authClient.auth.getUser(token);
    if (authError || !user) return json({erro:'Sessão inválida'},401);
    const {data:perfil,error:perfilErro} = await admin.from('usuarios')
      .select('ativo,precisa_trocar_senha').eq('id',user.id).single();
    if (perfilErro || !perfil?.ativo) return json({erro:'Acesso não autorizado'},403);
    if (!perfil.precisa_trocar_senha) return json({erro:'A primeira senha já foi definida'},409);
    const entrada = await req.json().catch(()=>null);
    const novaSenha = entrada?.novaSenha;
    if (typeof novaSenha !== 'string' || novaSenha.length < 12 || novaSenha.length > 128)
      return json({erro:'A senha deve ter entre 12 e 128 caracteres'},400);
    const {error:senhaErro} = await admin.auth.admin.updateUserById(user.id, {password:novaSenha});
    if (senhaErro) return json({erro:'Não foi possível alterar a senha'},500);
    const {error:flagErro} = await admin.from('usuarios')
      .update({precisa_trocar_senha:false}).eq('id',user.id);
    if (flagErro) {
      console.error('Senha alterada mas flag não atualizada',flagErro.code);
      return json({erro:'Senha alterada, mas liberação pendente. Solicite apoio ao administrador.'},500);
    }
    return json({sucesso:true});
  } catch (error) {
    console.error('Erro em definir-senha',error instanceof Error ? error.name : 'desconhecido');
    return json({erro:'Erro interno ao alterar senha'},500);
  }
});
