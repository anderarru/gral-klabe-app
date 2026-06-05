// lib/utils/time_formatter.dart

String formatTimer(int seconds) {
  int orduak = seconds ~/ 3600;
  int minutuak = (seconds % 3600) ~/ 60;
  int segunduHondarra = seconds % 60;
  
  if (orduak > 0) {
    return '${orduak.toString().padLeft(2, '0')}:${minutuak.toString().padLeft(2, '0')}:${segunduHondarra.toString().padLeft(2, '0')}';
  }
  return '${minutuak.toString().padLeft(2, '0')}:${segunduHondarra.toString().padLeft(2, '0')}';
}