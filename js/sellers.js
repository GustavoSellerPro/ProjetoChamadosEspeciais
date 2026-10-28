/* Seller Pro v0.5: cadastro unico seller, sem exclusao; RLS verificado no Supabase. */
'use strict';
let sellerCache=[],sellerCaseCache=[];
const sel=id=>document.getElementById(id);
function sellerFeedback(message,error=false){const node=sel('sellersMessage');node.textContent=message;node.classList.toggle('error',error)}
async function loadSellers(){
  try{
    await getAuthed();sellerFeedback('Carregando sellers...');
    const [s,c]=await Promise.all([sb.from('sellers').select('id,nome,nome_loja,email,telefone,mcid,cnpj,criado_em').order('nome').limit(2000),sb.from('chamados').select('id,seller_id,titulo,status,criado_em').limit(20000)]);
    if(s.error)throw s.error;if(c.error)throw c.error;
    sellerCache=s.data||[];sellerCaseCache=c.data||[];renderSellers();sellerFeedback(`${sellerCache.length} sellers carregados. Cadastros compartilhados por todos os chamados.`);
  }catch(e){sellerFeedback('Não foi possível carregar sellers: '+e.message,true)}
}
function renderSellers(){
 const q=sel('sellerSearch').value.trim().toLocaleLowerCase('pt-BR');const body=sel('sellersBody');body.replaceChildren();
 const rows=sellerCache.filter(s=>`${s.nome||''} ${s.nome_loja||''} ${s.email||''} ${s.telefone||''} ${s.mcid||''}`.toLocaleLowerCase('pt-BR').includes(q));
 if(!rows.length){const td=body.insertRow().insertCell();td.colSpan=5;td.textContent='Nenhum seller encontrado.';return}
 for(const x of rows){const tr=body.insertRow();for(const t of [x.nome,x.nome_loja||'—',x.email||x.telefone||'—',String(sellerCaseCache.filter(a=>a.seller_id===x.id).length)])tr.insertCell().textContent=t;const cell=tr.insertCell();const b=document.createElement('button');b.className='case-secondary';b.textContent='Abrir ficha';b.addEventListener('click',()=>openSeller(x.id));cell.append(b)}
}
function openSeller(id){
 const x=sellerCache.find(s=>s.id===id);if(!x){window.switchSellerView?.();loadSellers().then(()=>openSeller(id));return}
 sel('sellerForm').reset();sel('editSellerId').value=id;sel('sellerModalTitle').textContent='Ficha do seller — '+x.nome;
 for(const [field,val] of [['Name',x.nome],['Store',x.nome_loja],['Email',x.email],['Phone',x.telefone],['MCID',x.mcid],['CNPJ',x.cnpj]])sel('editSeller'+field).value=val||'';
 const linked=sel('sellerLinkedCases');linked.replaceChildren();const cases=sellerCaseCache.filter(c=>c.seller_id===id);if(!cases.length){linked.textContent='Nenhum chamado vinculado ainda.'}else{for(const c of cases){const line=document.createElement('p');line.textContent=`${c.titulo} — ${c.status}`;linked.append(line)}}
 sel('sellerSaveMessage').textContent='';sel('sellerModal').classList.remove('hidden');sel('editSellerName').focus();
}
window.openSeller=openSeller;
sel('newSellerButton').addEventListener('click',()=>{sel('sellerForm').reset();sel('editSellerId').value='';sel('sellerModalTitle').textContent='Novo seller';sel('sellerLinkedCases').textContent='Ainda sem chamados vinculados.';sel('sellerSaveMessage').textContent='';sel('sellerModal').classList.remove('hidden')});
sel('closeSellerModal').addEventListener('click',()=>sel('sellerModal').classList.add('hidden'));
sel('sellerModal').addEventListener('click',ev=>{if(ev.target===sel('sellerModal'))sel('sellerModal').classList.add('hidden')});
document.addEventListener('keydown',ev=>{if(ev.key==='Escape')sel('sellerModal').classList.add('hidden')});
sel('sellerSearch').addEventListener('input',renderSellers);sel('refreshSellers').addEventListener('click',loadSellers);
sel('sellerWhatsApp').addEventListener('click',()=>{const number=sel('editSellerPhone').value.replace(/\D/g,'');if(number.length<10||number.length>15){sel('sellerSaveMessage').textContent='Informe um telefone válido com DDI para abrir o WhatsApp.';return}window.open('https://wa.me/'+number,'_blank','noopener,noreferrer')});
sel('sellerForm').addEventListener('submit',async ev=>{ev.preventDefault();const button=sel('saveSeller');button.disabled=true;try{
 await getAuthed();const id=sel('editSellerId').value;const nome=sel('editSellerName').value.trim();if(nome.length<2)throw Error('Informe o nome do seller.');const payload={nome,nome_loja:sel('editSellerStore').value.trim()||null,email:sel('editSellerEmail').value.trim()||null,telefone:sel('editSellerPhone').value.trim()||null,mcid:sel('editSellerMCID').value.trim()||null,cnpj:sel('editSellerCNPJ').value.trim()||null};
 const response=id?await sb.from('sellers').update(payload).eq('id',id).select('id').single():await sb.from('sellers').insert(payload).select('id').single();if(response.error)throw response.error;
 sel('sellerSaveMessage').textContent='Seller salvo com sucesso.';await loadSellers();if(window.loadCases)await loadCases();if(window.loadDashboard)await loadDashboard();
 }catch(e){sel('sellerSaveMessage').textContent='Erro ao salvar: '+e.message}finally{button.disabled=false}});
window.loadSellers=loadSellers;
