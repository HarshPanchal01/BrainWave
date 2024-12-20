import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:src/models/folder.dart';
import 'package:src/models/note.dart';
import 'package:src/models/reminder.dart';
import 'package:src/services/db_helper.dart';
import 'package:src/screens/note_editor.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key); // Constructor for HomeScreen
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Create an instance of the DBHelper class
  final DBHelper _dbHelper = DBHelper.instance();
  List<Note> _notes = [];
  List<Folder> _folders = [];
  Folder? _selectedFolder;

  // Search related variables
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Method to check if the user is authenticated
  void _checkAuth() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  void initState() {
    super.initState();
    _checkAuth(); // Check if the user is authenticated
    _searchController.addListener(_onSearchChanged); // Listen for search changes
    _refreshFolderList(); // Fetch folders when the widget is initialized
    _refreshNoteList(); // Fetch notes when the widget is initialized
  }

  // Dispose of the search controller
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Method to handle search changes
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
    _refreshNoteList();
  }

  // Fetch folders from the database
  void _refreshFolderList() async {
    try {
      List<Folder> folders = await _dbHelper.getFolders();
      setState(() {
        _folders = folders;
      });
    } catch (e) {
      // Handle error (e.g., show a snackbar)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error fetching folders: $e',
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

  // Fetch notes from the database
  void _refreshNoteList() async {
    try {
      List<Note> notes =
          await _dbHelper.getNotes(folderId: _selectedFolder?.id);
      if (_searchQuery.isNotEmpty) {
        notes = notes.where((note) {
          return note.title
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              note.body.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();
      }
      setState(() {
        _notes = notes;
      });
    } catch (e) {
      // Handle error (e.g., show a snackbar)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error fetching notes: $e',
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

  // Navigate to the Note Editor to add or edit a note
  Future<void> _navigateToEditor({Note? note}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditor(
          note: note,
          initialFolderId: _selectedFolder?.id, // Pass the current folder ID
        ),
      ),
    );
    _refreshNoteList(); // Refresh notes after returning
  }

  // Confirm deletion of a note
  Future<void> _deleteNoteConfirm(int id) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await _dbHelper.deleteNote(id);
                Navigator.pop(context);
                _refreshNoteList();
                // Show success SnackBar for deleting note
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Note deleted successfully.',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Error deleting note: $e',
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
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Add a new folder
  Future<void> _addFolder() async {
    String folderName = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          onChanged: (value) => folderName = value,
          decoration: const InputDecoration(hintText: 'Folder Name'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (folderName.isNotEmpty) {
                // Prevent creating a folder named "Notes"
                if (folderName.trim().toLowerCase() == 'notes') {
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
                try {
                  await _dbHelper.insertFolder(Folder(
                    id: DateTime.now().millisecondsSinceEpoch, // provide a unique id
                    name: folderName.trim(),
                    userId: 'your_user_id', // this will be replaced with actual user id
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ));
                  Navigator.pop(context);
                  _refreshFolderList();
                  // Show success SnackBar for adding folder
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Folder added successfully.',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error adding folder: $e',
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
            },
            child: const Text('Add'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Rename a folder
  void _renameFolder(Folder folder) {
    String newFolderName = folder.name;
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController controller =
            TextEditingController(text: folder.name);
        return AlertDialog(
          title: const Text('Rename Folder'),
          content: TextField(
            controller: controller,
            onChanged: (value) => newFolderName = value,
            decoration: const InputDecoration(hintText: 'Folder Name'),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (newFolderName.isNotEmpty) {
                  // Prevent renaming to "Notes"
                  if (newFolderName.trim().toLowerCase() == 'notes') {
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
                  await _dbHelper.updateFolder(Folder(
                    id: folder.id,
                    name: newFolderName.trim(),
                    userId: folder.userId,
                    createdAt: folder.createdAt,
                    updatedAt: DateTime.now(),
                  ));
                  Navigator.pop(context);
                  _refreshFolderList();
                }
              },
              child: const Text('Save'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Confirm deletion of a folder
  Future<void> _deleteFolderConfirm(int id) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: const Text(
            'This will remove the folder and all the notes inside. Continue?'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await _dbHelper.deleteFolder(id);
                Navigator.pop(context);
                setState(() {
                  _selectedFolder = null;
                });
                _refreshFolderList();
                _refreshNoteList();
                // Show success SnackBar for deleting folder
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Folder deleted successfully.',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Error deleting folder: $e',
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
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Build the drawer with folders
  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          // Drawer Header with Menu Icon to close the drawer
          Container(
            height: 80.0,
            color: Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 5.0),
            child: Column(
              children: [
                const SizedBox(height: 30.0),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context); // Close the drawer
                      },
                    ),
                    const SizedBox(width: 8.0),
                    const Text(
                      'Folders',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home, color: Colors.blue,),
            title: const Text(
              'Notes',
              style: TextStyle(color: Colors.black),
            ),
            selected: _selectedFolder == null,
            onTap: () {
              setState(() {
                _selectedFolder = null;
                Navigator.pop(context);
                _refreshNoteList();
              });
            },
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero, // Remove extra padding
              itemCount: _folders.length,
              separatorBuilder: (context, index) => const SizedBox(height: 1),
              itemBuilder: (context, index) {
                Folder folder = _folders[index];
                return ListTile(
                  leading: const Icon(Icons.folder, color: Colors.blue),
                  title: Text(
                    folder.name,
                    style: const TextStyle(color: Colors.black),
                  ),
                  selected: _selectedFolder?.id == folder.id,
                  onTap: () {
                    setState(() {
                      _selectedFolder = folder;
                      Navigator.pop(context);
                      _refreshNoteList(); // Fetch notes for the selected folder
                    });
                  },
                  trailing: PopupMenuButton<String>(
                    color: Colors.white,
                    onSelected: (value) {
                      if (value == 'rename') {
                        _renameFolder(folder);
                      } else if (value == 'delete') {
                        _deleteFolderConfirm(folder.id);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'rename',
                        child: Text('Rename',
                            style: TextStyle(color: Colors.black)),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete',
                            style: TextStyle(color: Colors.black)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Add Folder Button
          ListTile(
            leading: const Icon(Icons.add, color: Colors.black),
            title: const Text(
              'Add Folder',
              style: TextStyle(color: Colors.black),
            ),
            onTap: () {
              Navigator.pop(context);
              _addFolder();
            },
          ),
        ],
      ),
    );
  }

  // Helper method to format timestamps
  String _formatTimestamp(String timestamp) {
    DateTime noteTime = DateTime.parse(timestamp).toLocal(); // Convert to local time
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = today.subtract(const Duration(days: 1));

    if (noteTime.isAfter(today)) {
      // Today
      return 'Today, ${DateFormat.jm().format(noteTime)}';
    } else if (noteTime.isAfter(yesterday)) {
      // Yesterday
      return 'Yesterday, ${DateFormat.jm().format(noteTime)}';
    } else {
      // Older dates
      return DateFormat.yMMMd().add_jm().format(noteTime);
    }
  }

  // Build the note item widget
  Widget _buildNoteItem(Note note) {
    return GestureDetector(
      onTap: () => _navigateToEditor(note: note),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8.0),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 4.0,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8.0),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8.0),
                Text(
                  note.title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4.0),
                Text(
                  note.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Text(
                  _formatTimestamp(note.updatedAt?.toIso8601String() ?? ''),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            Positioned(
              bottom: 2.0,
              right: 30.0,
              child: GestureDetector(
                onTap: () => _toggleReminder(note),
                child: Icon(
                  Icons.notifications,
                  color: note.hasReminder ? Colors.blue : Colors.grey,
                  size: 20,
                ),
              ),
            ),
            Positioned(
              bottom: 2.0,
              right: 2.0,
              child: GestureDetector(
                onTap: () => _deleteNoteConfirm(note.id!),
                child: const Icon(Icons.delete, color: Colors.grey, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Toggle reminder for a note
  Future<void> _toggleReminder(Note note) async {
    if (note.hasReminder) {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Reminder?'),
          content: const Text('Are you sure you want to delete the reminder?'),
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

      // Delete reminder if confirmed
      if (confirm == true) {
        try {
          await _dbHelper.deleteReminder(note.id!);
          await _dbHelper.updateNoteReminderStatus(note.id!, false);
          setState(() {
            note.hasReminder = false;
          });
          // Show success SnackBar for deleting reminder
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Reminder deleted successfully.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error deleting reminder: $e',
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
    } else { // Add a new reminder
      DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(minutes: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime(2100),
      );

      if (pickedDate != null) {
        TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );

        if (pickedTime != null) {
          DateTime reminderDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );

          // Ask if the user wants to add a location
          bool? addLocation = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Add Location'),
              content: const Text(
                  'Would you like to add a location to this reminder?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Yes'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('No'),
                ),
              ],
            ),
          );

          String? location;
          if (addLocation == true) {
            // Prompt for location with loading indicator
            location = await _promptForLocation();
          }

          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            try {
              Reminder reminder = Reminder(
                id: DateTime.now().millisecondsSinceEpoch, // Ensure unique ID
                noteId: note.id!,
                userId: user.id,
                reminderTime: reminderDateTime,
                location: location,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

              await _dbHelper.insertReminder(reminder);
              await _dbHelper.updateNoteReminderStatus(note.id!, true);
              setState(() {
                note.hasReminder = true;
              });
              // Show success SnackBar for adding reminder
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Reminder added successfully.',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Error adding reminder: $e',
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
      }
    }
  }

  // Show date and time picker
  Future<DateTime?> showDateTimePicker(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(minutes: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        return DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      }
    }
    return null;
  }

  // Prompt for location
  Future<String?> _promptForLocation() async {
    String? location;
    
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  // Show loading dialog
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) {
                      return Dialog(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                  );

                  try {
                    // Check location permissions
                    LocationPermission permission = await Geolocator.checkPermission();
                    if (permission == LocationPermission.denied || 
                        permission == LocationPermission.deniedForever) {
                      permission = await Geolocator.requestPermission();
                      if (permission != LocationPermission.whileInUse && 
                          permission != LocationPermission.always) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Location permissions are denied',
                              style: TextStyle(color: Colors.white),
                            ),
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        Navigator.of(context).pop(); // Close loading dialog
                        return;
                      }
                    }

                    // Get current position
                    Position position = await Geolocator.getCurrentPosition(
                        desiredAccuracy: LocationAccuracy.high);

                    // Convert position to address using Geocoding
                    List<Placemark> placemarks = await placemarkFromCoordinates(
                        position.latitude, position.longitude);
                    if (placemarks.isNotEmpty) {
                      Placemark placemark = placemarks.first;
                      location =
                          '${placemark.street}, ${placemark.locality}, ${placemark.country}';
                    } else {
                      location =
                          'Lat: ${position.latitude}, Lon: ${position.longitude}';
                    }

                    Navigator.of(context).pop(); // Close loading dialog
                    Navigator.of(context).pop(); // Close main dialog
                  } catch (e) {
                    Navigator.of(context).pop(); // Close loading dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Error getting location: $e',
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
                },
                child: const Text('Use Current Location'),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  // Manual entry
                  String? manualLocation;
                  TextEditingController controller = TextEditingController();
                  await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Enter Location'),
                      content: TextField(
                        controller: controller,
                        decoration:
                            const InputDecoration(hintText: 'Enter location'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            manualLocation = controller.text;
                            Navigator.of(context).pop();
                          },
                          child: const Text('OK'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  );
                  if (manualLocation != null && manualLocation!.isNotEmpty) {
                    location = manualLocation;
                    Navigator.of(context).pop(); // Close main dialog
                  }
                },
                child: const Text('Enter Manually'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    return location;
  }

  Future<String?> _getCurrentLocation() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, prompt the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location services are disabled.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }

    // Check location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location permissions are denied.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return null;
      }
    }

    // Check if location permissions are permanently denied
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location permissions are denied.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }

    // Get the current position
    Position position = await Geolocator.getCurrentPosition();
    return '${position.latitude},${position.longitude}';
  }

  // Build the UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField( // Search bar
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search notes',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white54),
                ),
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
              )
            : Text(
                _selectedFolder?.name ?? 'Notes',
                style: const TextStyle(color: Colors.white),
              ),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          _isSearching
              ? IconButton( // Clear search query
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchQuery = '';
                      _searchController.clear();
                      _refreshNoteList();
                    });
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),
          IconButton( // Logout button
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () {// Sign out and navigate to login screen
                        Supabase.instance.client.auth.signOut();
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/',
                          (route) => false,
                        );
                      },
                      child: const Text('Yes'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('No'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(), // Drawer with folders
      body: _notes.isEmpty
          ? Center(
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  border: Border.all(color: Colors.blue, width: 2.0),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No notes available. Tap ',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    Icon(Icons.add, size: 16, color: Colors.white),
                    Text(
                      ' to add a new note.',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.builder(
                itemCount: _notes.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // Number of columns
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                  childAspectRatio: 3 / 4, // Width / Height ratio
                ),
                itemBuilder: (context, index) => _buildNoteItem(_notes[index]),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditor(),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add Note',
      ),
    );
  }
}
