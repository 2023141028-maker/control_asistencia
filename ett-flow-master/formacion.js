async function finalizarCurso(id){
 let i=D.inscripciones.find(x=>x.id===id);if(!i||i.finalizado)return;
 let c=curso(i.curso_id);
 await update("inscripciones_curso",id,{finalizado:true});
 let existe=D.titulos.some(t=>t.cliente_id===i.cliente_id&&t.tipo==="CURSO"&&t.titulo===c?.titulo);
 if(!existe)await insert("titulos_adicionales",{cliente_id:i.cliente_id,tipo:"CURSO",titulo:c?.titulo||"Curso ETT",institucion:"ETT",fecha_obtencion:hoy()});
 await event("Formación","Curso finalizado: "+(c?.titulo||"")+"; incorporado al CV",i.cliente_id);
 await load()
}
function formacion(v){
 v.innerHTML='<h1>Formación / Cursos</h1><div class="lead">Los cursos finalizados se incorporan automáticamente a la información curricular del cliente.</div>'+
 '<form id="fcurso" class="panel grid"><div><label>Código *</label><input name="codigo" required></div><div><label>Título *</label><input name="titulo" required></div><div><label>Materia</label><input name="materia"></div><div><label>Horas *</label><input type="number" min="1" name="horas" required></div><div><label>Financiación *</label><select name="tipo_financiacion" required><option>ETT</option><option>EMPRESA</option><option>CLIENTE</option></select></div><div><button class="btn">Crear curso</button></div></form>'+
 '<h2>Inscribir cliente</h2><form id="fins" class="panel grid"><div><label>Cliente *</label><select name="cliente_id" required><option value="">Seleccione…</option>'+D.clientes.filter(c=>c.estado!=="BAJA").map(c=>'<option value="'+c.id+'">'+esc(nom(c))+'</option>').join("")+'</select></div><div><label>Curso *</label><select name="curso_id" required><option value="">Seleccione…</option>'+D.cursos.map(c=>'<option value="'+c.id+'">'+esc(c.titulo)+'</option>').join("")+'</select></div><div><button class="btn">Inscribir</button></div></form>'+
 '<h2>Inscripciones</h2>'+tbl(["Cliente","Curso","Fecha","Estado","Acción"],D.inscripciones.map(i=>[esc(nom(cli(i.cliente_id))),esc(curso(i.curso_id)?.titulo||"—"),esc(i.fecha_inscripcion),i.finalizado?badge("COMPLETADO"):badge("PENDIENTE"),!i.finalizado?'<button class="btn good" data-endcourse="'+i.id+'">Marcar finalizado</button>':"En CV"]))+
 '<h2>Cursos disponibles</h2>'+tbl(["Código","Título","Materia","Horas","Financiación"],D.cursos.map(c=>[esc(c.codigo),esc(c.titulo),esc(c.materia||"—"),c.horas,esc(c.tipo_financiacion)]));
 fcurso.onsubmit=async e=>{e.preventDefault();try{
  let f=Object.fromEntries(new FormData(e.target));f.horas=+f.horas;
  await insert("cursos",f);await event("Formación","Curso creado: "+f.titulo);await load()
 }catch(x){fail(x)}};
 fins.onsubmit=async e=>{e.preventDefault();try{
  let f=Object.fromEntries(new FormData(e.target));
  if(D.inscripciones.some(i=>i.cliente_id===f.cliente_id&&i.curso_id===f.curso_id&&!i.finalizado))throw new Error("El cliente ya está inscrito en ese curso.");
  await insert("inscripciones_curso",f);await event("Formación","Cliente inscrito en curso: "+(curso(f.curso_id)?.titulo||""),f.cliente_id);await load()
 }catch(x){fail(x)}};
 document.querySelectorAll("[data-endcourse]").forEach(b=>b.onclick=async()=>{try{await finalizarCurso(b.dataset.endcourse)}catch(x){fail(x)}})
}