/* Shared page behaviour: theme (nav button), search + filter dimming, full screen, dialog open/close. Page JS sets SMPAGE = {model(id), label(id), afterFilter?(visible)} and window.SMDATA = {search:{id:text}, filt:{id:[values]}}. */
(function(){
 var root=document.documentElement,$=function(s,r){return Array.prototype.slice.call((r||document).querySelectorAll(s))};
 try{var th=localStorage.getItem('sb-theme');if(th)root.setAttribute('data-theme',th)}catch(e){}
 document.getElementById('sbtt').onclick=function(){var d=root.getAttribute('data-theme')||(matchMedia('(prefers-color-scheme:dark)').matches?'dark':'light'),n=d==='dark'?'light':'dark';root.setAttribute('data-theme',n);try{localStorage.setItem('sb-theme',n)}catch(e){}};
 var hero=document.getElementById('hero'),dlg=document.getElementById('pop'),P=SMPAGE,DATA=window.SMDATA||{search:{},filt:{}};
 var nodes=function(){return $('#hero svg [data-id]')},st={q:'',f:'all'},cur=null,last=null;
 function apply(){var vis={};nodes().forEach(function(g){var id=g.dataset.id,t=DATA.search[id];if(t==null)return;
  var fv=DATA.filt[id],ok=(st.f==='all'||!fv||fv.indexOf(st.f)>=0)&&(!st.q||t.toLowerCase().indexOf(st.q)>=0);vis[id]=ok;g.classList.toggle('dim',!ok)});
  if(P.afterFilter)P.afterFilter(vis)}
 document.getElementById('q').addEventListener('input',function(e){st.q=e.target.value.trim().toLowerCase();apply()});
 $('.seg button').forEach(function(b){b.addEventListener('click',function(){st.f=b.dataset.f;$('.seg button').forEach(function(x){x.setAttribute('aria-pressed',String(x===b))});apply()})});
 var D=SM.Dialog(dlg,{label:P.label,onGo:function(id){open(id)},onClose:function(){nodes().forEach(function(x){x.classList.remove('sel')});cur=null;if(last)try{last.focus({preventScroll:true})}catch(e){}}});
 function open(id){var g=nodes().filter(function(x){return x.dataset.id===id})[0];if(!g||!P.model(id))return;if(!dlg.open)last=g;
  D.render(P.model(id));cur=id;nodes().forEach(function(x){x.classList.toggle('sel',x===g)});D.open()}
 window.SMopen=open;
 var sc=document.getElementById('sc');
 sc.addEventListener('click',function(e){var n=e.target.closest('[data-id]');if(n&&!(window.SMcanvas&&window.SMcanvas.moved))open(n.dataset.id)});
 sc.addEventListener('keydown',function(e){var n=e.target.closest&&e.target.closest('[data-id]');if(n&&(e.key==='Enter'||e.key===' ')){e.preventDefault();open(n.dataset.id)}});
 var fsb=document.getElementById('fsb'),fst=document.getElementById('fst'),exp=false;
 function fsOn(){return document.fullscreenElement===hero}
 function sync(){var on=exp||fsOn();fst.textContent=on?'Exit':'Full screen';fsb.setAttribute('aria-label',on?'Exit full screen':'Full screen')}
 function expand(on){exp=on;hero.classList.toggle('exp',on);root.classList.toggle('lock',on);sync()}
 function exitAll(){if(fsOn()){try{document.exitFullscreen()}catch(e){}}if(exp)expand(false)}
 fsb.addEventListener('click',function(){if(exp||fsOn()){exitAll();return}var p;try{p=hero.requestFullscreen?hero.requestFullscreen():null}catch(x){p=null}
  if(p&&p.then){p.then(sync,function(){expand(true)})}else if(!p){expand(true)}});
 document.addEventListener('fullscreenchange',sync);
 document.addEventListener('keydown',function(e){if(e.key==='Escape'&&!dlg.open&&exp)expand(false)});
 apply();
})();
