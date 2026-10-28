'use strict';
const PROJECT_URL='https://sshhyqywxwpijsosxdvz.supabase.co';
const PUBLISHABLE_KEY='sb_publishable_PfB_Sc1ZgKRUCPTJXIcPaA_5xkoVXBN';
const sb=window.supabase?.createClient(PROJECT_URL,PUBLISHABLE_KEY,{auth:{autoRefreshToken:true,persistSession:true,detectSessionInUrl:true}});
const $=id=>document.getElementById(id);let profile=null;let currentUser=null;
const screens=['login','recovery','change','welcome'];
function show(id){screens.forEach(x=>$(x).classList.toggle('hidden',x!==id));clearNotice()}
function notice(t){$('notice').style.display='block';$('notice').textContent=t}
function clearNotice(){$('notice').style.display='none';$('notice').textContent=''}
function friendly(e){if(!e)return 'Erro desconhecido';if(/invalid login credentials/i.test(e.message||''))return 'E-mail ou senha incorretos.';if(/email not confirmed/i.test(e.message||''))return 'O e-mail ainda não foi confirmado.';return e.message||String(e)}
function theme(){document.body.classList.toggle('dark');localStorage.setItem('sellerpro_theme',document.body.classList.contains('dark')?'dark':'light')}
if(localStorage.getItem('sellerpro_theme')==='dark')document.body.classList.add('dark');document.querySelectorAll('.theme').forEach(x=>x.onclick=theme);
async function authorized(){if(!sb){show('login');notice('Não foi possível carregar a biblioteca de autenticação. Confira sua conexão à internet.');return}const {data:{user},error:ue}=await sb.auth.getUser();if(ue||!user){show('login');return}const {data:p,error:pe}=await sb.from('usuarios').select('id,nome,email,cargo,ativo,precisa_trocar_senha').eq('id',user.id).maybeSingle();if(pe||!p||!p.ativo||!['admin','usuario'].includes(p.cargo)){await sb.auth.signOut();show('login');notice('Conta sem permissão ativa. Fale com um administrador.');return}profile=p;currentUser=user;if(p.precisa_trocar_senha){show('change');return} $('currentName').textContent=p.nome;$('currentEmail').textContent=p.email;$('currentRole').textContent=p.cargo==='admin'?'Administrador (ADM)':'Usuário';$('adminArea').classList.toggle('hidden',p.cargo!=='admin');show('welcome')}
$('loginForm').onsubmit=async ev=>{ev.preventDefault();if(!sb){notice('Biblioteca de autenticação não carregada.');return}const btn=$('loginButton');btn.disabled=true;clearNotice();try{const {error}=await sb.auth.signInWithPassword({email:$('email').value.trim(),password:$('password').value});if(error)throw error;await authorized()}catch(e){notice(friendly(e))}finally{btn.disabled=false}};
$('forgot').onclick=()=>{show('recovery');$('recoverEmail').value=$('email').value};$('backLogin').onclick=()=>show('login');
$('recoverForm').onsubmit=async ev=>{ev.preventDefault();try{const {error}=await sb.auth.resetPasswordForEmail($('recoverEmail').value.trim(),{redirectTo:location.origin+location.pathname});if(error)throw error;notice('Se houver uma conta correspondente e o serviço de e-mail estiver configurado, enviaremos as instruções.')}catch(e){notice(friendly(e))}};
$('changeForm').onsubmit=async ev=>{ev.preventDefault();const p=$('newpass').value;if(p!==$('newpass2').value){notice('As senhas são diferentes.');return}if(p.length<12){notice('Use pelo menos 12 caracteres.');return}try{const {data:{session},error:se}=await sb.auth.getSession();if(se||!session?.access_token)throw new Error('Sessão expirada. Faça login novamente.');const r=await fetch(PROJECT_URL+'/functions/v1/definir-senha',{method:'POST',headers:{'Content-Type':'application/json','apikey':PUBLISHABLE_KEY,'Authorization':'Bearer '+session.access_token},body:JSON.stringify({novaSenha:p})});const resultado=await r.json().catch(()=>({}));if(!r.ok)throw new Error(resultado.erro||('Erro HTTP '+r.status));$('newpass').value='';$('newpass2').value='';await authorized();notice('Senha pessoal definida com sucesso.');}catch(e){notice(friendly(e))}};

$('createForm').onsubmit=async ev=>{
  ev.preventDefault();
  const btn=$('createEmployeeButton');
  const feedback=$('createFeedback');
  feedback.textContent='';
  if(!profile||profile.cargo!=='admin'||!profile.ativo){feedback.textContent='Permissão administrativa necessária.';return}
  const nome=$('employeeName').value.trim(),email=$('employeeEmail').value.trim().toLowerCase(),cargo=$('employeeRole').value,senha=$('employeePassword').value;
  if(nome.length<2||senha.length<12||senha.length>128){feedback.textContent='Confira o nome e a senha (12 a 128 caracteres).';return}
  btn.disabled=true;
  try{
    const {data:{session},error:sessionErr}=await sb.auth.getSession();
    if(sessionErr||!session?.access_token)throw new Error('Sessão expirada. Entre novamente.');
    const r=await fetch(PROJECT_URL+'/functions/v1/criar-funcionario',{
      method:'POST',headers:{'Content-Type':'application/json','apikey':PUBLISHABLE_KEY,'Authorization':'Bearer '+session.access_token},
      body:JSON.stringify({nome,email,cargo,senha})
    });
    const body=await r.json().catch(()=>({}));
    if(!r.ok)throw new Error(body.erro||('Erro HTTP '+r.status));
    feedback.textContent='Funcionário criado: '+email+' ('+(cargo==='admin'?'ADM':'Usuário')+'). Confirme o cadastro em Authentication → Users. No primeiro acesso, será solicitada uma nova senha pessoal.';
    $('createForm').reset();
  }catch(e){feedback.textContent='Não foi possível criar: '+(e.message||String(e))}
  finally{btn.disabled=false}
};
$('logout').onclick=async()=>{await sb.auth.signOut();profile=null;currentUser=null;show('login')};
if(sb){sb.auth.onAuthStateChange((event)=>{if(event==='PASSWORD_RECOVERY')show('change')});authorized()}else{show('login');notice('Falha ao carregar Supabase JS. Verifique sua conexão.')}
