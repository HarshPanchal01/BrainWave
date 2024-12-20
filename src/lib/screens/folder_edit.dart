import 'package:flutter/material.dart';
import 'package:src/models/folder.dart';
import 'package:src/services/db_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Stateful widget for editing a folder
class FolderEdit extends StatefulWidget {
  final Folder folder;

  const FolderEdit({Key? key, required this.folder}) : super(key: key);

  @override
  _FolderEditState createState() => _FolderEditState();
}

class _FolderEditState extends State<FolderEdit> {
  // Create a global key for the form
  final _formKey = GlobalKey<FormState>();
  late String _folderName;
  final DBHelper _dbHelper = DBHelper.instance();

  @override
  void initState() {
    super.initState();
    // Initialize folder name with the current folder's name
    _folderName = widget.folder.name;
  }

  // Method to rename the folder
  void _renameFolder() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // Prevent renaming to "Notes"
      if (_folderName.trim().toLowerCase() == 'notes') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Folder name "Notes" is reserved.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User not authenticated',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      // Create a new folder instance with the updated name
      Folder updatedFolder = Folder(
        id: widget.folder.id,
        name: _folderName.trim(),
        userId: user.id,
        createdAt: widget.folder.createdAt,
        updatedAt: DateTime.now(),
      );
      try {
        await _dbHelper.updateFolder(updatedFolder);
        Navigator.pop(context, true); // Return true to indicate success
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error renaming folder: $e',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Method to delete the folder
  void _deleteFolder() async {
    // Prevent deleting the default "Notes" folder
    if (widget.folder.name.toLowerCase() == 'notes') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot delete the default "Notes" folder.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show a confirmation dialog before deleting the folder
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: const Text(
            'Are you sure you want to delete this folder? This will unassign its notes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteFolder(widget.folder.id);
      Navigator.pop(context, true); // Indicate that a refresh is needed
    }
  }

  // Build the widget tree
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Folder'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                initialValue: _folderName,
                decoration: const InputDecoration(labelText: 'Folder Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a folder name';
                  }
                  return null;
                },
                onSaved: (value) => _folderName = value ?? '',
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _renameFolder,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
