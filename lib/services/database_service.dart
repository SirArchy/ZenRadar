import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/matcha_product.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static DatabaseService get instance => _instance;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'zenradar.db');
    return await openDatabase(path, version: 1, onCreate: _createDatabase);
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE matcha_products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        site TEXT NOT NULL,
        url TEXT NOT NULL,
        isInStock INTEGER NOT NULL,
        lastChecked TEXT NOT NULL,
        price TEXT,
        imageUrl TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId TEXT NOT NULL,
        isInStock INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (productId) REFERENCES matcha_products (id)
      )
    ''');
  }

  Future<void> initDatabase() async {
    await database;
  }

  Future<void> insertProduct(MatchaProduct product) async {
    final db = await database;
    await db.insert(
      'matcha_products',
      product.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateProduct(MatchaProduct product) async {
    final db = await database;
    await db.update(
      'matcha_products',
      product.toJson(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<List<MatchaProduct>> getAllProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('matcha_products');
    return List.generate(maps.length, (i) {
      return MatchaProduct.fromJson(maps[i]);
    });
  }

  Future<MatchaProduct?> getProduct(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'matcha_products',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return MatchaProduct.fromJson(maps.first);
    }
    return null;
  }

  Future<List<MatchaProduct>> getProductsBySite(String site) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'matcha_products',
      where: 'site = ?',
      whereArgs: [site],
    );
    return List.generate(maps.length, (i) {
      return MatchaProduct.fromJson(maps[i]);
    });
  }

  Future<void> recordStockChange(String productId, bool isInStock) async {
    final db = await database;
    await db.insert('stock_history', {
      'productId': productId,
      'isInStock': isInStock ? 1 : 0,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getStockHistory(String productId) async {
    final db = await database;
    return await db.query(
      'stock_history',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'timestamp DESC',
      limit: 50,
    );
  }

  Future<void> deleteOldHistory() async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    await db.delete(
      'stock_history',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }
}
