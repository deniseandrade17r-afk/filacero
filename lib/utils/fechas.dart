const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
];

String diaCorto(DateTime d) => _dias[d.weekday - 1];

String fechaLarga(DateTime d) =>
    '${_dias[d.weekday - 1]} ${d.day} ${_meses[d.month - 1]}';

String hora(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';