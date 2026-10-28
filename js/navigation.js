
// Navegação desktop e mobile, sem modificar autenticação existente.
(function(){
  const nav=document.querySelectorAll('[data-view]');
  const admin=document.getElementById('adminArea');
  const menu=document.getElementById('mobileMenu');
  const side=document.querySelector('.app-sidebar');
  const dashboardNodes=['.topline','.dash-message','.stats','.filters','.table-wrap'];
  function switchView(view){
    const canAdmin=!!profile&&profile.cargo==='admin';
    if(view==='admin'&&!canAdmin)view='dashboard';
    admin.classList.toggle('hidden',view!=='admin'||!canAdmin);
    dashboardNodes.forEach(selector=>document.querySelector('.app-main '+selector)?.classList.toggle('hidden',view!=='dashboard'));
    nav.forEach(btn=>btn.classList.toggle('active',btn.dataset.view===view));
    if(side)side.classList.remove('sidebar-open');
    if(menu)menu.setAttribute('aria-expanded','false');
  }
  nav.forEach(btn=>btn.addEventListener('click',()=>switchView(btn.dataset.view)));
  if(menu)menu.addEventListener('click',()=>{const active=side.classList.toggle('sidebar-open');menu.setAttribute('aria-expanded',String(active));});
  const obs=new MutationObserver(()=>{
    if(!document.getElementById('welcome').classList.contains('hidden')){
      const canAdmin=!!profile&&profile.cargo==='admin';
      document.querySelector('[data-view="admin"]')?.classList.toggle('hidden',!canAdmin);
      switchView('dashboard');
    }
  });
  obs.observe(document.getElementById('welcome'),{attributes:true,attributeFilter:['class']});
  document.querySelector('[data-view="admin"]')?.classList.add('hidden');
})();
