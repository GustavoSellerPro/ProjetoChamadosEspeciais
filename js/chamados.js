/* Seller Pro | Chamados v0.4: CRUD sem exclusao, persistencia Supabase */
'use strict';
let allCases=[], allSellers=[], editingCase=null, originalTicket=null;
const c=id=>document.getElementById(id);
const trim=id=>c(id).value.trim();
function caseMessage(message,isError=false){const el=c('caseFeedback');el.textContent=message;el.classList.toggle('error',isError)}
function dateBR(v){return v?new Date(v).toLocaleDateString('pt-BR'):'—'}
function ticketLink(t){if(!t)return '—';const a=document.createElement('a');a.textContent=t.ticket_id; if(t.url_ticket&&/^https:\/\//i.test(t.url_ticket)){a.href=t.url_ticket;a.target='_blank';a.rel='noopener noreferrer';}return a}
async function getAuthed(){const {data:{user},error}=await sb.auth.getUser();if(error||!user)throw Error('Sessão expirada. Entre novamente.');const {data:p,error:e}=await sb.from('usuarios').select('ativo,precisa_trocar_senha,cargo').eq('id',user.id).single();if(e||!p?.ativo||p.precisa_trocar_senha)throw Error('Acesso não autorizado.');return user}
async function loadCases(){
 try{await getAuthed();caseMessage('Carregando chamados e sellers...');
 const [cases,sellers]=await Promise.all([
 sb.from('chamados').select('id,titulo,status,seller_id,descricao_original,descricao_formatada,observacoes_internas,importante_reuniao,criado_em,finalizado_em,sellers(id,nome,nome_loja),tickets_zendesk(id,ticket_id,url_ticket)').order('atualizado_em',{ascending:false,nullsFirst:false}).limit(1000),
 sb.from('sellers').select('id,nome,nome_loja,email,telefone,mcid').order('nome').limit(1000)
 ]);
 if(cases.error)throw cases.error;if(sellers.error)throw sellers.error;
 allCases=cases.data||[];allSellers=sellers.data||[];
 const selected=c('caseSeller').value;c('caseSeller').replaceChildren(new Option('Selecionar seller...',''));
 allSellers.forEach(s=>c('caseSeller').add(new Option(`${s.nome}${s.nome_loja?' — '+s.nome_loja:''}`,s.id)));
 c('caseSeller').value=allSellers.some(s=>s.id===selected)?selected:'';
 renderCases();caseMessage(`${allCases.length} chamados disponíveis. A lista está limitada aos 1.000 registros mais recentes por enquanto.`);
 }catch(e){caseMessage('Erro ao carregar: '+e.message,true)}
}
function renderCases(){const q=trim('caseSearch').toLowerCase(),status=c('caseStatusFilter').value;const rows=allCases.filter(x=>{
 const t=(x.tickets_zendesk||[]).map(t=>t.ticket_id).join(' ');return (!status||x.status===status)&&(!q||`${x.titulo} ${x.sellers?.nome||''} ${x.sellers?.nome_loja||''} ${t}`.toLowerCase().includes(q));});
 const body=c('casesBody');body.replaceChildren();if(!rows.length){const tr=body.insertRow();const td=tr.insertCell();td.colSpan=6;td.textContent='Nenhum chamado encontrado.';return}
 rows.forEach(item=>{const tr=body.insertRow();const t=(item.tickets_zendesk||[])[0];const vals=[item.titulo,item.sellers?.nome||'—',null,item.status,dateBR(item.criado_em),null];vals.forEach((v,i)=>{const td=tr.insertCell();if(i===2)td.append(ticketLink(t));else if(i===5){const b=document.createElement('button');b.type='button';b.textContent='Editar';b.className='case-secondary';b.addEventListener('click',()=>editCase(item.id));td.append(b)}else td.textContent=v||'—'})});
}
function clearCase(){editingCase=null;originalTicket=null;c('caseForm').reset();c('caseSeller').disabled=false;c('caseTicket').disabled=false;c('caseTicketUrl').disabled=false;c('caseEditorTitle').textContent='Novo chamado';c('caseStatus').value='Aguardando Amazon';}
function showEditor(){c('caseEditor').classList.remove('hidden');c('caseEditor').scrollIntoView({behavior:'smooth',block:'start'})}
function editCase(id){const x=allCases.find(y=>y.id===id);if(!x)return;clearCase();editingCase=id;
 c('caseEditorTitle').textContent='Editar chamado';c('caseTitle').value=x.titulo||'';c('caseStatus').value=x.status;c('caseSeller').value=x.seller_id||'';
 c('caseOriginal').value=x.descricao_original||'';c('caseFormatted').value=x.descricao_formatada||'';c('caseNotes').value=x.observacoes_internas||'';c('caseMeeting').checked=!!x.importante_reuniao;
 originalTicket=(x.tickets_zendesk||[])[0]||null;c('caseTicket').value=originalTicket?.ticket_id||'';c('caseTicketUrl').value=originalTicket?.url_ticket||'';
 // Editar o primeiro ticket somente nesta versao; os demais sao preservados.
 c('sellerName').value='';c('sellerStore').value='';c('sellerEmail').value='';c('sellerPhone').value='';c('sellerMCID').value='';showEditor();
}
async function saveCase(e){e.preventDefault();const button=c('saveCase');button.disabled=true;
 try{await getAuthed();const title=trim('caseTitle');if(!title)throw Error('Informe o título.');let sellerId=c('caseSeller').value||null;
 const newName=trim('sellerName');if(newName&&sellerId)throw Error('Selecione um seller existente OU preencha um novo, não ambos.');
 if(!sellerId&&!newName)throw Error('Selecione um seller ou cadastre um novo.');
 if(editingCase&&newName)throw Error('Para editar um chamado, selecione um seller já cadastrado. O cadastro de novos sellers está disponível para novos chamados.');
 const ticket=trim('caseTicket'),url=trim('caseTicketUrl');
 if(editingCase&&originalTicket&&!ticket)throw Error('Para preservar o histórico, não é possível remover o ticket Zendesk nesta versão.');if(url&&!/^https:\/\//i.test(url))throw Error('Use um link HTTPS no ticket.');
 if(ticket){const {data:existing,error:dupErr}=await sb.from('tickets_zendesk').select('id,chamado_id').eq('ticket_id',ticket).maybeSingle();if(dupErr)throw dupErr;if(existing&&existing.chamado_id!==editingCase)throw Error('Esse ID Zendesk já está vinculado a outro chamado.');}
 // Criar seller somente quando necessario. Manter registro em caso de falha posterior para evitar perda de dados.
 if(newName){const {data:seller,error:se}=await sb.from('sellers').insert({nome:newName,nome_loja:trim('sellerStore')||null,email:trim('sellerEmail')||null,telefone:trim('sellerPhone')||null,mcid:trim('sellerMCID')||null}).select('id').single();if(se)throw se;sellerId=seller.id;}
 const nowFinal=c('caseStatus').value==='Finalizado';const existing=editingCase?allCases.find(x=>x.id===editingCase):null;
 const payload={seller_id:sellerId,titulo:title,status:c('caseStatus').value,descricao_original:trim('caseOriginal')||null,descricao_formatada:trim('caseFormatted')||null,observacoes_internas:trim('caseNotes')||null,importante_reuniao:c('caseMeeting').checked,atualizado_em:new Date().toISOString(),finalizado_em:nowFinal?(existing?.finalizado_em||new Date().toISOString()):null};
 let caseId=editingCase;
 if(caseId){const {error}=await sb.from('chamados').update(payload).eq('id',caseId);if(error)throw error;}
 else{const {data,error}=await sb.from('chamados').insert(payload).select('id').single();if(error)throw error;caseId=data.id;}
 if(ticket){let r;if(originalTicket){r=await sb.from('tickets_zendesk').update({ticket_id:ticket,url_ticket:url||null,atualizado_em:new Date().toISOString()}).eq('id',originalTicket.id)}else{r=await sb.from('tickets_zendesk').insert({chamado_id:caseId,ticket_id:ticket,url_ticket:url||null})}if(r.error)throw Error('Chamado salvo, mas não foi possível salvar o ticket: '+r.error.message)}
 else if(originalTicket){throw Error('Chamado salvo, porém a remoção do ID Zendesk não está disponível nesta versão. Restaure o ID e salve novamente.');}
 clearCase();c('caseEditor').classList.add('hidden');await loadCases();if(window.loadDashboard)window.loadDashboard();caseMessage('Chamado salvo com sucesso no Supabase.');
 }catch(err){caseMessage(err.message||String(err),true)}finally{button.disabled=false}
}
c('newCaseButton').addEventListener('click',()=>{clearCase();showEditor()});c('cancelCase').addEventListener('click',()=>c('caseEditor').classList.add('hidden'));c('resetCase').addEventListener('click',clearCase);
c('caseForm').addEventListener('submit',saveCase);c('caseSearch').addEventListener('input',renderCases);c('caseStatusFilter').addEventListener('change',renderCases);c('caseRefresh').addEventListener('click',loadCases);
window.loadCases=loadCases;
