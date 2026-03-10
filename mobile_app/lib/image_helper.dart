import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart'
    as path; // Jeśli nie masz, dodaj paczkę 'path' do pubspec.yaml

Future<String> zapiszZdjecieLokalnie(File tymczasoweZdjecie) async {
  // 1. Znajdź bezpieczny folder aplikacji na telefonie
  final directory = await getApplicationDocumentsDirectory();

  // 2. Stwórz unikalną nazwę pliku (np. 1678901234_paragon.jpg)
  final nazwaPliku =
      '${DateTime.now().millisecondsSinceEpoch}_${path.basename(tymczasoweZdjecie.path)}';

  // 3. Połącz ścieżkę folderu z nazwą pliku
  final sciezkaDocelowa = '${directory.path}/$nazwaPliku';

  // 4. Skopiuj plik na stałe miejsce
  final zapisaneZdjecie = await tymczasoweZdjecie.copy(sciezkaDocelowa);

  // 5. Zwróć ścieżkę (to właśnie ten tekst zapiszemy w bazie SQLite!)
  return zapisaneZdjecie.path;
}
