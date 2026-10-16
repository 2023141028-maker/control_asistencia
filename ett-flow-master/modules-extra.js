function viernesValido(f){return new Date(f+"T12:00:00").getDay()===5}
async function registrarNomina(f){
 let c=cont(f.contrato_id);if(!c)throw new Error("Contrato no encontrado.");
 if(D.nominas.some(n=>n.contrato_id===c.id&&n.fecha_viernes===f.fecha_viernes))throw new Error("Ya existe una nómina para ese contrato y viernes.");
 if(!viernesValido(f.fecha_viernes))throw new Error("La fecha de nómina debe ser viernes.");
 let firmada=!!f.fecha_firma,weeks=0,pen=0,importe=0;
 if(firmada){
  let dias=Math.max(0,Math.floor((new Date(f.fecha_firma+"T12:00:00")-new Date(f.fecha_viernes+"T12:00:00"))/86400000));
  weeks=Math.floor(dias/7);
  pen=c.tipo_contrato==="INFERIOR A 1 SEMANA"?0:Math.min(+c.salario,+c.salario*0.05*weeks);
  importe=Math.max(0,+c.salario-pen)
 }
 let n=await insert("nominas",{contrato_id:c.id,fecha_viernes:f.fecha_viernes,fecha_firma:f.fecha_firma||null,firmada,pagada:firmada,semanas_retraso:weeks,penalizacion:+pen.toFixed(2),importe_pagado:+importe.toFixed(2)},true);
 await event("Nómina",c.tipo_contrato==="INFERIOR A 1 SEMANA"?"Contrato menor a una semana: sin penalización. Nómina registrada.":"Nómina de viernes registrada. Retraso "+weeks+" semana(s). Penalización "+pen.toFixed(2),c.cliente_id,c.caso_id);
 if(firmada){
  let pct=+c.porcentaje_honorario,imp=+(importe*pct/100).toFixed(2);
  await insert("honorarios",{nomina_id:n.id,porcentaje:pct,importe_honorario:imp});
  await event("Honorarios","Honorario ETT calculado automáticamente: "+pct+"% = "+imp.toFixed(2),c.cliente_id,c.caso_id)
 }
 await load()
}
function nominas(v){
 v.innerHTML='<h1>Nóminas</h1><div class="lead">La nómina se controla los viernes. Cada semana completa de retraso aplica 5% de penalización, excepto contratos inferiores a una semana.</div><form id="fn" class="panel grid"><div><label>Contrato activo *</label><select name="contrato_id" required><option value="">Seleccione…</option>'+D.contratos.filter(c=>c.estado==="ACTIVO").map(c=>'<option value="'+c.id+'">'+esc(nom(cli(c.cliente_id)))+' · '+esc(c.tipo_contrato)+'</option>').join("")+'</select></div><div><label>Viernes de nómina *</label><input type="date" name="fecha_viernes" required></div><div><label>Fecha de firma</label><input type="date" name="fecha_firma"></div><div><button class="btn">Calcular y registrar</button></div></form><h2>Nóminas registradas</h2>'+tbl(["Cliente","Viernes","Firma","Retraso","Penalización","Importe","Estado"],D.nominas.map(n=>{let c=cont(n.contrato_id);return [esc(nom(cli(c?.cliente_id))),esc(n.fecha_viernes),esc(n.fecha_firma||"—"),n.semanas_retraso+" sem.",Number(n.penalizacion).toFixed(2),Number(n.importe_pagado).toFixed(2),n.pagada?badge("PAGADA"):badge("PENDIENTE")]}));
 fn.onsubmit=async e=>{e.preventDefault();try{await registrarNomina(Object.fromEntries(new FormData(e.target)))}catch(x){fail(x)}}
}
function honorarios(v){
 v.innerHTML='<h1>Honorarios ETT</h1><div class="lead">Se calculan automáticamente cuando una nómina queda firmada y pagada.</div>'+tbl(["Fecha","Cliente","Empresa","Porcentaje","Importe"],D.honorarios.map(h=>{let n=D.nominas.find(x=>x.id===h.nomina_id),c=cont(n?.contrato_id);return [esc(h.fecha_registro),esc(nom(cli(c?.cliente_id))),esc(emp(c?.empresa_id)?.nombre||"—"),Number(h.porcentaje).toFixed(2)+"%",Number(h.importe_honorario).toFixed(2)]}))
}