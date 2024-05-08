import 'dart:io' as io;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
// import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:image_picker/image_picker.dart';

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

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final res = await picker.pickImage(source: ImageSource.gallery);

    // print(result);

    if (res != null) {
      // setState(() {
      _image = File(res.path);
      // _image = File(result.files[0].path!);
      // });
      await recognizeFaces();
    } else {
      print('No image selected.');
    }
  }

  Future<void> recognizeFaces() async {
    const apiUrl = 'http://192.168.1.106:5000/recognize';
    print(apiUrl);
    String img;

    if (_image != null) {
      Uint8List fileBytes = _image!.readAsBytesSync();
      // print(fileBytes);

      var fparts = _image!.path.split('/').last.split('.');
      var ext = fparts.last;
      print(ext);

      img = 'data:image/${ext};base64,${base64Encode(fileBytes)}';
      print(img);
      // Now you can use img which contains the base64 encoded string

      // final bytes = io.File(_image!.path).readAsBytesSync();
      // print(bytes);
      // img = base64Encode(bytes);
      // print(img);
    } else {
      throw Exception("Error: _image is null");
    }

    print(img);

// final img

    try {
      final res = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"image": img}),
      );

      // final request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      // request.files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: 'upload.jpg'));

      // final response = await request.send();
      if (res.statusCode == 200) {
        // final result = await res.stream.bytesToString();
        final data = jsonDecode(res.body);
        print(data);

        String base64Image = data["image"].split(',').last;

        // Decode the base64 string
        Uint8List bytes = base64Decode(base64Image);

        // Display the image
        // return;

        setState(() {
          recognizedFaces =
              'Recognized faces: ${List<String>.from(data["recognized_faces"]).join(',')}';
          output = bytes;
        });
        print(recognizedFaces);
      } else {
        print('Error: ${res.statusCode}');
        setState(() {
          errorMessage = 'Error: ${res.statusCode}';
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        errorMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Smart Attendance System',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
              Text('GIK Institute',
                  style: TextStyle(
                      fontSize: 32.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 40.0),
              ElevatedButton(
                onPressed: pickImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                    side: BorderSide(color: Colors.blue, width: 2.0),
                  ),
                  padding:
                      EdgeInsets.symmetric(horizontal: 30.0, vertical: 15.0),
                  elevation: 5,
                ),
                child: Text('Pick Image',
                    style:
                        TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 20.0),
              // if (_image != null) Image.file(_image!, width: 200, height: 200),
              const SizedBox(height: 20.0),
              if (recognizedFaces.isNotEmpty)
                Text(recognizedFaces,
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              if (errorMessage.isNotEmpty)
                Text(errorMessage,
                    style: TextStyle(color: Colors.red, fontSize: 16)),

              if (output != null)
                Image.memory(
                  output!,
                  fit: BoxFit.cover,
                  height: 200,
                  width: 200, // Adjust this as per your need
                )
            ],
          ),
        ),
      ),
    );
  }
}
