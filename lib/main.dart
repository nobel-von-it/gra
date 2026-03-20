import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

// --- КОНСТАНТЫ ---
const String boxGames = 'games_box';
const String boxTemplateSettings = 'settings_box';
const String boxSetetings = 'app_settings_box';

const List<String> allAvailableGenres = [
  'Action',
  'RPG',
  'Shooter',
  'Adventure',
  'OpenWorld',
  'Metroidvania',
  'Platformer',
  'TBC',
  'Indie',
  'Strategy',
  'Horror',
  'Puzzle',
  'Comedy',
  'Drama',
  'Sci-Fi',
  'Fantasy',
];

enum ReviewType {
  game(
    value: 'game',
    label: 'Игра',
    icon: Icons.videogame_asset,
    templateKey: 'default_criteria_game',
    defaultCriterias: ['Геймплей', 'Сюжет', 'Графика', 'Оптимизация', 'Звук'],
    dataKey: 'playTime',
    unit: 'ч.',
    unitString: 'Время прохождения',
    unitIcon: Icons.repeat,
  ),
  anime(
    value: 'anime',
    label: 'Аниме',
    icon: Icons.tv,
    templateKey: 'default_criteria_anime',
    defaultCriterias: ['Анимация', 'Сюжет', 'Персонажи', 'Звук'],
    dataKey: 'episodes',
    unit: 'сер.',
    unitString: 'Количество серий',
    unitIcon: Icons.numbers,
  ),
  manga(
    value: 'manga',
    label: 'Манга',
    icon: Icons.library_books,
    templateKey: 'default_criteria_manga',
    defaultCriterias: ['Рисовка', 'Сюжет', 'Персонажи', 'Звук'],
    dataKey: 'chapters',
    unit: 'гл.',
    unitString: 'Количество глав',
    unitIcon: Icons.numbers,
  ),
  book(
    value: 'book',
    label: 'Книга',
    icon: Icons.book,
    templateKey: 'default_criteria_book',
    defaultCriterias: ['Смысл', 'Стиль'],
    dataKey: 'readTime',
    unit: 'дн.',
    unitString: 'Время прочтения',
    unitIcon: Icons.repeat,
  ),
  movie(
    value: 'movie',
    label: 'Фильм',
    icon: Icons.movie,
    templateKey: 'default_criteria_film',
    defaultCriterias: ['Картинка', 'Сюжет', 'Персонажи', 'Звук'],
    dataKey: 'length',
    unit: 'мин.',
    unitString: 'Длительность',
    unitIcon: Icons.timer,
  ),
  music(
    value: 'music',
    label: 'Трек',
    icon: Icons.music_note,
    templateKey: 'default_criteria_music',
    defaultCriterias: ['Вайб', 'Смысл', 'Стиль', 'Текст'],
    dataKey: 'length',
    unit: 'мин.',
    unitString: 'Длительность',
    unitIcon: Icons.timer,
  ),
  video(
    value: 'video',
    label: 'Видео',
    icon: Icons.video_camera_front,
    templateKey: 'default_criteria_video',
    defaultCriterias: ['Смысл'],
    dataKey: 'url',
    unit: '',
    unitString: 'Ссылка',
    unitIcon: Icons.link,
  );

  final String value;
  final String label;
  final IconData icon;
  final String templateKey;
  final String dataKey;
  final List<String> defaultCriterias;
  final String unit;
  final String unitString;
  final IconData unitIcon;

  const ReviewType({
    required this.value,
    required this.label,
    required this.icon,
    required this.templateKey,
    required this.dataKey,
    required this.defaultCriterias,
    required this.unit,
    required this.unitString,
    required this.unitIcon,
  });
}

ReviewType getReviewType(dynamic type) {
  return ReviewType.values.firstWhere(
    (e) => e.name == type,
    orElse: () => ReviewType.game,
  );
}

// Миграция для старых данных
Future<void> migrateData() async {
  final box = Hive.box(boxGames);
  for (int i = 0; i < box.length; i++) {
    final item = box.getAt(i);
    if (item == null) continue;
    final Map<String, dynamic> updated = Map<String, dynamic>.from(item);
    bool changed = false;

    // Проставляем тип 'game' старым записям
    if (updated['type'] == null) {
      updated['type'] = 'game';
      changed = true;
    }
    // Старая миграция жанров
    if (updated['genres'] is String) {
      String oldGenres = updated['genres'] as String;
      updated['genres'] = oldGenres
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      changed = true;
    }

    if (changed) await box.putAt(i, updated);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox(boxGames);
  await Hive.openBox(boxSetetings);
  await Hive.openBox(boxTemplateSettings);

  await migrateData();

  final settings = Hive.box(boxTemplateSettings);

  for (var rt in ReviewType.values) {
    if (settings.get(rt.templateKey) == null) {
      settings.put(rt.templateKey, rt.defaultCriterias);
    }
  }

  runApp(const GameReviewApp());
}

// --- СЕРВИС ЭКСПОРТА / ИМПОРТА ---
class BackupService {
  static Future<void> exportDatabase(BuildContext context) async {
    final gamesBox = Hive.box(boxGames);
    final settingsBox = Hive.box(boxTemplateSettings);

    final backup = {
      'reviews': gamesBox.values.toList(),
      'templates': {
        for (var type in ReviewType.values)
          type.templateKey: settingsBox.get(type.templateKey),
      },
    };

    final String jsonString = jsonEncode(backup);

    try {
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        // --- ЛОГИКА ДЛЯ ПК ---
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Выберите место для сохранения бэкапа',
          fileName: 'reviewer_backup.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsString(jsonString);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Бэкап успешно сохранен!')),
          );
        }
      } else {
        // --- ЛОГИКА ДЛЯ МОБИЛОК ---
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/reviewer_backup.json');
        await file.writeAsString(jsonString);

        await Share.shareXFiles([XFile(file.path)], text: 'Бэкап моих отзывов');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка экспорта: $e')));
    }
  }

  static Future<void> importDatabase(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final String jsonString = await file.readAsString();
        final Map<String, dynamic> backup = jsonDecode(jsonString);

        final gamesBox = Hive.box(boxGames);
        final settingsBox = Hive.box(boxTemplateSettings);

        // Очистка и замена данных
        await gamesBox.clear();
        await gamesBox.addAll(backup['reviews']);

        if (backup['templates'] != null) {
          backup['templates'].forEach((key, value) {
            settingsBox.put(key, value);
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Данные успешно импортированы!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка импорта: $e')));
    }
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.backup_table),
            title: const Text('Бэкап и восстановление'),
            subtitle: const Text('Экспорт/импорт базы данных'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const BackupSettingsScreen()),
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}

// --- ЭКРАН НАСТРОЕК БЭКАПА ---
class BackupSettingsScreen extends StatelessWidget {
  const BackupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Бэкап данных'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.file_copy),
            title: const Text('Путь к автоматическому бэкапу'),
            subtitle: const Text('Выберите место для сохранения бэкапа'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: const Text('Время бэкапа'),
            subtitle: const Text('Выберите время для автоматического бэкапа'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.save),
            title: const Text('Сделать бэкап'),
            subtitle: const Text('Сохранить все отзывы в JSON файл'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.restore_sharp),
            title: const Text('Загрузить последний бэкап'),
            subtitle: const Text('Восстановить отзывы из файла'),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Экспортировать базу'),
            subtitle: const Text('Сохранить все отзывы в JSON файл'),
            onTap: () => BackupService.exportDatabase(context),
          ),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Импортировать базу'),
            subtitle: const Text('Восстановить отзывы из файла'),
            onTap: () => BackupService.importDatabase(context),
          ),
        ],
      ),
    );
  }
}

class GameReviewApp extends StatelessWidget {
  const GameReviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reviewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.dark,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

enum SortMode { dateDesc, dateAsc, liked, disliked, neutral }

// --- ГЛАВНЫЙ ЭКРАН ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool isGridView = false;
  String searchQuery = '';
  SortMode sortMode = SortMode.dateDesc;

  bool isAscending = false;

  Set<String> activeTypes = {};
  Set<String> activeStatuses = {};

  final Box gamesBox = Hive.box(boxGames);
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _getSortedAndFiltered(List<dynamic> items) {
    var result = items.where((g) {
      // Безопасное получение данных из Map
      final itemType = g['type']?.toString() ?? '';
      final itemStatus = g['status']?.toString() ?? '';
      final itemTitle = g['title']?.toString().toLowerCase() ?? '';

      // 1. Поиск
      final matchesSearch = itemTitle.contains(searchQuery.toLowerCase());

      // 2. Фильтр по типу (если сет пустой — подходят все)
      final matchesType = activeTypes.isEmpty || activeTypes.contains(itemType);

      // 3. Фильтр по статусу (если сет пустой — подходят все)
      final matchesStatus =
          activeStatuses.isEmpty || activeStatuses.contains(itemStatus);

      return matchesSearch && matchesType && matchesStatus;
    }).toList();

    // Сортировка по дате
    result.sort((a, b) {
      final da =
          DateTime.tryParse(a['dateTime']?.toString() ?? '') ?? DateTime(0);
      final db =
          DateTime.tryParse(b['dateTime']?.toString() ?? '') ?? DateTime(0);
      return isAscending ? da.compareTo(db) : db.compareTo(da);
    });

    return result;
  }

  void _showContextMenu(BuildContext context, int realIndex, String title) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Удалить отзыв',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context); // Закрываем меню
                  _confirmDelete(
                    context,
                    realIndex,
                    title,
                  ); // Показываем подтверждение
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          // Чтобы чипы обновлялись сразу внутри шторки
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Сортировка по дате",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text("Сначала новые"),
                        selected: !isAscending,
                        onSelected: (val) {
                          setState(() => isAscending = false);
                          setModalState(() {});
                        },
                      ),
                      ChoiceChip(
                        label: const Text("Сначала старые"),
                        selected: isAscending,
                        onSelected: (val) {
                          setState(() => isAscending = true);
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  const Text(
                    "Типы контента",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: ReviewType.values.map((type) {
                      return FilterChip(
                        label: Text(type.label),
                        selected: activeTypes.contains(type.value),
                        onSelected: (selected) {
                          setState(() {
                            selected
                                ? activeTypes.add(type.value)
                                : activeTypes.remove(type.value);
                          });
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const Divider(height: 30),
                  const Text(
                    "Оценка",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: ['Like', 'Neutral', 'Dislike'].map((status) {
                      return FilterChip(
                        label: Text(
                          status == 'Like'
                              ? 'Нравится'
                              : status == 'Dislike'
                              ? 'Нет'
                              : 'Норм',
                        ),
                        selected: activeStatuses.contains(status),
                        onSelected: (selected) {
                          setState(() {
                            selected
                                ? activeStatuses.add(status)
                                : activeStatuses.remove(status);
                          });
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        activeTypes.clear();
                        activeStatuses.clear();
                        isAscending = false;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Сбросить всё",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, int index, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление'),
        content: Text('Вы уверены, что хотите удалить "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              gamesBox.deleteAt(index);
              Navigator.pop(ctx);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reviews'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible:
                  activeTypes.isNotEmpty || activeStatuses.isNotEmpty,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _showFilterSheet,
            tooltip: 'Фильтры и сортировка',
          ),
          IconButton(
            icon: const Icon(Icons.book_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const TemplateSettingsScreen()),
            ),
            tooltip: 'Шаблоны',
          ),
          IconButton(
            icon: Icon(isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => isGridView = !isGridView),
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const SettingsScreen()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                filled: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => setState(() => searchQuery = v),
            ),
          ),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: gamesBox.listenable(),
        builder: (context, Box box, _) {
          final items = _getSortedAndFiltered(box.values.toList());
          if (box.isEmpty) return const Center(child: Text('Пусто...'));
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'По фильтрам ничего не подходит... Гет гут!',
                style: TextStyle(fontSize: 24),
              ),
            );
          }
          return isGridView
              ? _buildGrid(items, box.values.toList())
              : _buildList(items, box.values.toList());
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (ctx) => const AddReviewForm(),
        ),
        label: const Text('Добавить'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList(List<dynamic> items, List<dynamic> all) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = Map<String, dynamic>.from(items[index]);
        final realIndex = all.indexOf(items[index]);
        final ReviewType type = getReviewType(item['type']);
        return Card(
          child: ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) =>
                    ReviewDetailScreen(data: item, index: realIndex),
              ),
            ),
            onLongPress: () =>
                _showContextMenu(context, realIndex, item['title']),
            leading: Icon(type.icon, color: Colors.cyan),
            title: Text(item['title']),
            subtitle: item[type.dataKey] == ''
                ? Text(type.name)
                : Text("${type.name} • ${item[type.dataKey]} ${type.unit}"),
            trailing: _getStatusIcon(item['status']),
          ),
        );
      },
    );
  }

  Widget _buildGrid(List<dynamic> items, List<dynamic> all) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 240,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = Map<String, dynamic>.from(items[index]);
        final realIndex = all.indexOf(items[index]);
        final ReviewType type = getReviewType(item['type']);
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (c) => ReviewDetailScreen(data: item, index: realIndex),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(type.icon, size: 40, color: Colors.cyan),
                const Spacer(),
                Text(
                  item['title'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 2,
                ),
                _getStatusIcon(item['status'], size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _getStatusIcon(String? status, {double size = 24}) {
    if (status == 'Like')
      return Icon(
        Icons.sentiment_very_satisfied,
        color: Colors.greenAccent,
        size: size,
      );
    if (status == 'Dislike')
      return Icon(
        Icons.sentiment_very_dissatisfied,
        color: Colors.redAccent,
        size: size,
      );
    return Icon(
      Icons.sentiment_neutral,
      color: Colors.orangeAccent,
      size: size,
    );
  }
}

// --- ФОРМА ДОБАВЛЕНИЯ ---
class AddReviewForm extends StatefulWidget {
  const AddReviewForm({super.key});
  @override
  State<AddReviewForm> createState() => _AddReviewFormState();
}

class _AddReviewFormState extends State<AddReviewForm> {
  final _titleController = TextEditingController();
  String type = 'game'; // 'game' or 'anime' or 'manga'
  String status = 'Neutral';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: ReviewType.values
                  .map(
                    (rt) => ButtonSegment(
                      value: rt.value,
                      label: Text(rt.label),
                      icon: Icon(rt.icon),
                    ),
                  )
                  .toList(),
              selected: {type},
              onSelectionChanged: (val) => setState(() => type = val.first),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Название *'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () {
              if (_titleController.text.isEmpty) return;
              final templateKey = getReviewType(type).templateKey;
              final List<String> template = List<String>.from(
                Hive.box(boxTemplateSettings).get(templateKey),
              );

              final newItem = {
                'type': type,
                'title': _titleController.text,
                'genres': <String>[],
                for (var type in ReviewType.values) type.dataKey: '',
                'status': status,
                'dateTime': DateTime.now().toString(),
                'criteria': template
                    .map((name) => {'name': name, 'score': ''})
                    .toList(),
                'notes': <String>[],
                'finalOpinion': '',
              };
              Hive.box(boxGames).add(newItem);
              Navigator.pop(context);
            },
            child: const Text('Создать'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// --- ЭКРАН ДЕТАЛЕЙ ---
class ReviewDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final int index;
  const ReviewDetailScreen({
    super.key,
    required this.data,
    required this.index,
  });
  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends State<ReviewDetailScreen> {
  late Map<String, dynamic> data;
  late TextEditingController _mainValController; // Для часов или серий или глав
  late TextEditingController _finalOpinionController;

  @override
  void initState() {
    super.initState();
    data = Map<String, dynamic>.from(widget.data);
    final ReviewType type = getReviewType(data['type']);
    _mainValController = TextEditingController(text: data[type.dataKey]);
    _finalOpinionController = TextEditingController(text: data['finalOpinion']);
  }

  void _save() => Hive.box(boxGames).putAt(widget.index, data);

  void _addCustomCriterion() {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый критерий'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Название...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  data['criteria'].add({
                    'name': nameController.text.trim(),
                    'score': '',
                  });
                });
                _save();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(data['title'])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoCard(data['type']),
            const SizedBox(height: 20),
            _buildCriteriaSection(),
            const SizedBox(height: 20),
            _buildNotesSection(),
            const SizedBox(height: 20),
            const Text(
              "Вердикт",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextField(
              maxLines: 3,
              controller: _finalOpinionController,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onChanged: (v) {
                data['finalOpinion'] = v;
                _save();
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String typeStr) {
    final ReviewType type = getReviewType(typeStr);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Like', 'Neutral', 'Dislike']
                  .map(
                    (s) => IconButton(
                      icon: Icon(
                        s == 'Like'
                            ? Icons.thumb_up
                            : (s == 'Dislike'
                                  ? Icons.thumb_down
                                  : Icons.sentiment_neutral),
                      ),
                      color: data['status'] == s ? Colors.cyan : Colors.grey,
                      onPressed: () => setState(() {
                        data['status'] = s;
                        _save();
                      }),
                    ),
                  )
                  .toList(),
            ),
            TextField(
              controller: _mainValController,
              decoration: InputDecoration(
                labelText: type.unitString,
                prefixIcon: Icon(type.unitIcon),
              ),
              onChanged: (v) {
                data[type.dataKey] = v;
                _save();
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ...List<String>.from(data['genres']).map(
                  (g) => InputChip(
                    label: Text(g),
                    onDeleted: () {
                      setState(() => data['genres'].remove(g));
                      _save();
                    },
                  ),
                ),
                ActionChip(
                  label: const Text('+ Жанр'),
                  onPressed: _showGenrePicker,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showGenrePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        children: allAvailableGenres
            .map(
              (g) => ListTile(
                title: Text(g),
                onTap: () {
                  if (!data['genres'].contains(g))
                    setState(() => data['genres'].add(g));
                  _save();
                  Navigator.pop(ctx);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCriteriaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Оценки",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...List.generate(
          data['criteria'].length,
          (i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data['criteria'][i]['name'],
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          data['criteria'].removeAt(i);
                        });
                        _save();
                      },
                    ),
                  ],
                ),
                TextField(
                  controller:
                      TextEditingController(text: data['criteria'][i]['score'])
                        ..selection = TextSelection.collapsed(
                          offset: data['criteria'][i]['score'].length,
                        ),
                  maxLines: null,
                  minLines: 1,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(),
                    hintText: 'Ваша оценка...',
                  ),
                  onChanged: (v) {
                    data['criteria'][i]['score'] = v;
                    _save();
                  },
                ),
              ],
            ),
          ),
        ),
        Center(
          child: TextButton.icon(
            onPressed: _addCustomCriterion,
            icon: const Icon(Icons.add),
            label: const Text('Добавить критерий'),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    final controller = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Заметки",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        ...data['notes'].map(
          (n) => Card(
            child: ListTile(
              title: Text(n),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => setState(() {
                  data['notes'].remove(n);
                  _save();
                }),
              ),
            ),
          ),
        ),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Добавить заметку...',
            suffixIcon: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () {
                if (controller.text.isEmpty) return;
                setState(() => data['notes'].add(controller.text));
                _save();
                controller.clear();
              },
            ),
          ),
        ),
      ],
    );
  }
}

// --- НАСТРОЙКИ ШАБЛОНОВ (TABS) ---
class TemplateSettingsScreen extends StatelessWidget {
  const TemplateSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Tab> tabs = ReviewType.values
        .map((rt) => Tab(text: rt.label))
        .toList();
    final List<TemplateEditor> templateEditors = ReviewType.values
        .map((rt) => TemplateEditor(templateKey: rt.templateKey))
        .toList();
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Настройка шаблонов'),
          bottom: TabBar(
            tabs: tabs,
            isScrollable: true,
            indicatorSize: TabBarIndicatorSize.label,
            labelPadding: EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
        body: TabBarView(children: templateEditors),
      ),
    );
  }
}

class TemplateEditor extends StatefulWidget {
  final String templateKey;
  const TemplateEditor({super.key, required this.templateKey});
  @override
  State<TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<TemplateEditor> {
  late List<String> criteria;
  @override
  void initState() {
    super.initState();
    criteria = List<String>.from(
      Hive.box(boxTemplateSettings).get(widget.templateKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: criteria.length + 1,
      itemBuilder: (context, i) {
        if (i == criteria.length) {
          return ElevatedButton.icon(
            onPressed: () => setState(() {
              criteria.add('Новый критерий');
              Hive.box(boxTemplateSettings).put(widget.templateKey, criteria);
            }),
            icon: const Icon(Icons.add),
            label: const Text('Добавить'),
          );
        }
        return Card(
          child: ListTile(
            title: TextField(
              controller: TextEditingController(text: criteria[i])
                ..selection = TextSelection.collapsed(
                  offset: criteria[i].length,
                ),
              onChanged: (v) {
                criteria[i] = v;
                Hive.box(boxTemplateSettings).put(widget.templateKey, criteria);
              },
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => setState(() {
                criteria.removeAt(i);
                Hive.box(boxTemplateSettings).put(widget.templateKey, criteria);
              }),
            ),
          ),
        );
      },
    );
  }
}
