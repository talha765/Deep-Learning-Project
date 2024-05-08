import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  Future<void> recognizeFaces() async {
    const apiUrl = 'http://10.1.144.71:5000/recognize';
    String img;

    if (_image != null) {
      Uint8List fileBytes = _image!.readAsBytesSync();
      var fparts = _image!.path.split('/').last.split('.');
      var ext = fparts.last;
      img = 'data:image/$ext;base64,${base64Encode(fileBytes)}';
    } else {
      throw Exception("Error: _image is null");
    }

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
          recognizedFaces = 'Recognized faces: ${faces.isNotEmpty ? faces.join(', ') : "No known faces recognized"}';
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
  }

  Future<void> generateAndSavePdf(List<String> names, Uint8List image) async {
    final pdf = pw.Document();
    final imageProvider = pw.MemoryImage(image);

    try {
      final file = File('recognized_names.txt');
      await file.writeAsString(names.join('\n'));
    } catch (e) {
      print('Error saving recognized names: $e');
    }

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.ListView.builder(
            itemCount: names.length,
            itemBuilder: (context, index) => pw.Column(
              children: [
                pw.Text(names[index], style: pw.TextStyle(fontSize: 10)),
                pw.Padding(padding: const pw.EdgeInsets.all(5)),
                //pw.Image(imageProvider, height: 200, width: 200),
                //pw.Divider(color: PdfColors.black),
              ],
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'RecognizedFaces.pdf');
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
    );
  }
}
