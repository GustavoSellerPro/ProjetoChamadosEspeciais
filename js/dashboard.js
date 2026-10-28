/* Dashboard read-only. Dados carregados exclusivamente do Supabase após autorização. */
'use strict';
let dashboardRows=[];
const $d=id=>document.getElementById(id);
const months=new Intl.DateTimeFormat('pt-BR',{month:'long',year:'numeric'});
const dateFmt=new Intl.DateTimeFormat('pt-BR',{day:'2-digit',month:'2-digit',year:'numeric'});
function safeDate(v){const d=new Date(v);return Number.isFinite(d.valueOf())?d:null}
function monthKey(v){const d=safeDate(v);return d?`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}`:''}
function days(v,end){const start=safeDate(v);if(!start)return '—';const finish=safeDate(end)||new Date();return Math.max(0,Math.floor((finish-start)/86400000))+' dias'}
function normalizeStatus(s){return s==='Resolvido'||s==='Concluido'?'Finalizado':s}
function renderDashboard(){
  const month=$d('monthFilter').value,status=$d('statusFilter').value,search=$d('searchFilter').value.trim().toLocaleLowerCase('pt-BR');
  const data=dashboardRows.filter(x=>(!month||monthKey(x.criado_em)===month)&&(!status||normalizeStatus(x.status)===status)&&(!search||`${x.titulo||''} ${x.id||''}`.toLocaleLowerCase('pt-BR').includes(search)));
  const count=s=>data.filter(x=>normalizeStatus(x.status)===s).length;
  $d('statTotal').textContent=data.length;$d('statAmazon').textContent=count('Aguardando Amazon');$d('statSeller').textContent=count('Pendente Seller');$d('statOpen').textContent=count('Aguardando Amazon')+count('Pendente Seller');$d('statFinal').textContent=count('Finalizado');
  const tbody=$d('ticketsBody');tbody.replaceChildren();
  if(!data.length){const tr=tbody.insertRow();const td=tr.insertCell();td.colSpan=5;td.textContent='Nenhum chamado encontrado para os filtros selecionados.';return}
  data.slice(0,200).forEach(x=>{const tr=tbody.insertRow();const cells=[x.titulo||'Sem título',normalizeStatus(x.status)||'—',safeDate(x.criado_em)?dateFmt.format(safeDate(x.criado_em)):'—',days(x.criado_em,x.finalizado_em),x.importante_reuniao?'Sim':'Não'];cells.forEach((value,i)=>{const td=tr.insertCell();td.textContent=value;if(i===1)td.className='status-cell'})});
  if(data.length>200){const tr=tbody.insertRow();const td=tr.insertCell();td.colSpan=5;td.textContent='Mostrando os 200 primeiros resultados. Use os filtros para refinar.'}
}
async function loadDashboard(){
  const msg=$d('dashboardMessage');if(!msg||!sb)return;
  msg.classList.remove('error');msg.textContent='Atualizando chamados...';
  // Conferir usuário e status a cada atualização. Não usar cache local de dados sensíveis.
  const {data:{user},error:authErr}=await sb.auth.getUser();if(authErr||!user){msg.textContent='Sessão expirada.';return}
  const {data:permission,error:permErr}=await sb.from('usuarios').select('ativo,precisa_trocar_senha').eq('id',user.id).single();
  if(permErr||!permission?.ativo||permission.precisa_trocar_senha){dashboardRows=[];renderDashboard();msg.classList.add('error');msg.textContent='Acesso indisponível. Verifique suas permissões.';return}
  let all=[],offset=0;const size=500;
  while(true){const {data,error}=await sb.from('chamados').select('id,titulo,status,criado_em,finalizado_em,importante_reuniao').order('criado_em',{ascending:false}).range(offset,offset+size-1);if(error){dashboardRows=[];renderDashboard();msg.classList.add('error');msg.textContent='Não foi possível carregar os chamados: '+error.message;return}all.push(...data);if(data.length<size)break;offset+=size;if(offset>20000){msg.textContent='Volume alto: somente os 20.000 primeiros chamados foram carregados.';break}}
  dashboardRows=all;const chosen=$d('monthFilter').value;const values=[...new Set(all.map(x=>monthKey(x.criado_em)).filter(Boolean))].sort().reverse();$d('monthFilter').replaceChildren(new Option('Todos os meses',''));values.forEach(k=>{const [y,m]=k.split('-').map(Number);$d('monthFilter').add(new Option(months.format(new Date(y,m-1,1)),k))});$d('monthFilter').value=values.includes(chosen)?chosen:'';
  renderDashboard();msg.textContent=`${all.length} chamados carregados do Supabase. Atualizado em ${new Date().toLocaleTimeString('pt-BR')}.`;
}
['monthFilter','statusFilter','searchFilter'].forEach(id=>$d(id).addEventListener(id==='searchFilter'?'input':'change',renderDashboard));
$d('refreshDashboard').addEventListener('click',loadDashboard);
window.loadDashboard=loadDashboard;
