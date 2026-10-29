var DATA=%%DATA%%;var S=DATA.skills;
function link(u,l){var a=SM.el('a',null,l);a.href=u;a.target='_blank';a.rel='noopener';return a}
function model(id){
 var s=S[id],gi=id.indexOf('grp:')===0?DATA.groupsInfo[id.slice(4)]:null;
 var cat=gi?id.slice(4):(s?s.category:'principles');if(id==='poteto-mode')cat='router';
 var m={accent:'c-'+cat,blocks:[]},B=m.blocks;
 if(id==='__how'){m.title='How principles work';m.tags=[['24 principles',1]];
  B.push({label:'How they work',key:'how',type:'ul',v:DATA.how});
  B.push({label:'When each group applies',key:'when',type:'ul',v:Object.keys(DATA.groups).map(function(k){var g2=DATA.groups[k];return '**'+g2.name+':** '+g2.howItWorks})})}
 else if(gi){m.title=gi.name;
  B.push({label:'What it is for',key:'grp',type:'p',v:gi.blurb});
  B.push({type:'note',v:"**Not a command, it's a group.** Pick a skill inside it."});
  B.push({label:'When X → pick Y',key:'when',type:'when',v:gi.items.map(function(it){return it[0]+' → [['+it[1]+']]'})});
  B.push({label:'Example',key:'ex',type:'example',v:[['You say','“'+gi.ex[0]+'”'],['Use','[['+gi.ex[1]+']]']],note:'Example'});
  B.push({label:'Does poteto-mode route here?',key:'picks',type:'p',v:gi.routes})}
 else{
  m.title=s.name;var tg=[];
  if(s.kind==='skill'){tg.push([s.command,1]);if(s.trigger)tg.push([s.trigger])}else tg.push(['principle',1]);
  tg.push([s.kind==='skill'?DATA.cats[s.category]:DATA.groups[s.principleGroup].name]);m.tags=tg;
  if(id==='poteto-mode')B.push({label:'Official diagram',key:'diag',type:'node',v:function(body){var im=SM.el('img','dimg');im.src=DATA.img;im.alt='Official pstack overview';body.appendChild(im)}});
  B.push({label:s.kind==='skill'?'When to use it':'When it applies',key:'when',type:'when',v:SM.bullets(s.when)});
  B.push({label:'What it is',key:'is',type:'p',v:s.whatItIs});
  if(s.kind==='skill'){
   B.push({label:'How it works',key:'how',type:'ol',v:s.steps});
   if(s.ex){var sy=SM.story(s.ex[1]);B.push({label:'Example',key:'ex',type:'example',v:[['Situation',sy.situation],['You type',s.ex[0],'code'],['What happens',sy.steps.length?sy.steps:s.ex[1]],['You get',s.ex[2]]],note:s.ex[3]?'Example. Prompt taken from the official guide.':'Example. Written from the skill file.'})}
   if(s.picks)B.push({label:'How it picks',key:'picks',type:'flows',v:s.picks});
   if(s.calls)B.push({label:'Calls these',key:'calls',type:'flows',v:s.calls});
   if(s.diag){B.push({label:'Diagram (from the official guide)',key:'diag',type:'flows',v:s.diag.flows});B.push({type:'node',v:function(body){var c3=SM.el('p','cr');c3.appendChild(document.createTextNode('source: '));c3.appendChild(link(s.diag.url,s.diag.src));body.appendChild(c3)}})}
   if(s.flows&&s.flows.length)B.push({label:'Behind the scenes',key:'bts',type:'flows',v:s.flows});
   B.push({label:'You get',key:'get',type:'p',v:s.output});
   B.push({label:'Use it',key:'use',type:'ul',v:['**Claude Code:** '+(s.claudeCode||''),'**Codex:** '+(s.codex||'').replace(/^Codex: /,'')]});
   if(!s.calls&&s.handsOffTo&&s.handsOffTo.length)B.push({label:'Next',key:'next',type:'chips',v:s.handsOffTo})
  }else{B.push({label:'In practice',key:'how',type:'ul',v:s.inPractice});B.push({label:'Use it',key:'use',type:'p',v:s.claudeCode||''})}
  B.push({type:'node',v:function(body){var sr=SM.el('div','src');sr.appendChild(SM.el('span','badge b-'+s.source,{both:'Claude Code + Cursor',claude:'Claude Code only',cursor:'Cursor only'}[s.source]));
   if(s.source==='both'){sr.appendChild(link(s.url,'Cursor source'));if(s.claudeUrl)sr.appendChild(link(s.claudeUrl,'Claude port source'))}else sr.appendChild(link(s.url,'Source file'));body.appendChild(sr)}})}
 return m}
SMPAGE={model:model,label:function(id){return S[id]?S[id].name:id},afterFilter:function(vis){
 var nds=Array.prototype.slice.call(document.querySelectorAll('#hero svg [data-id]'));
 Array.prototype.slice.call(document.querySelectorAll('#hero .rg')).forEach(function(r){var c=r.dataset.cat,any=c==='router'||nds.some(function(g){var s=S[g.dataset.id];return s&&s.category===c&&vis[g.dataset.id]});r.classList.toggle('dim',!any)})}};
window.SMDATA={search:{},filt:{}};Object.keys(S).forEach(function(k){var s=S[k];SMDATA.search[k]=[s.name,s.command,s.trigger,s.whatItIs,s.summary].join(' ');SMDATA.filt[k]=s.source==='both'?['claude','cursor']:[s.source]});
Object.keys(DATA.groupsInfo).forEach(function(c){SMDATA.search['grp:'+c]=DATA.groupsInfo[c].name+' '+DATA.groupsInfo[c].blurb});
