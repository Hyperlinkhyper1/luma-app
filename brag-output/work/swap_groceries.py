import re
p = r'C:\Users\ayden\Downloads\luma-app\brag-output\composition\index.html'
s = open(p, encoding='utf-8').read()


def rep(old, new, count=1):
    global s
    n = s.count(old)
    assert n == count, (old[:70], n)
    s = s.replace(old, new)


def between(start, end, new):
    global s
    a = s.index(start)
    b = s.index(end)
    s = s[:a] + new + s[b:]


rep('<div class="lt" id="lt-calc"><div class="eyebrow"><span class="ic">functions</span>Calculator</div><div class="line">Everyday sums <em>and graphs.</em></div></div>',
    '<div class="lt" id="lt-groc"><div class="eyebrow"><span class="ic">local_grocery_store</span>Groceries List</div><div class="line">Compare <em>supermarket prices</em> side by side.</div></div>')

between('      <div class="pane" id="p-calc">', '      <div class="pane" id="p-recipe">', '''      <div class="pane" id="p-groc">
        <div style="display:flex;gap:8px;align-items:center;margin-bottom:18px" id="gStores"></div>
        <div style="display:grid;grid-template-columns:1.2fr 1fr;gap:16px">
          <div class="card gc" style="padding:20px;height:620px;position:relative">
            <div style="height:46px;border-radius:12px;background:var(--bg);border:1px solid rgba(180,157,245,.45);display:flex;align-items:center;gap:10px;padding:0 14px;font-size:16px"><span class="ic" style="font-size:21px;color:var(--accent)">search</span><span id="gq"></span></div>
            <div style="display:flex;justify-content:space-between;align-items:center;margin:16px 0 8px"><div class="lbl" id="gCount">Results</div><span class="pill on" style="height:26px">Price ↑</span></div>
            <div id="gRes"></div>
            <div class="muted" style="position:absolute;left:20px;bottom:16px;font-size:12px">Example prices</div>
          </div>
          <div class="card gc" style="padding:20px;height:620px;display:flex;flex-direction:column">
            <div style="display:flex;justify-content:space-between;align-items:baseline"><div style="font-size:18px;font-weight:700">Weekend shop</div><div class="muted" style="font-size:13.5px" id="gItems">5 items</div></div>
            <div id="gList" style="flex:1;margin-top:10px"></div>
            <div style="display:flex;justify-content:space-between;align-items:center;padding-top:14px;border-top:1px solid var(--border)"><div style="font-size:16px;font-weight:700">Total</div><div class="mono" style="font-size:26px;font-weight:700;color:var(--accent)" id="gTot">€12.95</div></div>
          </div>
        </div>
        <div id="gToast" style="position:absolute;left:50%;bottom:24px;transform:translateX(-50%);display:flex;align-items:center;gap:10px;padding:12px 18px;border-radius:14px;background:#1d2a26;border:1px solid rgba(87,217,163,.4);font-size:15px;font-weight:600;opacity:0;white-space:nowrap"><span class="ic" style="color:var(--ok);font-size:22px">check_circle</span>Added &quot;Oat drink 1 L&quot; to your list</div>
      </div>

''')

rep('["calc","functions"]', '["groc","local_grocery_store"]')

between('/* ---------- calculator ---------- */', '/* ---------- recipe planner ---------- */', r'''/* ---------- groceries ---------- */
const MK={jumbo:["Jumbo","#F6C500"],ah:["Albert Heijn","#4FA8DE"],hoog:["Hoogvliet","#E53935"],lidl:["Lidl","#3D6DC7"]};
const dot=c=>'<span style="width:10px;height:10px;border-radius:50%;background:'+c+';display:inline-block;flex:none"></span>';
pill($('gStores'),'<span class="pill on">All stores</span>');
Object.values(MK).forEach(([n,c])=>pill($('gStores'),'<span class="pill">'+dot(c)+n+'</span>'));
const GQ="oat drink";
const RES=[["lidl",129],["jumbo",149],["hoog",155],["ah",179]];
const gRows=RES.map(([m,c],i)=>{const e=h('div','display:flex;align-items:center;gap:14px;padding:13px 14px;border-radius:12px;margin-bottom:8px;background:var(--bg);border:1px solid '+(i==0?'rgba(87,217,163,.45)':'var(--border)'),
 '<div style="width:44px;height:44px;border-radius:11px;background:var(--hover);display:flex;align-items:center;justify-content:center"><span class="ic" style="font-size:24px;color:var(--t2)">local_drink</span></div>'+
 '<div style="flex:1"><div style="font-size:15.5px;font-weight:700">Oat drink 1 L</div><div style="display:flex;align-items:center;gap:7px;font-size:13px;margin-top:3px" class="sec">'+dot(MK[m][1])+MK[m][0]+(i==0?'<span class="gBadge" style="margin-left:6px;font-size:11.5px;font-weight:700;color:var(--ok);background:rgba(87,217,163,.14);border:1px solid rgba(87,217,163,.4);border-radius:20px;padding:1px 8px">Cheapest</span>':'')+'</div></div>'+
 '<div class="mono" style="font-size:19px;font-weight:700;color:'+(i==0?'var(--ok)':'var(--t1)')+'">€'+(c/100).toFixed(2)+'</div>'+
 '<div class="gAdd" style="width:36px;height:36px;border-radius:10px;border:1px solid rgba(180,157,245,.5);display:flex;align-items:center;justify-content:center;color:var(--accent)"><span class="ic" style="font-size:20px">add</span></div>');
 $('gRes').appendChild(e);return e;});
const gAddBtn=gRows[0].querySelector('.gAdd'),gBadge=gRows[0].querySelector('.gBadge');
const LIST=[["lidl",[["Bananas",119],["Pasta 500 g",89]]],["jumbo",[["Coffee beans",649],["Eggs ×10",299]]],["hoog",[["Tomatoes",139]]]];
let gNew=null;const gSecTot={};
LIST.forEach(([m,items])=>{const sec=h('div','margin-bottom:14px',
 '<div style="display:flex;align-items:center;gap:8px;font-size:13.5px;font-weight:700;margin-bottom:6px">'+dot(MK[m][1])+MK[m][0]+'<span style="flex:1"></span><span class="mono sec gst" style="font-size:13px"></span></div>');
 items.forEach(([n,c])=>sec.appendChild(h('div','display:flex;justify-content:space-between;padding:7px 0 7px 18px;font-size:14.5px;border-bottom:1px solid var(--border)','<span>'+n+'</span><span class="mono sec">€'+(c/100).toFixed(2)+'</span>')));
 if(m=='lidl'){gNew=h('div','display:flex;justify-content:space-between;padding:7px 0 7px 18px;font-size:14.5px;border-bottom:1px solid var(--border);border-radius:8px','<span>Oat drink 1 L</span><span class="mono" style="color:var(--ok)">€1.29</span>');sec.appendChild(gNew);}
 gSecTot[m]=[sec.querySelector('.gst'),items.reduce((a,b)=>a+b[1],0)];
 $('gList').appendChild(sec);});
const grocCards=[...document.querySelectorAll('#p-groc .gc')];

''')

rep('calc:36*B', 'groc:36*B')
rep("[S.calc,'calc','Calculator','p-calc']", "[S.groc,'groc','Groceries List','p-groc']")
rep(" [S.calc-.08,rail('calc'),.7],[S.calc+1.05,()=>keyEls['='],.7],[S.calc+2.4,[1450,560],.9],",
    " [S.groc-.08,rail('groc'),.7],[S.groc+1.8,()=>gAddBtn,.8],[S.groc+2.8,[1420,640],.7],")
rep("S.calc,S.calc+1.1,", "S.groc,S.groc+1.85,")
rep("block($('lt-calc'),S.calc,S.recipe);", "block($('lt-groc'),S.groc,S.recipe);")
rep("block($('lt-ai'),S.ai,S.calc);", "block($('lt-ai'),S.ai,S.groc);")

between('  /* calculator */', '  /* recipe */', r'''  /* groceries */
  s0=S.groc;
  stagger(grocCards,s0+.05,.08,.45,rise);
  const gt=Math.round(GQ.length*p(t,s0+.35,s0+.9));
  $('gq').innerHTML=gt?GQ.slice(0,gt)+(gt<GQ.length?'<span style="color:var(--accent)">|</span>':''):'<span class="muted">Search products…</span>';
  $('gCount').textContent=t>=s0+.95?'4 results · 4 stores':'Results';
  stagger(gRows,s0+.95,.09,.35,(e,a)=>{e.style.opacity=a;e.style.transform='translateY('+(1-a)*14+'px)';});
  const gb=back(p(t,s0+1.35,s0+1.65));gBadge.style.opacity=cl(gb);gBadge.style.display='inline-block';gBadge.style.transform='scale('+gb+')';
  const added=t>=s0+1.85;
  gAddBtn.style.background=added?'rgba(87,217,163,.15)':'transparent';gAddBtn.style.borderColor=added?'rgba(87,217,163,.5)':'rgba(180,157,245,.5)';
  gAddBtn.innerHTML='<span class="ic" style="font-size:20px;color:'+(added?'var(--ok)':'var(--accent)')+'">'+(added?'check':'add')+'</span>';
  gAddBtn.style.transform='scale('+((t>s0+1.8&&t<s0+1.93)?.9:1)+')';
  const na=eo(p(t,s0+1.85,s0+2.2));gNew.style.display=added?'flex':'none';gNew.style.opacity=na;gNew.style.background='rgba(87,217,163,'+(.18*(1-p(t,s0+2.3,s0+3)))+')';gNew.style.transform='translateX('+(1-na)*-20+'px)';
  Object.entries(gSecTot).forEach(([m,[el,v]])=>{el.textContent='€'+((v+(m=='lidl'&&added?129:0))/100).toFixed(2);});
  const tot=1295+Math.round(129*eo(p(t,s0+1.9,s0+2.5)));$('gTot').textContent='€'+(tot/100).toFixed(2);
  $('gItems').textContent=(added?6:5)+' items';
  const gtk=back(p(t,s0+1.95,s0+2.3));$('gToast').style.opacity=cl(p(t,s0+1.95,s0+2.1))*(1-p(t,s0+3.1,s0+3.3));$('gToast').style.transform='translateX(-50%) translateY('+(1-gtk)*24+'px)';

''')

rep("const mcCard=plCards[10],mcBtn=mcCard.querySelector('.inst');",
    "const mcCard=plCards[10],mcBtn=mcCard.querySelector('.inst');\n"
    "[1,13].forEach(i=>{const b=plCards[i].querySelector('.inst');b.innerHTML='<span class=\"ic\" style=\"font-size:17px\">check</span>Installed';b.style.color='var(--t3)';b.style.borderColor='var(--border)';});")

left = [m.start() for m in re.finditer(r'calc(?!ulat)', s)]
assert not left, [s[i - 30:i + 30] for i in left]
open(p, 'w', encoding='utf-8', newline='').write(s)
print('ok')
