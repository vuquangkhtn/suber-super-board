/* Shared skill-map dialog component (SM). Inlined by diagrams/impeccable/build.py and diagrams/pstack/gen.py.
   Markup in text: **bold**  ==highlight (one per section)==  `code`  [[id]] (tappable chip, label from opts.label). */
var SM=(function(){
 function el(t,c,x){var e=document.createElement(t);if(c)e.className=c;if(x!=null)e.textContent=x;return e}
 function Dlg(dlg,opts){
  var body=el('div'),btn=el('button','x','×');btn.type='button';btn.setAttribute('aria-label','Close');
  dlg.textContent='';dlg.appendChild(btn);dlg.appendChild(body);dlg.classList.add('sm');
  var self={body:body,dlg:dlg,opts:opts};
  function chip(id){var c=el('button','chip',opts.label?opts.label(id):id);c.type='button';c.dataset.go=id;return c}
  function md(p,s){String(s).split(/(\*\*.+?\*\*|==.+?==|`.+?`|\[\[[^\]]+\]\])/).forEach(function(x){if(!x)return;
   if(x.slice(0,2)==='**')p.appendChild(el('b',null,x.slice(2,-2)));else if(x.slice(0,2)==='==')p.appendChild(el('mark',null,x.slice(2,-2)));
   else if(x[0]==='`')p.appendChild(el('code',null,x.slice(1,-1)));else if(x.slice(0,2)==='[[')p.appendChild(chip(x.slice(2,-2)));else p.appendChild(document.createTextNode(x))})}
  function sec(label,key){body.appendChild(el('h4','l-'+key,label))}
  function para(s){var p=el('p');md(p,s);body.appendChild(p)}
  function list(a,ordered){var u=el(ordered?'ol':'ul');a.forEach(function(x){var li=el('li');md(li,x);u.appendChild(li)});body.appendChild(u)}
  /* "When X -> use this" list: each item "situation → action" */
  function when(a){var u=el('ul','wl');(typeof a==='string'?[a]:a).forEach(function(x){var li=el('li'),i=x.indexOf('→');
   if(i<0){var c0=el('span','wc');md(c0,x);li.appendChild(c0)}else{var c=el('span','wc');md(c,x.slice(0,i).trim());li.appendChild(c);li.appendChild(el('span','ar','→'));var w=el('span','wu');md(w,x.slice(i+1).trim());li.appendChild(w)}
   u.appendChild(li)});body.appendChild(u)}
  function flow(f){var d=el('div','fl');f.forEach(function(tk,i){if(i)d.appendChild(el('span','ar','→'));
   if(Array.isArray(tk)){var g=el('span','cg');tk.forEach(function(x){g.appendChild(chip(x.slice(1)))});d.appendChild(g)}
   else if(tk&&tk.stack){var sk=el('span','stack');tk.stack.forEach(function(x){var p=el('span','pill');md(p,x);sk.appendChild(p)});d.appendChild(sk)}
   else if(tk[0]==='@'){d.appendChild(chip(tk.slice(1)))}
   else{var p=el('span','pill'+(i===0&&tk[0]==='/'?' cmd':''));md(p,tk);d.appendChild(p)}});body.appendChild(d)}
  /* rows: [label, content, kind]  kind 'code' = exact prompt, array content = numbered steps */
  function example(rows,note){var b=el('div','ex');rows.forEach(function(r){var row=el('div','exr');row.appendChild(el('b',null,r[0]));
   if(r[2]==='code')row.appendChild(el('code',null,r[1]));else if(Array.isArray(r[1])){var o=el('ol');r[1].forEach(function(s){var li=el('li');md(li,s);o.appendChild(li)});row.appendChild(o)}else{var s=el('span');md(s,r[1]);row.appendChild(s)}
   b.appendChild(row)});b.appendChild(el('p','exn',note||'Example'));body.appendChild(b)}
  function chips(ids){var h=el('div','hl');ids.forEach(function(n){h.appendChild(chip(n))});body.appendChild(h)}
  function note(s){var n=el('p','note2');md(n,s);body.appendChild(n)}
  function tags(a){var t=el('div','tags');a.forEach(function(x){t.appendChild(el('span','tag'+(x[1]?' k':''),x[0]))});body.appendChild(t)}
  /* model: {accent, title, tags:[[text,key?]], blocks:[{label,key,type,v,note}]}; type: p ul ol when flows example chips note node */
  self.render=function(m){body.textContent='';dlg.className='sm '+(m.accent||'');if(m.title)body.appendChild(el('h3',null,m.title));if(m.tags)tags(m.tags);
   m.blocks.forEach(function(b){if(b.label)sec(b.label,b.key||'how');var t=b.type;
    if(t==='p')para(b.v);else if(t==='ul')list(b.v);else if(t==='ol')list(b.v,1);else if(t==='when')when(b.v);else if(t==='flows')b.v.forEach(flow);
    else if(t==='example')example(b.v,b.note);else if(t==='chips')chips(b.v);else if(t==='note')note(b.v);else if(t==='node')b.v(body,self)})};
  self.open=function(){if(!dlg.open){try{dlg.showModal()}catch(e){dlg.setAttribute('open','')}}dlg.scrollTop=0;btn.focus({preventScroll:true})};
  self.close=function(){if(dlg.open){try{dlg.close()}catch(e){dlg.removeAttribute('open')}}};
  dlg.addEventListener('click',function(e){var c=e.target.closest&&e.target.closest('[data-go]');if(c){opts.onGo&&opts.onGo(c.dataset.go);return}
   if(e.target.closest('.x')){self.close();return}
   var r=dlg.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)self.close()});
  dlg.addEventListener('close',function(){opts.onClose&&opts.onClose()});
  self.md=md;self.el=el;self.chip=chip;self.sec=sec;self.para=para;self.list=list;self.flow=flow;
  return self}
 /* "a • b • c" -> list; arrays pass through */
 function bullets(w){return Array.isArray(w)?w:String(w).split(' • ')}
 /* "**Situation:** text. (1) a. (2) b." -> {situation, steps[]} */
 function story(s){var m=String(s).match(/^\s*\*\*Situation:\*\*\s*([\s\S]*?)\s*(\(1\)[\s\S]*)?$/),sit=m?m[1]:'',steps=[];
  if(m&&m[2])m[2].split(/\(\d+\)\s*/).forEach(function(x){x=x.trim();if(x)steps.push(x)});return {situation:sit,steps:steps}}
 return {Dialog:Dlg,el:el,bullets:bullets,story:story}
})();
