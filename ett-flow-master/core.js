const URL="https://c--70c1df90-79f8-47db-b610-cfa9fd320ff9-prod.lovable.cloud";
const KEY="sb_publishable_lxgurL9wq10yQrsGdZgWyw_gn60AvUc";
const H={"apikey":KEY,"Content-Type":"application/json"};
const tabs=[
["home","Inicio"],["empresas","Empresas"],["ofertas","Ofertas"],["clientes","Clientes y CV"],
["casos","Casos / Proceso ETT"],["entrevistas","Entrevistas"],["ss","Seguridad Social"],
["contratos","Contratos"],["nominas","Nóminas"],["honorarios","Honorarios ETT"],
["advertencias","Advertencias"],["formacion","Formación / Cursos"],["bajas","Renuncia / Despido / Reactivación"],
["personal","Personal ETT"],["reglas","Reglas del sistema"]];
let tab="home",selCaso=null;
let D={empresas:[],ofertas:[],clientes:[],casos:[],postulaciones:[],entrevistas:[],ss:[],contratos:[],eventos:[],nominas:[],honorarios:[],advertencias:[],cursos:[],inscripciones:[],renuncias:[],despidos:[],titulos:[],personal:[],rechazadas:[]};

const esc=v=>String(v??"").replace(/[&<>"']/g,m=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"}[m]));
const hoy=()=>new Date().toISOString().slice(0,10);
const nom=c=>c?((c.nombres||"")+" "+(c.apellidos||"")).trim():"";
const nivel=n=>({1:"Nivel 1 · Universitario",2:"Nivel 2 · FP / Medio",3:"Nivel 3 · Básico / Sin estudios"})[n]||"";
const nivelEst=e=>e==="UNIVERSITARIO"?1:(e==="FORMACION PROFESIONAL"||e==="NIVEL MEDIO"?2:3);
const emp=id=>D.empresas.find(x=>x.id===id), ofe=id=>D.ofertas.find(x=>x.id===id), cli=id=>D.clientes.find(x=>x.id===id);
const cont=id=>D.contratos.find(x=>x.id===id), curso=id=>D.cursos.find(x=>x.id===id);
const fmt=d=>d?new Date(d).toLocaleString("es-PE"):"—";

function badge(x){
 x=String(x||"");
 let c=/ACTIV|TRABAJ|ALTA|APTO|ACUERDO|FINALIZADO|CONTRATADO|ABIERTA|COMPLETADO|PAGADA/.test(x)?"g":/BAJA|CERRAD|RECHAZ|NO APTO|SIN ACUERDO|DESPEDIDO|RENUNCIA/.test(x)?"r":/ESPERA|PENDIENTE|PROCESO|RESERVA|SIN ALTA|SIN REGISTRO/.test(x)?"y":"b";
 return '<span class="badge '+c+'">'+esc(x)+'</span>'
}
async function req(path,opt={}){
 const r=await fetch(URL+path,{...opt,headers:{...H,...(opt.headers||{})}});
 const t=await r.text();let d=null;try{d=t?JSON.parse(t):null}catch{d=t}
 if(!r.ok)throw new Error(d?.message||("Error "+r.status));return d
}
async function list(t){return await req("/rest/v1/"+t+"?select=*&order=created_at.desc")}
async function insert(t,d,ret=false){
 let r=await req("/rest/v1/"+t,{method:"POST",headers:{"Prefer":ret?"return=representation":"return=minimal"},body:JSON.stringify(d)});
 return ret&&Array.isArray(r)?r[0]:r
}
async function update(t,id,d){return req("/rest/v1/"+t+"?id=eq."+encodeURIComponent(id),{method:"PATCH",headers:{"Prefer":"return=minimal"},body:JSON.stringify(d)})}
async function delWhere(t,field,val){return req("/rest/v1/"+t+"?"+field+"=eq."+encodeURIComponent(val),{method:"DELETE",headers:{"Prefer":"return=minimal"}})}
async function event(mod,msg,cid=null,caseid=null){return insert("eventos",{modulo:mod,mensaje:msg,cliente_id:cid,caso_id:caseid})}
async function upload(file,folder){
 const p=folder+"/"+crypto.randomUUID()+"-"+file.name.replace(/[^\w.-]/g,"_");
 const r=await fetch(URL+"/storage/v1/object/documentos/"+encodeURI(p),{method:"POST",headers:{"apikey":KEY,"Content-Type":file.type||"application/octet-stream","x-upsert":"false"},body:file});
 if(!r.ok){let j={};try{j=await r.json()}catch{}throw new Error(j.message||"No se pudo subir el archivo")}return p
}
function say(m,type="ok"){
 const n=document.createElement("div");n.className="msg "+type;n.textContent=m;document.querySelector("main")?.prepend(n);setTimeout(()=>n.remove(),5000)
}
function fail(e){console.error(e);say(e.message||String(e),"err")}
function tbl(h,rows){
 return '<div style="overflow:auto"><table><thead><tr>'+h.map(x=>"<th>"+x+"</th>").join("")+'</tr></thead><tbody>'+(rows.length?rows.map(r=>"<tr>"+r.map(c=>"<td>"+c+"</td>").join("")+"</tr>").join(""):'<tr><td colspan="'+h.length+'" class="small">Sin registros.</td></tr>')+'</tbody></table></div>'
}
function timeline(xs){
 xs=xs.slice().sort((a,b)=>String(b.fecha).localeCompare(String(a.fecha)));
 return '<div class="panel timeline">'+(xs.length?xs.map(e=>'<div class="ev"><b>'+esc(e.modulo)+'</b><div>'+esc(e.mensaje)+'</div><small>'+fmt(e.fecha)+'</small></div>').join(""):'<div class="small">Sin eventos todavía.</div>')+'</div>'
}
async function load(){
 try{
  const n=["empresas","ofertas","clientes","casos","postulaciones","entrevistas","seguridad_social","contratos","eventos","nominas","honorarios","advertencias","cursos","inscripciones_curso","renuncias","despidos","titulos_adicionales","personal_ett","solicitudes_rechazadas"];
  const v=await Promise.all(n.map(list));
  D={empresas:v[0],ofertas:v[1],clientes:v[2],casos:v[3],postulaciones:v[4],entrevistas:v[5],ss:v[6],contratos:v[7],eventos:v[8],nominas:v[9],honorarios:v[10],advertencias:v[11],cursos:v[12],inscripciones:v[13],renuncias:v[14],despidos:v[15],titulos:v[16],personal:v[17],rechazadas:v[18]};
  render()
 }catch(e){
  document.getElementById("root").innerHTML='<div style="padding:30px"><h1>Gestión ETT</h1><div class="msg err">'+esc(e.message)+'</div><button class="btn" onclick="location.reload()">Reintentar</button></div>'
 }
}
function shell(){
 document.getElementById("root").innerHTML='<div class="app"><aside><div class="brand">Gestión ETT</div><div class="sub">Sistema integral según el proceso ETT</div><nav>'+tabs.map(t=>'<button data-tab="'+t[0]+'" class="'+(tab===t[0]?"on":"")+'">'+t[1]+'</button>').join("")+'</nav></aside><main id="view"></main></div>';
 document.querySelectorAll("[data-tab]").forEach(b=>b.onclick=()=>{tab=b.dataset.tab;shell();section()})
}
function render(){shell();section()}
function section(){
 const v=document.getElementById("view");
 const map={home,empresas,ofertas,clientes,casos,entrevistas,ss,contratos,nominas,honorarios,advertencias,formacion,bajas,personal,reglas};
 (map[tab]||home)(v)
}
function home(v){
 let m=[
 ["Clientes disponibles",D.clientes.filter(x=>x.estado==="DISPONIBLE").length],
 ["Trabajando",D.clientes.filter(x=>x.estado==="TRABAJANDO").length],
 ["Ofertas abiertas",D.ofertas.filter(x=>x.estado==="ABIERTA").length],
 ["Contratos activos",D.contratos.filter(x=>x.estado==="ACTIVO").length],
 ["Entrevistas pendientes",D.entrevistas.filter(x=>x.resultado==="PENDIENTE").length],
 ["Clientes de baja",D.clientes.filter(x=>x.estado==="BAJA").length],
 ["Cursos",D.cursos.length],["Personal ETT",D.personal.filter(x=>x.estado==="ACTIVO").length]];
 v.innerHTML='<h1>Sistema de Gestión ETT</h1><div class="lead">Todas las decisiones del proceso quedan registradas en el historial.</div><div class="grid cards">'+m.map(x=>'<div class="card"><div class="metric">'+x[1]+'</div><div class="small">'+x[0]+'</div></div>').join("")+'</div><h2>Últimas decisiones</h2>'+timeline(D.eventos.slice(0,15))
}