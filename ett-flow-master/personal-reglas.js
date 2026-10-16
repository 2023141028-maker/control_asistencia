function personal(v){
 let activos=D.personal.filter(p=>p.estado==="ACTIVO").length;
 v.innerHTML='<h1>Personal ETT</h1><div class="lead">La ETT debe contar con un mínimo de 4 personas registradas.</div><div class="msg '+(activos>=4?"ok":"err")+'"><b>Personal activo: '+activos+'</b> · '+(activos>=4?"Cumple el mínimo requerido.":"Faltan "+(4-activos)+" persona(s) para cumplir el mínimo.")+'</div><form id="fp" class="panel grid"><div><label>DNI *</label><input name="dni" maxlength="8" required></div><div><label>Nombres *</label><input name="nombres" required></div><div><label>Apellidos *</label><input name="apellidos" required></div><div><label>Cargo *</label><input name="cargo" required></div><div><label>Teléfono</label><input name="telefono"></div><div><label>Correo</label><input type="email" name="correo"></div><div><button class="btn">Registrar personal</button></div></form><h2>Personal registrado</h2>'+tbl(["DNI","Nombre","Cargo","Estado"],D.personal.map(p=>[esc(p.dni),esc(nom(p)),esc(p.cargo),badge(p.estado)]));
 fp.onsubmit=async e=>{e.preventDefault();try{
  let f=Object.fromEntries(new FormData(e.target));
  if(!/^\d{8}$/.test(f.dni))throw new Error("El DNI debe tener 8 dígitos.");
  await insert("personal_ett",f);
  await event("Personal ETT","Personal registrado: "+f.nombres+" "+f.apellidos);
  await load()
 }catch(x){fail(x)}}
}
function reglas(v){
 let rs=[
 ["Admisión","DNI + currículum + fotografía. Si falta alguno, solicitud rechazada. Si está completo, cliente admitido."],
 ["Clasificación","Universitario = Nivel 1; Formación Profesional/Nivel Medio = Nivel 2; Estudios Básicos/Sin estudios = Nivel 3."],
 ["Oferta compatible","Oferta abierta, con vacantes y nivel compatible. Si no existe, cliente en espera."],
 ["Interés","No interesado: se descarta esa oferta y se busca otra compatible. Sí: entrevista ETT."],
 ["Entrevistas","ETT APTO pasa a empresa. Con acuerdo de empresa se reserva/reduce vacante y continúa contratación."],
 ["Trabajo activo","Si el cliente ya tiene contrato activo, no puede celebrar otro hasta finalizarlo."],
 ["Seguridad Social","Si está de alta, registrar contrato. Si no, alta automática y luego contrato."],
 ["Contratos","Fin de obra, superior a una semana e inferior a una semana. Solo uno activo por cliente."],
 ["Nómina","Control por viernes. Penalización del 5% por semana completa de retraso. Contrato menor a una semana: sin penalización."],
 ["Honorarios","Al pagar nómina se calcula automáticamente el porcentaje de honorarios de la ETT."],
 ["Renuncia","Finaliza contrato y baja en Seguridad Social. Si sigue en ETT queda disponible; si no, baja."],
 ["Despido","Finaliza contrato. Si procede sustitución se reabre una vacante. El cliente puede continuar o salir de la ETT."],
 ["Advertencias","Tres advertencias provocan baja inmediata y finalización de contratos activos."],
 ["Reactivación","Cliente de baja puede reactivarse y volver a la bolsa; se busca una oferta compatible."],
 ["Formación","Cliente puede inscribirse en cursos; al finalizarlos se incorporan a su información curricular."],
 ["Personal ETT","Mínimo 4 personas activas registradas."]
 ];
 v.innerHTML='<h1>Reglas del sistema</h1><div class="lead">Correspondencia entre el diagrama y el comportamiento de la aplicación.</div><div class="panel">'+rs.map(r=>'<div class="rule"><b>'+esc(r[0])+'</b><div>'+esc(r[1])+'</div></div>').join("")+'</div>'
}