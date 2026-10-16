function empresas(v){
 v.innerHTML='<h1>Empresas</h1><div class="lead">Registro de empresas que solicitan trabajadores.</div><form id="fe" class="panel grid"><div><label>RUC *</label><input name="ruc" maxlength="11" required></div><div><label>Razón social *</label><input name="nombre" required></div><div><label>Actividad</label><input name="actividad"></div><div><label>Domicilio</label><input name="domicilio"></div><div><label>Teléfono</label><input name="telefono"></div><div><label>Correo</label><input type="email" name="correo"></div><div class="full"><button class="btn">Registrar empresa</button></div></form><h2>Empresas registradas</h2>'+tbl(["RUC","Nombre","Actividad","Estado"],D.empresas.map(e=>[esc(e.ruc),esc(e.nombre),esc(e.actividad||"—"),badge(e.estado)]));
 fe.onsubmit=async e=>{e.preventDefault();try{let f=Object.fromEntries(new FormData(e.target));if(!/^\d{11}$/.test(f.ruc))throw new Error("El RUC debe tener 11 dígitos.");await insert("empresas",f);await event("Empresas","Empresa registrada: "+f.nombre);await load()}catch(x){fail(x)}}
}

function ofertas(v){
 v.innerHTML='<h1>Ofertas</h1><div class="lead">Las vacantes se reservan cuando existe acuerdo con la empresa.</div><form id="fo" class="panel grid"><div><label>Empresa *</label><select name="empresa_id" required><option value="">Seleccione…</option>'+D.empresas.filter(e=>e.estado==="ACTIVA").map(e=>'<option value="'+e.id+'">'+esc(e.nombre)+'</option>').join("")+'</select></div><div><label>Puesto *</label><input name="puesto" required></div><div><label>Nivel requerido *</label><select name="nivel_requerido" required><option value="">Seleccione…</option><option value="1">Nivel 1</option><option value="2">Nivel 2</option><option value="3">Nivel 3</option></select></div><div><label>Vacantes *</label><input type="number" min="1" value="1" name="vacantes" required></div><div><label>Fecha</label><input type="date" name="fecha" value="'+hoy()+'"></div><div class="full"><label>Descripción</label><textarea name="descripcion"></textarea></div><div class="full"><button class="btn">Publicar oferta</button></div></form><h2>Ofertas</h2>'+tbl(["Puesto","Empresa","Nivel","Vacantes","Estado"],D.ofertas.map(o=>[esc(o.puesto),esc(emp(o.empresa_id)?.nombre||"—"),nivel(o.nivel_requerido),o.vacantes,badge(o.estado)]));
 fo.onsubmit=async e=>{e.preventDefault();try{let f=Object.fromEntries(new FormData(e.target));f.nivel_requerido=+f.nivel_requerido;f.vacantes=+f.vacantes;await insert("ofertas",f);await event("Ofertas",'Oferta publicada: "'+f.puesto+'"');await load()}catch(x){fail(x)}}
}

async function autoOferta(cid){
 let c=cli(cid);if(!c)return;
 let activo=D.casos.find(x=>x.cliente_id===cid&&x.estado==="EN CURSO");
 if(activo){say("El cliente ya tiene un caso en curso.","err");return}
 let intentadas=new Set(D.postulaciones.filter(p=>p.cliente_id===cid).map(p=>p.oferta_id));
 let os=D.ofertas.filter(o=>o.estado==="ABIERTA"&&o.vacantes>0&&c.nivel<=o.nivel_requerido&&!intentadas.has(o.id));
 let espera=D.casos.find(x=>x.cliente_id===cid&&x.estado==="EN ESPERA");
 if(!os.length){
  let ca=espera||await insert("casos",{cliente_id:cid,etapa:"SIN OFERTA COMPATIBLE",estado:"EN ESPERA"},true);
  if(!espera)await event("Búsqueda","No existe oferta compatible → cliente queda DISPONIBLE / EN ESPERA",cid,ca.id);
  await update("clientes",cid,{estado:"DISPONIBLE"});return
 }
 os.sort((a,b)=>String(a.fecha).localeCompare(String(b.fecha)));
 let o=os[0],ca;
 if(espera){await update("casos",espera.id,{oferta_id:o.id,etapa:"DECIDIR INTERÉS",estado:"EN CURSO",updated_at:new Date().toISOString()});ca=espera}
 else ca=await insert("casos",{cliente_id:cid,oferta_id:o.id,etapa:"DECIDIR INTERÉS",estado:"EN CURSO"},true);
 await update("clientes",cid,{estado:"EN PROCESO"});
 await event("Búsqueda",'Oferta compatible encontrada: "'+o.puesto+'" → decidir interés',cid,ca.id)
}

function clientes(v){
 v.innerHTML='<h1>Clientes y CV</h1><div class="lead">La admisión valida DNI, currículum y fotografía. Si falta alguno, se registra el rechazo.</div>'+
 '<form id="fc" class="panel grid"><div><label>DNI *</label><input name="dni" maxlength="8"></div><div><label>Nombres *</label><input name="nombres" required></div><div><label>Apellidos *</label><input name="apellidos" required></div><div><label>Nivel de estudios *</label><select name="nivel_estudios" required><option value="">Seleccione…</option><option>UNIVERSITARIO</option><option>FORMACION PROFESIONAL</option><option>NIVEL MEDIO</option><option>ESTUDIOS BASICOS</option><option>SIN ESTUDIOS</option></select></div><div><label>Dirección</label><input name="direccion"></div><div><label>Teléfono</label><input name="telefono"></div><div><label>Correo</label><input type="email" name="correo"></div><div><label>Currículum *</label><input type="file" name="cv"></div><div><label>Fotografía *</label><input type="file" name="foto" accept="image/*"></div><div class="full"><label>Experiencia laboral</label><textarea name="experiencia_laboral"></textarea></div><div class="full"><button class="btn">Solicitar admisión</button></div></form>'+
 '<h2>Clientes admitidos</h2>'+tbl(["DNI","Cliente","Nivel","Estado","Acción"],D.clientes.map(c=>[esc(c.dni),esc(nom(c)),nivel(c.nivel),badge(c.estado),c.estado==="DISPONIBLE"?'<button class="btn alt" data-search="'+c.id+'">Buscar oferta</button>':"—"]))+
 '<h2>Títulos adicionales / información para CV</h2><form id="ftit" class="panel grid"><div><label>Cliente *</label><select name="cliente_id" required><option value="">Seleccione…</option>'+D.clientes.map(c=>'<option value="'+c.id+'">'+esc(nom(c))+'</option>').join("")+'</select></div><div><label>Tipo *</label><select name="tipo" required><option>TÍTULO</option><option>CERTIFICADO</option><option>CURSO</option></select></div><div><label>Título *</label><input name="titulo" required></div><div><label>Institución</label><input name="institucion"></div><div><label>Fecha obtención</label><input type="date" name="fecha_obtencion"></div><div><button class="btn">Agregar al CV</button></div></form>'+
 tbl(["Cliente","Tipo","Título","Institución","Fecha"],D.titulos.map(t=>[esc(nom(cli(t.cliente_id))),esc(t.tipo),esc(t.titulo),esc(t.institucion||"—"),esc(t.fecha_obtencion||"—")]))+
 '<h2>Solicitudes rechazadas</h2>'+tbl(["Fecha","DNI","Solicitante","Motivo"],D.rechazadas.map(r=>[fmt(r.fecha),esc(r.dni||"—"),esc((r.nombres||"")+" "+(r.apellidos||"")),esc(r.motivo)]));
 fc.onsubmit=async e=>{e.preventDefault();try{
   let fd=new FormData(e.target),dni=String(fd.get("dni")||"").trim(),cv=fd.get("cv"),foto=fd.get("foto");
   let faltan=[];if(!/^\d{8}$/.test(dni))faltan.push("DNI válido de 8 dígitos");if(!(cv instanceof File)||!cv.size)faltan.push("currículum");if(!(foto instanceof File)||!foto.size)faltan.push("fotografía");
   if(faltan.length){
    await insert("solicitudes_rechazadas",{dni:dni||null,nombres:fd.get("nombres"),apellidos:fd.get("apellidos"),motivo:"Falta: "+faltan.join(", ")});
    await event("Admisión","Solicitud rechazada por documentación incompleta");await load();say("Solicitud rechazada: "+faltan.join(", "),"err");return
   }
   let est=String(fd.get("nivel_estudios")),paths=await Promise.all([upload(cv,"curriculum"),upload(foto,"fotos")]);
   let c=await insert("clientes",{dni,nombres:fd.get("nombres"),apellidos:fd.get("apellidos"),nivel_estudios:est,nivel:nivelEst(est),direccion:fd.get("direccion")||null,telefono:fd.get("telefono")||null,correo:fd.get("correo")||null,experiencia_laboral:fd.get("experiencia_laboral")||null,curriculum_url:paths[0],fotografia_url:paths[1],estado:"DISPONIBLE"},true);
   await event("Admisión","Documentación completa → cliente ADMITIDO → "+nivel(c.nivel),c.id);
   await load();await autoOferta(c.id);await load()
 }catch(x){fail(x)}};
 document.querySelectorAll("[data-search]").forEach(b=>b.onclick=async()=>{try{await autoOferta(b.dataset.search);await load()}catch(x){fail(x)}});
 ftit.onsubmit=async e=>{e.preventDefault();try{let f=Object.fromEntries(new FormData(e.target));if(!f.fecha_obtencion)f.fecha_obtencion=null;await insert("titulos_adicionales",f);await event("CV","Título adicional agregado: "+f.titulo,f.cliente_id);await load()}catch(x){fail(x)}}
}

async function interes(ca,yes){
 if(!yes){
  await insert("postulaciones",{cliente_id:ca.cliente_id,oferta_id:ca.oferta_id,caso_id:ca.id,interesado:false,estado:"DESCARTADA"});
  await update("casos",ca.id,{etapa:"CLIENTE NO INTERESADO",estado:"CERRADO",updated_at:new Date().toISOString()});
  await update("clientes",ca.cliente_id,{estado:"DISPONIBLE"});
  await event("Interés","Cliente NO interesado → buscar otra oferta compatible",ca.cliente_id,ca.id);
  await load();await autoOferta(ca.cliente_id);await load()
 }else{
  let p=await insert("postulaciones",{cliente_id:ca.cliente_id,oferta_id:ca.oferta_id,caso_id:ca.id,interesado:true},true);
  await insert("entrevistas",{postulacion_id:p.id,tipo:"ETT"});
  await update("casos",ca.id,{etapa:"ENTREVISTA ETT",updated_at:new Date().toISOString()});
  await event("Interés","Cliente interesado → entrevista ETT creada",ca.cliente_id,ca.id);await load()
 }
}

async function resultado(e,pos,obs){
 let p=D.postulaciones.find(x=>x.id===e.postulacion_id),ca=D.casos.find(x=>x.id===p.caso_id),res=e.tipo==="ETT"?(pos?"APTO":"NO APTO"):(pos?"ACUERDO":"SIN ACUERDO");
 await update("entrevistas",e.id,{resultado:res,observaciones:obs||null});
 if(!pos){
  await update("postulaciones",p.id,{estado:"CERRADA"});
  await update("casos",ca.id,{etapa:e.tipo==="ETT"?"NO APTO EN ENTREVISTA ETT":"SIN ACUERDO CON EMPRESA",estado:"CERRADO",updated_at:new Date().toISOString()});
  await update("clientes",p.cliente_id,{estado:"DISPONIBLE"});
  await event("Entrevista","Resultado "+res+" → cliente vuelve a DISPONIBLE",p.cliente_id,ca.id);
  await load();if(e.tipo==="EMPRESA"){await autoOferta(p.cliente_id);await load()}
 }else if(e.tipo==="ETT"){
  await insert("entrevistas",{postulacion_id:p.id,tipo:"EMPRESA"});
  await update("casos",ca.id,{etapa:"ENTREVISTA EMPRESA",updated_at:new Date().toISOString()});
  await event("Entrevista","Entrevista ETT: APTO → entrevista empresa",p.cliente_id,ca.id);await load()
 }else{
  let o=ofe(ca.oferta_id),vac=Math.max(0,(o?.vacantes||0)-1);
  if(o)await update("ofertas",o.id,{vacantes:vac,estado:vac<=0?"CUBIERTA":"ABIERTA"});
  await update("postulaciones",p.id,{estado:"ACEPTADA"});
  await update("casos",ca.id,{etapa:"REGISTRAR CONTRATO",vacante_reservada:true,updated_at:new Date().toISOString()});
  await update("clientes",p.cliente_id,{estado:"RESERVA"});
  await event("Entrevista","Empresa: ACUERDO → vacante reservada / oferta reducida → comprobar trabajo activo",p.cliente_id,ca.id);await load()
 }
}

async function crearContrato(ca,f){
 let o=ofe(ca.oferta_id),act=D.contratos.filter(x=>x.cliente_id===ca.cliente_id&&x.estado==="ACTIVO");
 if(act.length){await event("Contrato","¿Tiene otro trabajo activo? SÍ → contratación bloqueada / esperar disponibilidad",ca.cliente_id,ca.id);throw new Error("El cliente tiene otro trabajo activo. Debe finalizarlo antes de continuar.")}
 await event("Contrato","¿Tiene otro trabajo activo? NO → consultar Seguridad Social",ca.cliente_id,ca.id);
 let s=D.ss.find(x=>x.cliente_id===ca.cliente_id);
 if(s?.dado_de_alta)await event("Seguridad Social","¿Está dado de alta? SÍ → Registrar contrato",ca.cliente_id,ca.id);
 else if(s){await update("seguridad_social",s.id,{dado_de_alta:true,fecha_alta:hoy(),observaciones:"Alta automática previa a contrato"});await event("Seguridad Social","¿Está dado de alta? NO → alta automática → Registrar contrato",ca.cliente_id,ca.id)}
 else{await insert("seguridad_social",{cliente_id:ca.cliente_id,dado_de_alta:true,fecha_alta:hoy(),observaciones:"Alta automática previa a contrato"});await event("Seguridad Social","Sin registro → alta automática → Registrar contrato",ca.cliente_id,ca.id)}
 await insert("contratos",{cliente_id:ca.cliente_id,empresa_id:o.empresa_id,oferta_id:o.id,caso_id:ca.id,tipo_contrato:f.tipo_contrato,fecha_inicio:f.fecha_inicio,fecha_fin:f.fecha_fin||null,salario:+f.salario,porcentaje_honorario:+f.porcentaje_honorario});
 if(!ca.vacante_reservada){let vac=Math.max(0,o.vacantes-1);await update("ofertas",o.id,{vacantes:vac,estado:vac<=0?"CUBIERTA":"ABIERTA"})}
 await update("clientes",ca.cliente_id,{estado:"TRABAJANDO"});
 let p=D.postulaciones.find(x=>x.caso_id===ca.id);if(p)await update("postulaciones",p.id,{estado:"CONTRATADA"});
 await update("casos",ca.id,{etapa:"CONTRATADO",estado:"FINALIZADO",updated_at:new Date().toISOString()});
 await event("Contrato","Contrato registrado → cliente TRABAJANDO",ca.cliente_id,ca.id);await load()
}

function casos(v){
 if(!selCaso&&D.casos.length)selCaso=D.casos[0].id;let ca=D.casos.find(x=>x.id===selCaso);
 v.innerHTML='<h1>Casos / Proceso ETT</h1><div class="lead">Aquí se ejecutan las compuertas del diagrama y se guarda la trazabilidad.</div><div class="two"><div>'+D.casos.map(c=>'<div class="panel case '+(c.id===selCaso?"sel":"")+'" data-case="'+c.id+'"><b>'+esc(nom(cli(c.cliente_id)))+'</b><div class="small">'+esc(ofe(c.oferta_id)?.puesto||"Sin oferta")+'</div><div>'+badge(c.estado)+' '+badge(c.etapa)+'</div></div>').join("")+'</div><div>'+detalle(ca)+'</div></div>';
 document.querySelectorAll("[data-case]").forEach(b=>b.onclick=()=>{selCaso=b.dataset.case;casos(v)});
 document.querySelectorAll("[data-int]").forEach(b=>b.onclick=async()=>{try{await interes(ca,b.dataset.int==="1")}catch(x){fail(x)}});
 document.querySelectorAll("[data-res]").forEach(b=>b.onclick=async()=>{try{let e=D.entrevistas.find(x=>x.id===b.dataset.res);await resultado(e,b.dataset.ok==="1",document.getElementById("obs")?.value||"")}catch(x){fail(x)}});
 document.querySelectorAll("[data-clear]").forEach(b=>b.onclick=async()=>{try{if(!confirm("¿Limpiar solo el historial de este caso? No se eliminarán los demás datos."))return;await delWhere("eventos","caso_id",b.dataset.clear);await load();say("Historial de este caso eliminado.")}catch(x){fail(x)}});
 let f=document.getElementById("fcontract");if(f)f.onsubmit=async e=>{e.preventDefault();try{await crearContrato(ca,Object.fromEntries(new FormData(e.target)))}catch(x){fail(x)}}
}

function detalle(ca){
 if(!ca)return '<div class="panel">No hay casos.</div>';
 let p=D.postulaciones.find(x=>x.caso_id===ca.id),pe=D.entrevistas.find(x=>x.postulacion_id===p?.id&&x.resultado==="PENDIENTE"),a="";
 if(ca.estado==="EN CURSO"&&ca.etapa==="DECIDIR INTERÉS")a='<div class="panel"><h2>¿Cliente interesado?</h2><div class="actions"><button class="btn good" data-int="1">Sí, interesado</button><button class="btn alt" data-int="0">No</button></div></div>';
 if(ca.estado==="EN CURSO"&&pe)a='<div class="panel"><h2>Resultado entrevista '+esc(pe.tipo)+'</h2><textarea id="obs" placeholder="Observaciones"></textarea><div class="actions" style="margin-top:8px"><button class="btn good" data-res="'+pe.id+'" data-ok="1">'+(pe.tipo==="ETT"?"APTO":"Hay acuerdo")+'</button><button class="btn bad" data-res="'+pe.id+'" data-ok="0">'+(pe.tipo==="ETT"?"NO APTO":"Sin acuerdo")+'</button></div></div>';
 if(ca.estado==="EN CURSO"&&ca.etapa==="REGISTRAR CONTRATO")a='<form id="fcontract" class="panel grid"><div class="full msg"><b>Secuencia automática:</b> ¿Tiene otro trabajo activo? → Seguridad Social → alta si corresponde → contrato.</div><div><label>Tipo *</label><select name="tipo_contrato" required><option value="">Seleccione…</option><option>FIN DE OBRA</option><option>SUPERIOR A 1 SEMANA</option><option>INFERIOR A 1 SEMANA</option></select></div><div><label>Inicio *</label><input type="date" name="fecha_inicio" value="'+hoy()+'" required></div><div><label>Fin</label><input type="date" name="fecha_fin"></div><div><label>Salario *</label><input type="number" step=".01" min="1" name="salario" required></div><div><label>Honorario ETT % *</label><input type="number" step=".01" min="0" max="100" name="porcentaje_honorario" value="10" required></div><div><button class="btn">Verificar y registrar contrato</button></div></form>';
 return '<div class="panel"><h2>'+esc(nom(cli(ca.cliente_id)))+'</h2><div>Estado '+badge(ca.estado)+' · Etapa '+badge(ca.etapa)+'</div><div class="small">Oferta: '+esc(ofe(ca.oferta_id)?.puesto||"Sin oferta")+'</div></div>'+a+'<div class="hist-head"><h2>Historial cronológico</h2><button class="btn bad" data-clear="'+ca.id+'">Limpiar historial de este caso</button></div>'+timeline(D.eventos.filter(e=>e.caso_id===ca.id))
}

function entrevistas(v){
 v.innerHTML='<h1>Entrevistas</h1><div class="lead">Entrevista ETT y entrevista con la empresa.</div>'+tbl(["Fecha","Cliente","Tipo","Resultado","Observaciones"],D.entrevistas.map(e=>{let p=D.postulaciones.find(x=>x.id===e.postulacion_id);return [fmt(e.fecha),esc(nom(cli(p?.cliente_id))),esc(e.tipo),badge(e.resultado),esc(e.observaciones||"—")]}))
}

function ss(v){
 v.innerHTML='<h1>Seguridad Social</h1><div class="lead">Durante la contratación el sistema decide automáticamente si debe dar de alta.</div><div class="msg"><b>Diagrama:</b> DADO DE ALTA → Registrar contrato. SIN ALTA / SIN REGISTRO → Dar de alta → Registrar contrato.</div>'+tbl(["Cliente","Estado","Fecha alta","Control manual"],D.clientes.map(c=>{let s=D.ss.find(x=>x.cliente_id===c.id);return [esc(nom(c)),s?.dado_de_alta?badge("DADO DE ALTA"):badge(s?"SIN ALTA":"SIN REGISTRO"),esc(s?.fecha_alta||"—"),'<button class="btn alt" data-ss="'+c.id+'" data-alta="'+(s?.dado_de_alta?"0":"1")+'">'+(s?.dado_de_alta?"Marcar sin alta":"Dar de alta")+'</button>']}));
 document.querySelectorAll("[data-ss]").forEach(b=>b.onclick=async()=>{try{let cid=b.dataset.ss,alta=b.dataset.alta==="1",s=D.ss.find(x=>x.cliente_id===cid);if(s)await update("seguridad_social",s.id,{dado_de_alta:alta,fecha_alta:alta?hoy():null,observaciones:"Cambio manual para consulta/demostración"});else await insert("seguridad_social",{cliente_id:cid,dado_de_alta:alta,fecha_alta:alta?hoy():null,observaciones:"Cambio manual para consulta/demostración"});await event("Seguridad Social",alta?"Alta manual registrada":"Marcado SIN ALTA",cid);await load()}catch(x){fail(x)}})
}

async function finalizarFinObra(id){
 let c=cont(id);if(!c||c.estado!=="ACTIVO")return;
 await update("contratos",id,{estado:"FINALIZADO",fecha_fin:c.fecha_fin||hoy()});
 await update("clientes",c.cliente_id,{estado:"DISPONIBLE"});
 let s=D.ss.find(x=>x.cliente_id===c.cliente_id);if(s)await update("seguridad_social",s.id,{dado_de_alta:false,fecha_alta:null,observaciones:"Baja por finalización de contrato"});
 await event("Contrato","Fin de obra / fin de contrato → contrato FINALIZADO → cliente DISPONIBLE",c.cliente_id,c.caso_id);await load()
}
function contratos(v){
 v.innerHTML='<h1>Contratos</h1><div class="lead">Solo puede existir un contrato activo por cliente.</div>'+tbl(["Cliente","Empresa","Oferta","Tipo","Inicio","Fin","Salario","Estado","Acción"],D.contratos.map(c=>[esc(nom(cli(c.cliente_id))),esc(emp(c.empresa_id)?.nombre||"—"),esc(ofe(c.oferta_id)?.puesto||"—"),esc(c.tipo_contrato),esc(c.fecha_inicio),esc(c.fecha_fin||"—"),Number(c.salario).toFixed(2),badge(c.estado),c.estado==="ACTIVO"?'<button class="btn alt" data-fin="'+c.id+'">Finalizar contrato</button>':"—"]));
 document.querySelectorAll("[data-fin]").forEach(b=>b.onclick=async()=>{try{if(!confirm("¿Finalizar este contrato y dejar al cliente disponible?"))return;await finalizarFinObra(b.dataset.fin)}catch(x){fail(x)}})
}