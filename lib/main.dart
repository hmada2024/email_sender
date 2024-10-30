import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:file_picker/file_picker.dart';

void main() async {
  await Hive.initFlutter();
  await Hive.openBox('emails');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CV Sender',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        hintColor: Colors.amber,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
        buttonTheme: ButtonThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          buttonColor: Colors.blue,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _recipientController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<Map<dynamic, dynamic>> savedEmails = [];
  String? _cvFilePath;

  @override
  void initState() {
    super.initState();
    loadSavedEmails();
  }

  void loadSavedEmails() {
    final emailBox = Hive.box('emails');
    savedEmails = List<Map<dynamic, dynamic>>.from(emailBox.get('emails', defaultValue: []));
    setState(() {});
  }

  void saveEmail(String email, String password) {
    final emailBox = Hive.box('emails');
    savedEmails.add({'email': email, 'password': password});
    emailBox.put('emails', savedEmails);
    setState(() {});
  }

  void deleteEmail(int index) {
    final emailBox = Hive.box('emails');
    savedEmails.removeAt(index);
    emailBox.put('emails', savedEmails);
    setState(() {});
  }

  Future<void> pickCvFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      setState(() {
        _cvFilePath = result.files.single.path;
      });
    }
  }

  void sendEmail(String email, String password, String recipient, String subject, String message, String cv) async {
  // Create the SMTP server using the provided email and password
  final smtpServer = gmail(email, password);

  // Create the email message
  final emailMessage = Message()
    ..from = Address(email)
    ..recipients.add(recipient)
    ..subject = subject
    ..text = message;

  // Attach the CV file if a path is provided
  if (cv.isNotEmpty) {
    emailMessage.attachments.add(FileAttachment(File(cv)));
  }

  try {
    // Send the email message using the smtpServer
    final sendReport = await send(emailMessage, smtpServer);
    if (kDebugMode) {
      print('Message sent: $sendReport');
    }
    
    // Show success message to the user
    if (mounted) {
      showEmailStatus(context, 'Email sent successfully.');
    }
  } on MailerException catch (e) {
    String errorMsg = 'Email not sent.';

    // Check specific error codes and set error message accordingly
    if (e.problems.any((p) => p.code == 'invalid-email')) {
      errorMsg = 'Invalid email address.';
    } else if (e.problems.any((p) => p.code == 'auth')) {
      errorMsg = 'Authentication failed. Check your email and password.';
    } else if (e.problems.any((p) => p.code == 'recipient')) {
      errorMsg = 'Invalid recipient email address.';
    } else if (e.problems.any((p) => p.code == 'network')) {
      errorMsg = 'Network error. Please try again.';
    } else {
      errorMsg = 'An unexpected error occurred: ${e.toString()}';
    }

    // Show error message to the user
    if (mounted) {
      showEmailStatus(context, errorMsg);
    }

    // Log the specific problems for debugging
    for (var p in e.problems) {
      if (kDebugMode) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    }
  } catch (e) {
    // Handle unexpected errors
    if (mounted) {
      showEmailStatus(context, 'An unexpected error occurred: $e');
    }
    if (kDebugMode) {
      print('Unexpected error: $e');
    }
  }
}



  void showEmailStatus(BuildContext context, String message) {
  final snackBar = SnackBar(
    content: Text(message),
    action: SnackBarAction(
      label: 'Dismiss',
      onPressed: () {
        // يتم تنفيذ هذا عند الضغط على "تجاهل"
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      },
    ),
    duration: const Duration(days: 365), // تجعل الإشعار دائم حتى يتم تجاهله
  );

  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CV Sender'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ManageEmailsPage(savedEmails: savedEmails, deleteEmail: deleteEmail)),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton(
                onPressed: pickCvFile,
                child: const Text('Choose CV File'),
              ),
              if (_cvFilePath != null) Text('Selected File: $_cvFilePath'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: 'Subject'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the subject';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(labelText: 'Message'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the message';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _recipientController,
                decoration: const InputDecoration(labelText: 'Recipient Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the recipient email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Your Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Your Email Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate() && _cvFilePath != null) {
                    final email = _emailController.text;
                    final password = _passwordController.text;
                    final recipient = _recipientController.text;
                    final subject = _subjectController.text;
                    final message = _messageController.text;
                    final cv = _cvFilePath!;

                    saveEmail(email, password);
                    sendEmail(email, password, recipient, subject, message, cv);
                  } else {
                    showEmailStatus(context, 'Please fill all fields and select a CV file.');
                  }
                },
                child: const Text('Send Email'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Saved Emails:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: savedEmails.length,
                  itemBuilder: (context, index) {
                    final email = savedEmails[index]['email']!;
                    return ListTile(
                      title: Text(email),
                      trailing: IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () {
                          if (_formKey.currentState!.validate() && _cvFilePath != null) {
                            final email = savedEmails[index]['email']!;
                            final password = savedEmails[index]['password']!;
                            final recipient = _recipientController.text;
                            final subject = _subjectController.text;
                            final message = _messageController.text;
                            final cv = _cvFilePath!;

                            sendEmail(email, password, recipient, subject, message, cv);
                          } else {
                            showEmailStatus(context, 'Please fill all fields and select a CV file.');
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ManageEmailsPage extends StatelessWidget {
  final List<Map<dynamic, dynamic>> savedEmails;
  final Function(int) deleteEmail;

  const ManageEmailsPage({super.key, required this.savedEmails, required this.deleteEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Emails'),
      ),
      body: ListView.builder(
        itemCount: savedEmails.length,
        itemBuilder: (context, index) {
          final email = savedEmails[index]['email']!;
          return ListTile(
            title: Text(email),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                deleteEmail(index);
                Navigator.pop(context);
              },
            ),
          );
        },
      ),
    );
  }
}
