import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NoteDatabase.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '我的笔记',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: false,
      ),
      home: const NotesPage(),
    );
  }
}

class Note {
  int id;
  String title;
  String content;
  String date;
  int category;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'date': date,
        'category': category,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'],
        title: json['title'],
        content: json['content'],
        date: json['date'],
        category: json['category'],
      );
}

class NoteDatabase {
  static late SharedPreferences _prefs;
  static const String _keyNotes = 'notes_list';
  static int _nextId = 1;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final notes = await getAllNotes();
    if (notes.isNotEmpty) {
      _nextId = notes.map((n) => n.id).reduce((a, b) => a > b ? a : b) + 1;
    }
  }

  static Future<List<Note>> getAllNotes() async {
    final jsonString = _prefs.getString(_keyNotes);
    if (jsonString == null) return [];
    final List<dynamic> list = json.decode(jsonString);
    return list.map((e) => Note.fromJson(e)).toList();
  }

  static Future<void> saveNotes(List<Note> notes) async {
    final jsonString = json.encode(notes.map((n) => n.toJson()).toList());
    await _prefs.setString(_keyNotes, jsonString);
  }

  static Future<void> addNote(Note note) async {
    final notes = await getAllNotes();
    notes.add(note);
    await saveNotes(notes);
  }

  static Future<void> updateNote(Note updatedNote) async {
    final notes = await getAllNotes();
    final index = notes.indexWhere((n) => n.id == updatedNote.id);
    if (index != -1) {
      notes[index] = updatedNote;
      await saveNotes(notes);
    }
  }

  static Future<void> deleteNote(int id) async {
    final notes = await getAllNotes();
    notes.removeWhere((n) => n.id == id);
    await saveNotes(notes);
  }

  static int getNextId() {
    return _nextId++;
  }
}

class NotesPage extends StatefulWidget {
  const NotesPage({Key? key}) : super(key: key);

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  int _selectedCategory = 0;
  late Future<List<Note>> _notesFuture;
  final List<String> categories = ['全部', '菜单', '通话笔记', '未分类'];

  @override
  void initState() {
    super.initState();
    _refreshNotes();
  }

  void _refreshNotes() {
    setState(() {
      _notesFuture = NoteDatabase.getAllNotes();
    });
  }

  void _onCategoryTap(int index) {
    setState(() {
      _selectedCategory = index;
    });
  }

  void _addNote() async {
    final newNote = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditNotePage()),
    );
    if (newNote != null) {
      await NoteDatabase.addNote(newNote);
      _refreshNotes();
    }
  }

  void _editNote(Note note) async {
    final editedNote = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditNotePage(note: note),
      ),
    );
    if (editedNote != null) {
      await NoteDatabase.updateNote(editedNote);
      _refreshNotes();
    }
  }

  void _deleteNote(int id) async {
    await NoteDatabase.deleteNote(id);
    _refreshNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的笔记'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: GestureDetector(
                    onTap: () => _onCategoryTap(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedCategory == index ? Colors.grey[200] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 2),
                        ],
                      ),
                      child: Text(
                        categories[index],
                        style: TextStyle(
                          color: _selectedCategory == index ? Colors.black : Colors.grey[600],
                          fontWeight: _selectedCategory == index ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Note>>(
              future: _notesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('暂无笔记'));
                }
                final allNotes = snapshot.data!;
                final filteredNotes = _selectedCategory == 0
                    ? allNotes
                    : allNotes.where((note) => note.category == _selectedCategory).toList();

                if (filteredNotes.isEmpty) {
                  return const Center(child: Text('该分类下无笔记'));
                }

                return ListView.builder(
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, index) {
                    final note = filteredNotes[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(note.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(note.date, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                                const SizedBox(width: 8),
                                const Icon(Icons.star, size: 16, color: Colors.yellow),
                              ],
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _editNote(note),
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('删除笔记？'),
                              content: Text('确定要删除“${note.title}”吗？'),
                              actions: [
                                TextButton(onPressed: Navigator.of(context).pop, child: const Text('取消')),
                                TextButton(
                                  onPressed: () {
                                    _deleteNote(note.id);
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('删除', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        onPressed: _addNote,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.notes), label: '笔记'),
          BottomNavigationBarItem(icon: Icon(Icons.check_box), label: '待办'),
        ],
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('待办功能开发中...')),
            );
          }
        },
      ),
    );
  }
}

class AddEditNotePage extends StatefulWidget {
  final Note? note;

  const AddEditNotePage({Key? key, this.note}) : super(key: key);

  @override
  State<AddEditNotePage> createState() => _AddEditNotePageState();
}

class _AddEditNotePageState extends State<AddEditNotePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late int _category;

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController = TextEditingController(text: widget.note!.title);
      _contentController = TextEditingController(text: widget.note!.content);
      _category = widget.note!.category;
    } else {
      _titleController = TextEditingController();
      _contentController = TextEditingController();
      _category = 1;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? '新建笔记' : '编辑笔记'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '标题 *'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return '请输入标题';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '内容'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _category,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('菜单')),
                  DropdownMenuItem(value: 2, child: Text('通话笔记')),
                  DropdownMenuItem(value: 3, child: Text('未分类')),
                ],
                onChanged: (value) {
                  setState(() {
                    _category = value!;
                  });
                },
                decoration: const InputDecoration(labelText: '分类'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final note = Note(
                      id: widget.note?.id ?? NoteDatabase.getNextId(),
                      title: _titleController.text.trim(),
                      content: _contentController.text,
                      date: DateTime.now().toLocal().toString().split(' ')[0].substring(5),
                      category: _category,
                    );
                    Navigator.pop(context, note);
                  }
                },
                child: Text(widget.note == null ? '保存笔记' : '更新笔记'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
