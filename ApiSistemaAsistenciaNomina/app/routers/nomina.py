"""Modulo de Nomina.

Calculo (opcion 2a del diseno):

    total a pagar = dias trabajados x salario diario

Cuentan como dia trabajado los registros con estado "presente" y "retardo"
(el empleado si laboro, aunque haya llegado tarde). Los dias con estado
"falta" no se pagan.

La nomina NO se almacena: se calcula al momento a partir de los registros de
asistencia. Asi, si se corrige una asistencia, la nomina refleja el cambio de
inmediato y no existe el riesgo de tener dos versiones distintas del mismo dato.
"""
from datetime import date as Date, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.deps import get_db, get_current_user
from app.models import Usuario, Empleado, Asistencia
from app.schemas import NominaResumen, NominaDetalle

router = APIRouter(prefix="/nomina", tags=["Nomina"])

# Estados que se pagan.
ESTADOS_PAGADOS = ("presente", "retardo")


@router.get("", response_model=NominaResumen)
def calcular(
    inicio: Optional[Date] = Query(None, description="Inicio del periodo (YYYY-MM-DD)"),
    fin: Optional[Date] = Query(None, description="Fin del periodo (YYYY-MM-DD)"),
    solo_activos: bool = Query(True, description="Excluir empleados dados de baja"),
    db: Session = Depends(get_db),
    _: Usuario = Depends(get_current_user),
):
    # Periodo por defecto: los ultimos 15 dias (quincena).
    if fin is None:
        fin = Date.today()
    if inicio is None:
        inicio = fin - timedelta(days=14)

    consulta = db.query(Empleado)
    if solo_activos:
        consulta = consulta.filter(Empleado.activo == 1)
    empleados = consulta.order_by(Empleado.nombre).all()

    detalle = []
    total_nomina = 0.0
    total_dias = 0

    for emp in empleados:
        registros = (
            db.query(Asistencia)
            .filter(
                Asistencia.empleado_id == emp.id,
                Asistencia.fecha >= inicio,
                Asistencia.fecha <= fin,
            )
            .all()
        )

        dias_presente = sum(1 for r in registros if r.estado == "presente")
        dias_retardo = sum(1 for r in registros if r.estado == "retardo")
        dias_falta = sum(1 for r in registros if r.estado == "falta")

        dias_pagados = dias_presente + dias_retardo
        total_empleado = round(dias_pagados * (emp.salario_diario or 0), 2)

        total_nomina += total_empleado
        total_dias += dias_pagados

        detalle.append(
            NominaDetalle(
                empleado_id=emp.id,
                empleado_nombre=emp.nombre,
                puesto=emp.puesto,
                departamento=emp.departamento,
                salario_diario=emp.salario_diario,
                dias_trabajados=dias_pagados,
                dias_retardo=dias_retardo,
                dias_falta=dias_falta,
                total_pagar=total_empleado,
            )
        )

    return NominaResumen(
        periodo_inicio=inicio,
        periodo_fin=fin,
        total_empleados=len(detalle),
        total_dias_pagados=total_dias,
        total_nomina=round(total_nomina, 2),
        detalle=detalle,
    )
