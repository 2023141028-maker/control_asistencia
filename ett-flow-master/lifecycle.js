async function cerrarRelacion(c,tipo,f){
 if(!c)throw new Error("Contrato no encontrado.");
 if(tipo==="RENUNCIA"){
  await insert("renuncias",{contrato_id:c.id,fecha_renuncia:hoy(),motivo:f.motivo,desea_continuar_ett:f.desea_continuar_ett==="1"})
 }else{
  await insert("despidos",{contrato_id:c.id,fecha_despido:hoy(),motivo:f.motivo,procede_sustitucion:f.procede_sustitucion==="1",desea_continuar_ett:f.desea_continuar_ett==="1"})
 }
 await update("contratos",c.id,{estado:"FINALIZADO",fecha_fin:hoy()});
 let s=D.ss.find(x=>x.cliente_id===c.cliente_id);
 if(s)await update("seguridad_social",s.id,{dado_de_alta:false,fecha_alta:null,observaciones:"Baja tras "+tipo.toLowerCase()});
 if(tipo==="DESPIDO"&&f.procede_sustitucion==="1"&&c.oferta_id){
  let o=ofe(c.oferta_id);
  if(o)await update("ofertas",o.id,{vacantes:(o.vacantes||0)+1,estado:"ABIERTA"})
 }
 let sigue=f.desea_continuar_ett==="1";
 await update("clientes",c.cliente_id,{estado:sigue?"DISPONIBLE":"BAJA"});
 await event(tipo,tipo+" registrada. Contrato finalizado. "+(sigue?"Cliente disponible para nuevas ofertas.":"Cliente dado de baja."),c.cliente_id,c.caso_id);
 await load()
}
async function reactivar(cid){
 await update("clientes",cid,{estado:"DISPONIBLE"});
 await event("Reactivación","Cliente reactivado y devuelto a la bolsa de trabajo",cid);
 await load();await autoOferta(cid);await load()
}
function bajas(v){
 let activos=D.contratos.filter(c=>c.estado==="ACTIVO");
 v.innerHTML='<h1>Renuncia / Despido / Reactivación</h1><div class="lead">Finaliza la relación laboral, actualiza Seguridad Social y determina si el cliente continúa en la ETT.</div>'+
 '<h2>Registrar renuncia</h2><form id="fren" class="panel grid"><div><label>Contrato activo *</label><select name="contrato_id" required><option value="">Seleccione…</option>'+activos.map(c=>'<option value="'+c.id+'">'+esc(nom(cli(c.cliente_id)))+' · '+esc(ofe(c.oferta_id)?.puesto||c.tipo_contrato)+'</option>').join("")+'</select></div><div class="full"><label>Motivo *</label><input name="motivo" required></div><div><label>¿Desea continuar en la ETT? *</label><select name="desea_continuar_ett"><option value="1">Sí</option><option value="0">No</option></select></div><div><button class="btn warn">Registrar renuncia</button></div></form>'+
 '<h2>Registrar despido</h2><form id="fdes" class="panel grid"><div><label>Contrato activo *</label><select name="contrato_id" required><option value="">Seleccione…</option>'+activos.map(c=>'<option value="'+c.id+'">'+esc(nom(cli(c.cliente_id)))+' · '+esc(ofe(c.oferta_id)?.puesto||c.tipo_contrato)+'</option>').join("")+'</select></div><div class="full"><label>Motivo *</label><input name="motivo" required></div><div><label>¿Procede sustitución?</label><select name="procede_sustitucion"><option value="0">No</option><option value="1">Sí, reabrir vacante</option></select></div><div><label>¿Desea continuar en la ETT?</label><select name="desea_continuar_ett"><option value="1">Sí</option><option value="0">No</option></select></div><div><button class="btn bad">Registrar despido</button></div></form>'+
 '<h2>Clientes de baja</h2>'+tbl(["Cliente","DNI","Acción"],D.clientes.filter(c=>c.estado==="BAJA").map(c=>[esc(nom(c)),esc(c.dni),'<button class="btn good" data-react="'+c.id+'">Reactivar en ETT</button>']))+
 '<h2>Historial de renuncias</h2>'+tbl(["Fecha","Cliente","Motivo","Continúa ETT"],D.renuncias.map(r=>{let c=cont(r.contrato_id);return [esc(r.fecha_renuncia),esc(nom(cli(c?.cliente_id))),esc(r.motivo),r.desea_continuar_ett?"Sí":"No"]}))+
 '<h2>Historial de despidos</h2>'+tbl(["Fecha","Cliente","Motivo","Sustitución","Continúa ETT"],D.despidos.map(d=>{let c=cont(d.contrato_id);return [esc(d.fecha_despido),esc(nom(cli(c?.cliente_id))),esc(d.motivo),d.procede_sustitucion?"Sí":"No",d.desea_continuar_ett?"Sí":"No"]}));
 fren.onsubmit=async e=>{e.preventDefault();try{let f=Object.fromEntries(new FormData(e.target));await cerrarRelacion(cont(f.contrato_id),"RENUNCIA",f)}catch(x){fail(x)}};
 fdes.onsubmit=async e=>{e.preventDefault();try{let f=Object.fromEntries(new FormData(e.target));await cerrarRelacion(cont(f.contrato_id),"DESPIDO",f)}catch(x){fail(x)}};
 document.querySelectorAll("[data-react]").forEach(b=>b.onclick=async()=>{try{await reactivar(b.dataset.react)}catch(x){fail(x)}})
}