import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // Wzorzec Singleton - gwarantuje, że mamy tylko jedną instancję bazy w całej apce
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Otwieranie lub inicjalizacja bazy
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ksiegowy.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // TWORZENIE TABEL (Architektura relacyjna)
  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';

    // Tabela Paragonów
    await db.execute('''
      CREATE TABLE paragony(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sklep TEXT,
        data TEXT,
        kwota REAL,
        image_local_path TEXT,  -- NOWA KOLUMNA NA ZDJĘCIE
        ai_model_used TEXT      -- NOWA KOLUMNA NA NAZWĘ MODELU
      )
    ''');

    // Tabela Pozycji (produktów)
    await db.execute('''
      CREATE TABLE pozycje (
        id $idType,
        paragon_id $intType,
        nazwa $textType,
        cena $realType,
        FOREIGN KEY (paragon_id) REFERENCES paragony (id) ON DELETE CASCADE
      )
    ''');
  }

  // ==========================================
  // METODY DO ZAPISYWANIA DANYCH Z QWENA
  // ==========================================

  // 1. Zapisuje paragon i zwraca jego wygenerowane ID
  Future<int> dodajParagon(Map<String, dynamic> paragonInfo) async {
    final db = await instance.database;
    return await db.insert('paragony', paragonInfo);
  }

  // 2. Zapisuje pojedynczy produkt podpinając go pod ID paragonu
  Future<int> dodajPozycje(Map<String, dynamic> pozycjaInfo) async {
    final db = await instance.database;
    return await db.insert('pozycje', pozycjaInfo);
  }

  // ==========================================
  // METODY DO ODCZYTU (Na potrzeby zakładek)
  // ==========================================

  // Pobiera wszystkie paragony do Zakładki "Paragony"
  Future<List<Map<String, dynamic>>> pobierzWszystkieParagony() async {
    final db = await instance.database;
    return await db.query('paragony', orderBy: 'data DESC');
  }

  // Pobiera wszystkie pozycje do Zakładki "Baza/Analityka"
  Future<List<Map<String, dynamic>>> pobierzWszystkiePozycje() async {
    final db = await instance.database;
    // Łączymy tabele, żeby przy produkcie wiedzieć, z jakiego jest sklepu i z jaką datą
    return await db.rawQuery('''
      SELECT pozycje.*, paragony.sklep, paragony.data 
      FROM pozycje 
      JOIN paragony ON pozycje.paragon_id = paragony.id
      ORDER BY paragony.data DESC
    ''');
  }
  // ==========================================
  // ZARZĄDZANIE PARAGONAMI (ZAKŁADKA 2)
  // ==========================================

  // 1. Pobieranie produktów tylko dla konkretnego paragonu
  Future<List<Map<String, dynamic>>> pobierzPozycjeDlaParagonu(
    int paragonId,
  ) async {
    final db = await instance.database;
    return await db.query(
      'pozycje',
      where: 'paragon_id = ?',
      whereArgs: [paragonId],
    );
  }

  // 2. Usuwanie całego paragonu i jego zawartości
  Future<void> usunParagon(int id) async {
    final db = await instance.database;
    // Bezpieczniej usunąć najpierw pozycje, potem paragon
    await db.delete('pozycje', where: 'paragon_id = ?', whereArgs: [id]);
    await db.delete('paragony', where: 'id = ?', whereArgs: [id]);
  }

  // 3. Aktualizacja nazwy i ceny konkretnego produktu
  Future<void> aktualizujPozycje(
    int pozycjaId,
    String nowaNazwa,
    double nowaCena,
  ) async {
    final db = await instance.database;
    await db.update(
      'pozycje',
      {'nazwa': nowaNazwa, 'cena': nowaCena},
      where: 'id = ?',
      whereArgs: [pozycjaId],
    );
  }

  // 4. Przeliczanie łącznej sumy paragonu (gdy zmienisz cenę produktu)
  Future<void> przeliczSumeParagonu(int paragonId) async {
    final db = await instance.database;
    final wynik = await db.rawQuery(
      'SELECT SUM(cena) as suma FROM pozycje WHERE paragon_id = ?',
      [paragonId],
    );

    double nowaSuma = (wynik.first['suma'] as num?)?.toDouble() ?? 0.0;
    await db.update(
      'paragony',
      {'kwota': nowaSuma},
      where: 'id = ?',
      whereArgs: [paragonId],
    );
  }
}
