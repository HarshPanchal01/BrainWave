import 'package:flutter/material.dart';
import '../models/note.dart';
import '../models/folder.dart';
import '../services/db_helper.dart';
import '../services/summarization_service.dart';
import '../services/suggestion_service.dart'; // Import Suggestion Service
import 'package:supabase_flutter/supabase_flutter.dart';

class NoteEditor extends StatefulWidget {
  final Note? note; // If null, this is a new note
  final int? initialFolderId; // Current folder ID

  const NoteEditor({Key? key, this.note, this.initialFolderId}) : super(key: key);

  @override
  _NoteEditorState createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  final _formKey = GlobalKey<FormState>();
  final DBHelper _dbHelper = DBHelper();
  final SummarizationService _summarizationService = SummarizationService();
  final SuggestionService _suggestionService = SuggestionService();

  String _title = '';
  String _content = '';
  String _summary = '';
  List<String> _suggestions = [];
  bool _isLoadingSummary = false;
  bool _isLoadingSuggestions = false;
  int? _selectedFolderId;
  List<Folder> _folders = [];

  @override
  void initState() {
    super.initState();
    _title = widget.note?.title ?? '';
    _content = widget.note?.body ?? '';
    _selectedFolderId = widget.note?.folderId ?? widget.initialFolderId;
    _loadFoldersFromDb();
  }

  // Load folders from the database
  void _loadFoldersFromDb() async {
    try {
      List<Folder> foldersFromDb = await _dbHelper.getFolders();
      setState(() {
        _folders = foldersFromDb;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading folders: $e')),
      );
    }
  }

  // Summarize note content
  Future<void> _summarizeContent() async {
    setState(() {
      _isLoadingSummary = true;
    });
    try {
      final summary = await _summarizationService.summarizeText(_content);
      setState(() {
        _summary = summary;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error summarizing content: $e')),
      );
    } finally {
      setState(() {
        _isLoadingSummary = false;
      });
    }
  }

  // Generate AI suggestions
  Future<void> _generateSuggestions() async {
    setState(() {
      _isLoadingSuggestions = true;
    });
    try {
      final suggestions = await _suggestionService.generateSuggestions(_content);
      setState(() {
        _suggestions = suggestions;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating suggestions: $e')),
      );
    } finally {
      setState(() {
        _isLoadingSuggestions = false;
      });
    }
  }

  // Save the note to the database
  void _saveNote() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      Note note = Note(
        id: widget.note?.id ?? 0, // Provide a default value for new notes
        title: _title,
        body: _content,
        userId: user.id,
        folderId: _selectedFolderId,
        attachmentPath: null, // Adjust if handling attachments
        createdAt: widget.note?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      try {
        if (widget.note == null) {
          await _dbHelper.insertNote(note);
        } else {
          await _dbHelper.updateNote(note);
        }
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving note: $e')),
        );
      }
    }
  }

  // Build the UI
  @override
  Widget build(BuildContext context) {
    if (_folders.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Loading...', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            value: _selectedFolderId,
            dropdownColor: Colors.blue,
            iconEnabledColor: Colors.white,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: const Text('No Folder', style: TextStyle(color: Colors.white)),
              ),
              ..._folders.map((folder) {
                return DropdownMenuItem<int?>(
                  value: folder.id,
                  child: Text(folder.name, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
            ],
            onChanged: (value) {
              setState(() {
                _selectedFolderId = value;
              });
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _saveNote,
            tooltip: 'Save Note',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextFormField(
                initialValue: _title,
                maxLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                onSaved: (value) => _title = value?.trim() ?? '',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
            ),
            const Divider(color: Colors.grey, height: 1, thickness: 0.5),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextFormField(
                  initialValue: _content,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    hintText: 'Start typing your note...',
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 16),
                  onSaved: (value) => _content = value?.trim() ?? '',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter some content';
                    }
                    return null;
                  },
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _isLoadingSummary ? null : _summarizeContent,
              child: _isLoadingSummary ? CircularProgressIndicator() : Text('Summarize'),
            ),
            ElevatedButton(
              onPressed: _isLoadingSuggestions ? null : _generateSuggestions,
              child: _isLoadingSuggestions ? CircularProgressIndicator() : Text('AI Suggestions'),
            ),
            if (_summary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Summary: $_summary',
                  style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                ),
              ),
            if (_suggestions.isNotEmpty)
              ExpansionTile(
                title: Text('Suggestions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                children: _suggestions.map((suggestion) => ListTile(
                  title: Text(suggestion),
                )).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
