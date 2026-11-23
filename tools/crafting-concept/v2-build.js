// Monta mockup-v2.html: duas opções de disposição das categorias (A painéis, B estante)
const fs = require("fs"), path = require("path");
const P = (f) => path.join(__dirname, f);
// parte do mockup aprovado e troca só a área das categorias
let s = fs.readFileSync(P("mockup.html"), "utf8");
{
  const a = s.indexOf('  <div class="decks">'), b = s.indexOf(' <div class="altar">'), e = s.lastIndexOf(" </div>", b);
  s = s.slice(0, a) + '  <div id="optA" class="optA"></div>\n  <div id="optB" class="optB" style="display:none"></div>\n' + s.slice(e);
  s = s.replace(/ <div class="note" data-n="[1234]"[^\n]*\n/g, "");
}

const css = `
.note{display:none!important}
.note2{position:absolute;font-family:"Segoe UI",sans-serif;font-size:13px;color:#0b1219;background:#f2d64b;padding:7px 11px;border-radius:3px;max-width:260px;z-index:9;line-height:1.35;box-shadow:0 4px 14px #0008}
.switch{position:absolute;left:640px;top:68px;display:flex;z-index:10;border:1px solid #d8b46a88;font-family:"Segoe UI",sans-serif}
.switch span{padding:6px 16px;font-size:13px;color:#c9c2b0;cursor:pointer;background:#0b1219ee}
.switch span.on{background:#f2d64b;color:#0b1219;font-weight:600}
.optA,.optB{margin-top:18px}
.optA{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;align-items:start}
.cat{background:linear-gradient(#122029ee,#0a1218ee);border:1px solid #d8b46a40;position:relative}
.cat:before{content:"";position:absolute;left:0;right:0;top:0;height:2px;background:linear-gradient(90deg,transparent,var(--gold),transparent);opacity:.7}
.ch{display:flex;align-items:center;gap:12px;padding:14px 14px 10px;border-bottom:1px solid #ffffff12}
.ch .ci{width:44px;height:44px;border-radius:50%;border:2px solid var(--gold2);background:radial-gradient(var(--h),#120c06 72%);flex:none}
.ch .cn{font-size:16px;letter-spacing:1px}
.ch .cs{font-size:11px;color:var(--mut);margin-top:3px}
.ch .cs b{color:var(--teal);font-weight:400}
.ch .mini{margin-left:auto;display:flex;gap:3px}
.ch .mini i{width:7px;height:7px;transform:rotate(45deg);background:var(--c)}
.row{display:flex;align-items:center;gap:10px;height:46px;padding:0 12px;border-bottom:1px solid #ffffff08}
.row:last-child{border-bottom:none}
.row .ri{width:32px;height:32px;border-radius:50%;border:1px solid var(--gold2);background:radial-gradient(var(--h),#120c06 72%);flex:none}
.row .rn{font-size:13px;flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.row .gm{width:9px;height:9px;transform:rotate(45deg);background:var(--c);flex:none;box-shadow:0 0 6px var(--c)}
.row .q{font-size:12px;color:#0b1219;background:var(--teal);padding:1px 6px;font-family:"Segoe UI",sans-serif;font-weight:600}
.row .ms{font-size:11px;color:#e0605a;font-family:"Segoe UI",sans-serif}
.row.dim .rn,.row.dim .ri{opacity:.5}
.row.sel{background:#1c4247cc;box-shadow:inset 3px 0 0 var(--teal)}
.row .st{color:var(--gold);font-size:12px}
.shelf{display:flex;gap:10px}
.tile{width:144px;height:118px;flex:none;background:linear-gradient(#122029ee,#0a1218ee);border:1px solid #d8b46a33;text-align:center;padding-top:10px;position:relative;cursor:pointer}
.tile .ti{width:50px;height:50px;border-radius:50%;margin:0 auto;border:2px solid var(--gold2);background:radial-gradient(var(--h),#120c06 72%)}
.tile .tn{font-size:12px;margin-top:7px;line-height:1.2;height:29px;padding:0 6px}
.tile .tc{position:absolute;right:8px;top:7px;font-size:12px;color:var(--gold)}
.tile .rd{position:absolute;left:8px;top:8px;font-size:11px;color:#0b1219;background:var(--teal);padding:0 5px;font-family:"Segoe UI",sans-serif;font-weight:600}
.tile.on{border-color:var(--teal);background:linear-gradient(#1c4247,#0f1f26);box-shadow:0 0 20px #5fd6d044}
.tile.on:after{content:"";position:absolute;left:20%;right:20%;bottom:-1px;height:3px;background:var(--teal);box-shadow:0 0 10px var(--teal)}
.tile.all .ti{background:radial-gradient(#d8b46a,#3a2a10 72%)}
.bh{display:flex;align-items:baseline;gap:14px;margin:22px 0 12px;border-bottom:1px solid #d8b46a33;padding-bottom:8px}
.bh h3{margin:0;font-weight:400;font-size:22px;letter-spacing:1px}
.bh span{font-size:12px;color:var(--mut)}
.bh .sort{margin-left:auto;font-size:12px;color:#c9c2b0}
.big{display:grid;grid-template-columns:repeat(4,1fr);gap:14px}
.bc{height:250px;background:linear-gradient(#152430f0,#0b141bf0);border:1px solid #ffffff1a;position:relative;padding:14px;display:flex;flex-direction:column}
.bc:before{content:"";position:absolute;left:0;right:0;top:0;height:3px;background:var(--c)}
.bc .top{display:flex;gap:12px;align-items:center}
.bc .bi{width:66px;height:66px;border-radius:50%;border:2px solid var(--gold2);background:radial-gradient(var(--h),#120c06 72%);flex:none}
.bc .bn{font-size:15px;line-height:1.25}
.bc .dl{font-size:11px;color:var(--c);margin-top:4px;font-family:"Segoe UI",sans-serif}
.bc .mats{margin-top:14px;display:flex;flex-direction:column;gap:6px;flex:1}
.bc .m{display:flex;align-items:center;gap:8px;font-size:12px;font-family:"Segoe UI",sans-serif;color:#c9c2b0}
.bc .m i{width:20px;height:20px;border-radius:50%;border:1px solid #6ad06a;background:#2a3a30;flex:none}
.bc .m b{margin-left:auto;font-weight:400;color:var(--gr)}
.bc .m.no i{border-color:#c0504a;background:#3a2222}.bc .m.no b{color:#e0605a}
.bc .foot{display:flex;align-items:center;justify-content:space-between;border-top:1px solid #ffffff12;padding-top:9px}
.bc .foot .q{font-size:13px;color:#0b1219;background:var(--teal);padding:2px 8px;font-family:"Segoe UI",sans-serif;font-weight:600}
.bc .foot .x{font-size:12px;color:var(--mut);font-family:"Segoe UI",sans-serif}
.bc.sel{border-color:var(--teal);box-shadow:0 0 0 1px var(--teal),0 0 24px #5fd6d055}
.bc.dim .bi,.bc.dim .bn{opacity:.55}
`;

const js = `
(function(){
var C={or:'var(--or)',ye:'var(--ye)',gr:'var(--gr)',gy:'var(--gy)'},DL={or:'Sempre sobe',ye:'Provável',gr:'Raro',gy:'Não sobe'};
var cats=[
 {n:'Refeições do Dia-a-dia',h:'#d08a3a',r:[['Mariscos Fervidos','or','#e07a50',2,[['Marisco',3,1],['Água Refrescante',2,1]]],['Kebab Kaldorei de Aranha','ye','#a06030',0,[['Perna de Aranha',0,1],['Tempero Suave',1,1]],1],['Carne Tostada de Lobo','gr','#904030',0,[['Carne de Lobo',0,1],['Tempero Suave',0,1]]]]},
 {n:'Comidas de Força',h:'#c04030',r:[['Empadão de Fígado de Goretusco','or','#a04a30',1,[['Fígado de Goretusco',1,1],['Tempero Quente',1,1],['Farinha',2,1]]],['Carne Assada de Porco','gr','#c07050',0,[['Costela de Porco',0,1]]]]},
 {n:'Comidas de Agilidade',h:'#6ad06a',r:[['Bife de Coiote','or','#b05030',4,[['Carne de Coiote',4,1]],1],['Carne Temperada de Lobo','ye','#905040',0,[['Carne de Lobo',0,1],['Tempero Suave',1,1]]]]},
 {n:'Comidas de Vigor',h:'#5fd6d0',r:[['Ovo Assado com Ervas','gr','#f0c0b0',0,[['Ovo Pequeno',0,1],['Tempero Suave',0,1]]]]},
 {n:'Comidas de Intelecto',h:'#6a8ad0',r:[['Ensopado de Moa','or','#7080a0',0,[['Carne de Moa',0,2],['Cebola',1,1]]]]},
 {n:'Acampamento',h:'#ff8a3d',r:[['Fogueira Básica','gy','#ff8a3d',9,[['Gravetos',9,1]]]]}
];
var SEL='Ovo Assado com Ervas';
function ready(r){return r[3]>0}
function rowHtml(r){var cls='row'+(r[0]===SEL?' sel':'')+(ready(r)?'':' dim');var miss=r[4].filter(function(m){return m[1]<m[2]}).length;
 return '<div class="'+cls+'" style="--c:'+C[r[1]]+';--h:'+r[2]+'"><span class="gm"></span><span class="ri"></span><span class="rn">'+r[0]+'</span>'+(r[5]?'<span class="st">★</span>':'')+(ready(r)?'<span class="q">x'+r[3]+'</span>':'<span class="ms">falta '+miss+'</span>')+'</div>'}
var A='';cats.forEach(function(c){var rd=c.r.filter(ready).length;
 A+='<div class="cat"><div class="ch"><span class="ci" style="--h:'+c.h+'"></span><div><div class="cn">'+c.n+'</div><div class="cs sans">'+c.r.length+(c.r.length>1?' receitas':' receita')+' · <b>'+rd+' pronta'+(rd==1?'':'s')+'</b></div></div><div class="mini">'+c.r.map(function(r){return '<i style="--c:'+C[r[1]]+'"></i>'}).join('')+'</div></div>'+c.r.map(rowHtml).join('')+'</div>'});
document.getElementById('optA').innerHTML=A;
function bigHtml(r){var cls='bc'+(r[0]===SEL?' sel':'')+(ready(r)?'':' dim');
 return '<div class="'+cls+'" style="--c:'+C[r[1]]+';--h:'+r[2]+'"><div class="top"><span class="bi"></span><div><div class="bn">'+r[0]+'</div><div class="dl">'+DL[r[1]]+'</div></div></div><div class="mats">'+r[4].map(function(m){return '<div class="m'+(m[1]<m[2]?' no':'')+'"><i></i>'+m[0]+'<b>'+m[1]+' / '+m[2]+'</b></div>'}).join('')+'</div><div class="foot">'+(ready(r)?'<span class="q">pode criar x'+r[3]+'</span>':'<span class="x">faltam materiais</span>')+(r[5]?'<span style="color:var(--gold)">★</span>':'')+'</div></div>'}
var cur=0;function renderB(){var all=0;cats.forEach(function(c){all+=c.r.length});
 var B='<div class="shelf"><div class="tile all'+(cur<0?' on':'')+'" data-i="-1"><span class="tc">'+all+'</span><div class="ti"></div><div class="tn">Todas</div></div>';
 cats.forEach(function(c,i){var rd=c.r.filter(ready).length;B+='<div class="tile'+(i===cur?' on':'')+'" data-i="'+i+'">'+(rd?'<span class="rd">'+rd+' pronta'+(rd>1?'s':'')+'</span>':'')+'<span class="tc">'+c.r.length+'</span><div class="ti" style="--h:'+c.h+'"></div><div class="tn">'+c.n+'</div></div>'});
 B+='</div>';var list=cur<0?cats.reduce(function(a,c){return a.concat(c.r)},[]):cats[cur].r;var nm=cur<0?'Todas as receitas':cats[cur].n;
 B+='<div class="bh"><h3>'+nm+'</h3><span class="sans">'+list.length+' receita'+(list.length>1?'s':'')+' · prontas primeiro</span><span class="sort sans">Ordenar: chance de subir perícia</span></div><div class="big">'+list.slice().sort(function(a,b){return b[3]-a[3]}).slice(0,8).map(bigHtml).join('')+'</div>';
 var el=document.getElementById('optB');el.innerHTML=B;el.querySelectorAll('.tile').forEach(function(t){t.onclick=function(){cur=+t.dataset.i;renderB()}})}
renderB();
document.querySelectorAll('.switch span').forEach(function(s){s.onclick=function(){var b=s.dataset.o==='B';
 document.querySelectorAll('.switch span').forEach(function(x){x.classList.toggle('on',x===s)});
 document.getElementById('optA').style.display=b?'none':'';document.getElementById('optB').style.display=b?'':'none';
 document.querySelectorAll('.nA').forEach(function(n){n.style.display=b?'none':''});document.querySelectorAll('.nB').forEach(function(n){n.style.display=b?'':'none'})}});
if(location.hash==='#B')document.querySelector('.switch span[data-o=B]').click();
})();
`;

const notes = `<div class="switch"><span class="on" data-o="A">Opção A · painéis por categoria</span><span data-o="B">Opção B · estante + cartas grandes</span></div>
 <div class="note2 nA" style="left:200px;top:700px">Cada categoria é um painel separado: cabeçalho com ícone, total e quantas estão prontas; losangos mostram a mistura de dificuldades</div>
 <div class="note2 nA" style="left:620px;top:700px">Receitas em linhas legíveis dentro do painel: losango = chance de subir, xN = dá para criar, "falta N" = materiais faltando</div>
 <div class="note2 nB" style="left:200px;top:720px;display:none">Primeiro escolhe a categoria na estante (com selo de quantas estão prontas); "Todas" mostra tudo</div>
 <div class="note2 nB" style="left:620px;top:720px;display:none">Só as receitas da categoria escolhida, em cartas grandes com os materiais e a contagem escritos por extenso</div>
`;

s = s.replace("</style></head><body>", css + "</style></head><body>");
s = s.replace('\n <div class="altar">', "\n" + notes + ' <div class="altar">');
s = s.replace("\nfunction fit(", js + "\nfunction fit(");
fs.writeFileSync(P("mockup-v2.html"), s);
console.log("montado", s.includes('class="switch"'), s.includes("renderB"));
