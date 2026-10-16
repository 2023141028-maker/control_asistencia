async function terceraAdvertencia(cid){
 let activos=D.contratos.filter(c=>c.cliente_id===cid&&c.estado==="ACTIVO");
 for(let c of activos)await update("contratos",c.id,{estado:"FINALIZADO",fecha_fin:hoy()});
 let s=D.ss.find(x=>x.cliente_id===cid);
 if(s)await update("seguridad_social",s.id,{dado_de_alta:false,fecha_alta:null,observaciones:"Baja por 3 advertencias"});
 let abiertos=D.casos.filter(c=>c.cliente_id===cid&&c.estado==="EN CURSO");
 for(let ca of abiertos){
  if(ca.vacante_reservada&&ca.oferta_id){
   let o=ofe(ca.oferta_id);
   if(o)await update("ofertas",o.id,{vacantes:(o.vacantes||0)+1,estado:"ABIERTA"})
  }
  await update("casos",ca.id,{estado:"CERRADO",etapa:"BAJA POR 3 ADVERTENCIAS",updated_at:new Date().toISOString()})
 }
 await update("clientes",cid,{estado:"BAJA"});
 await event("Advertencia","Regla automática: tres advertencias, cliente dado de baja y contratos finalizados",cid)
}
function advertencias(v){
 v.innerHTML='<h1>Advertencias</h1><div class="lead">Tres advertencias producen la baja inmediata del cliente.</div><form id="fa" class="panel grid"><div><label>Cliente *</label><select name="cliente_id" required><option value="">Seleccione…</option>'+D.clientes.filter(c=>c.estado!=="BAJA").map(c=>'<option value="'+c.id+'">'+esc(nom(c))+'</option>').join("")+'</select></div><div class="full"><label>Motivo *</label><input name="motivo" required></div><div><button class="btn">Registrar advertencia</button></div></form><h2>Estado por cliente</h2>'+tbl(["Cliente","Advertencias","Estado"],D.clientes.map(c=>{let n=D.advertencias.filter(a=>a.cliente_id===c.id).length;return [esc(nom(c)),n+"/3",badge(c.estado)]}))+'<h2>Historial</h2>'+tbl(["Fecha","Cliente","Motivo"],D.advertencias.map(a=>[esc(a.fecha_advertencia),esc(nom(cli(a.cliente_id))),esc(a.motivo)]));
 fa.onsubmit=async e=>{e.preventDefault();try{
  let f=Object.fromEntries(new FormData(e.target));
  await insert("advertencias",{cliente_id:f.cliente_id,fecha_advertencia:hoy(),motivo:f.motivo});
  let n=D.advertencias.filter(a=>a.cliente_id===f.cliente_id).length+1;
  await event("Advertencia","Advertencia registrada ("+n+"/3): "+f.motivo,f.cliente_id);
  if(n>=3)await terceraAdvertencia(f.cliente_id);
  await load()
 }catch(x){fail(x)}}
}