import * as XLSX from 'xlsx';
import type { AttendanceRecord, Worksite, UserData } from '../types';

interface ExportFilters {
  startDate: Date;
  endDate: Date;
  worksiteId: string;
  workerId: string;
}

export const exportAttendanceToExcel = (
  records: AttendanceRecord[],
  filters: ExportFilters,
  worksites: Worksite[],
  workers: UserData[]
) => {
  // Crear un nuevo workbook
  const wb = XLSX.utils.book_new();

  // Preparar datos para el encabezado
  const startDateStr = filters.startDate.toLocaleDateString('es-ES');
  const endDateStr = filters.endDate.toLocaleDateString('es-ES');
  const worksiteName = filters.worksiteId
    ? worksites.find(w => w.worksiteId === filters.worksiteId)?.name || 'Todas'
    : 'Todas';
  const workerName = filters.workerId
    ? workers.find(w => w.uid === filters.workerId)?.fullName || 'Todos'
    : 'Todos';

  // Preparar datos de registros
  const recordsData = records.map(record => {
    const worker = workers.find(w => w.uid === record.workerId);
    const worksite = worksites.find(w => w.worksiteId === record.worksiteId);

    return {
      Nombre: worker?.fullName || 'N/A',
      Obra: worksite?.name || 'N/A',
      Fecha: record.date.toDate().toLocaleDateString('es-ES'),
      Estado: record.status,
      Entrada: record.punchIn?.timestamp
        ? record.punchIn.timestamp.toDate().toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' })
        : 'N/A',
      Salida: record.punchOut?.timestamp
        ? record.punchOut.timestamp.toDate().toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' })
        : 'N/A',
      'Horas Trabajadas': record.workedHours ? `${record.workedHours.toFixed(2)}h` : 'N/A'
    };
  });

  // Crear header data (este será en filas separadas)
  const headerData: (string | number)[][] = [
    ['REPORTE DE ASISTENCIAS'],
    [],
    ['Fecha de Inicio:', startDateStr],
    ['Fecha de Fin:', endDateStr],
    ['Obra:', worksiteName],
    ['Trabajador:', workerName],
    [],
    [] // Fila vacía antes de la tabla de datos
  ];

  // Crear un array con header + datos
  const allData = [
    ...headerData,
    Object.keys(recordsData[0] || {}), // Headers de la tabla
    ...recordsData.map(row => Object.values(row)) // Datos
  ];

  // Crear hoja de cálculo
  const ws = XLSX.utils.aoa_to_sheet(allData as (string | number | boolean | Date)[][]);

  // Estilos y formato
  // Ancho de columnas
  const colWidths = [20, 20, 15, 15, 12, 12, 18];
  ws['!cols'] = colWidths.map(width => ({ wch: width }));

  // Agregar estilos a las celdas
  // Título principal
  ws['A1'] = {
    ...ws['A1'],
    t: 's',
    v: 'REPORTE DE ASISTENCIAS',
    s: {
      font: { bold: true, size: 14, color: { rgb: 'FFFFFF' } },
      fill: { fgColor: { rgb: '1F2937' } },
      alignment: { horizontal: 'center', vertical: 'center' }
    }
  };

  // Headers del formulario
  const headerRows = [
    { cell: 'A3', label: 'Fecha de Inicio:' },
    { cell: 'A4', label: 'Fecha de Fin:' },
    { cell: 'A5', label: 'Obra:' },
    { cell: 'A6', label: 'Trabajador:' }
  ];

  headerRows.forEach(({ cell }) => {
    if (ws[cell]) {
      ws[cell].s = {
        font: { bold: true, size: 11, color: { rgb: '1F2937' } },
        fill: { fgColor: { rgb: 'E5E7EB' } },
        alignment: { horizontal: 'left', vertical: 'center' }
      };
    }
  });

  // Headers de la tabla de datos
  const tableHeaderRow = 8; // Fila donde están los headers de tabla (después de encabezado)
  const headerCells = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];
  headerCells.forEach(col => {
    const cellRef = `${col}${tableHeaderRow}`;
    if (ws[cellRef]) {
      ws[cellRef].s = {
        font: { bold: true, size: 11, color: { rgb: 'FFFFFF' } },
        fill: { fgColor: { rgb: '3B82F6' } },
        alignment: { horizontal: 'center', vertical: 'center' }
      };
    }
  });

  // Freeze panes
  ws['!freeze'] = {
    xSplit: 0,
    ySplit: 9, // Congela hasta la fila 9 (antes de los datos)
    topLeftCell: 'A10'
  };

  // Agregar hoja al workbook
  XLSX.utils.book_append_sheet(wb, ws, 'Reporte');

  // Generar nombre de archivo
  const fileName = `Reporte-Asistencias-${new Date().toLocaleDateString('es-ES').replace(/\//g, '-')}.xlsx`;

  // Guardar archivo
  XLSX.writeFile(wb, fileName);
};
