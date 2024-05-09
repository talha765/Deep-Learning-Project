import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart'; 
import 'package:flutter/services.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Attendance System',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;
  String recognizedFaces = '';
  String errorMessage = '';
  Uint8List? output;
  List<String> recognizedNames = [];

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final res = await picker.pickImage(source: ImageSource.gallery);

    if (res != null) {
      _image = File(res.path);
      await recognizeFaces();
    } else {
      print('No image selected.');
    }
  }

  Future<void> takeAndSendPicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      _image = File(pickedFile.path);
      await recognizeFaces();
    } else {
      print('No image selected.');
    }
  }

  Future<void> recognizeFaces() async {
    const apiUrl = 'http://10.1.146.205:5000/recognize';
    String img;

    if (_image != null) {
      Uint8List fileBytes = _image!.readAsBytesSync();
      var fparts = _image!.path.split('/').last.split('.');
      var ext = fparts.last;
      img = 'data:image/$ext;base64,${base64Encode(fileBytes)}';

      try {
        final res = await http.post(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({"image": img}),
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          String base64Image = data["image"].split(',').last;
          Uint8List bytes = base64Decode(base64Image);

          List<String> faces = List<String>.from(data["recognized_faces"]);
          faces.removeWhere((name) => name.trim().toLowerCase() == "unknown");

          setState(() {
            //recognizedFaces = 'Recognized faces: ${faces.isNotEmpty ? faces.join(', ') : "No known faces recognized"}';
            recognizedNames = faces;
            output = bytes;
          });
        } else {
          setState(() {
            errorMessage = 'Error: ${res.statusCode}';
          });
        }
      } catch (e) {
        setState(() {
          errorMessage = 'Error: $e';
        });
      }
    } else {
      throw Exception("Error: _image is null");
    }
  }

  Future<void> generateAndSavePdf(List<String> names, Uint8List image) async {
  final pdf = pw.Document();
  final imageProvider = pw.MemoryImage(image);

  // Get today's date and day
  final now = DateTime.now();
  final DateFormat formatter = DateFormat('dd-MM-yyyy');
  final String formattedDate = formatter.format(now);
  final String formattedDay = DateFormat('EEEE').format(now);

  // Instructor's name
  final String instructorName = 'Dr. Ali Imran Sandhu';

  pdf.addPage(
    pw.Page(
      build: (pw.Context context) {
        return pw.ListView(
          children: [
            // Add date, day, and instructor's name
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Date: $formattedDate', style: pw.TextStyle(fontSize: 12)),
                pw.Text('Day: $formattedDay', style: pw.TextStyle(fontSize: 12)),
              ],
            ),
            pw.Text('Instructor: $instructorName', style: pw.TextStyle(fontSize: 12)),
            pw.Divider(),
            pw.Text('Students Present:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            for (var name in names)
              pw.Text(name, style: pw.TextStyle(fontSize: 15)),
            pw.Image(imageProvider),
          ],
        );
      },
    ),
  );

  final pdfBytes = await pdf.save();
  await Printing.sharePdf(bytes: pdfBytes, filename: 'Attendance.pdf');
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Smart Attendance System', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4CAF50), Color(0xFF2196F3)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('GIK Institute', style: TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 40.0),
              ElevatedButton(
                onPressed: pickImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                    side: BorderSide(color: Colors.blue, width: 2.0),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 30.0, vertical: 15.0),
                  elevation: 5,
                ),
                child: Text('Pick Image', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 20.0),
              if (recognizedFaces.isNotEmpty)
                Text(recognizedFaces, style: TextStyle(color: Colors.white, fontSize: 16)),
              if (errorMessage.isNotEmpty)
                Text(errorMessage, style: TextStyle(color: Colors.red, fontSize: 16)),
              if (output != null)
                Image.memory(output!, fit: BoxFit.cover, height: 200, width: 200),
              SizedBox(height: 20.0),
              ElevatedButton(
                onPressed: output != null ? () => generateAndSavePdf(recognizedNames, output!) : null,
                child: Text('Generate PDF'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: takeAndSendPicture,
        child: Icon(Icons.camera_alt),
      ),
    );
  }
}
