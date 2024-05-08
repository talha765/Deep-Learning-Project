from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import pickle
import cv2  
import numpy as np
from mtcnn.mtcnn import MTCNN
from keras_facenet import FaceNet
import base64
import re
import sys
sys.stdout.reconfigure(encoding='utf-8')

app = Flask(__name__)
CORS(app)

# Load known faces data from the saved file
try:
    with open('known_faces.pkl', 'rb') as f:
        mean_known_faces = pickle.load(f)
except FileNotFoundError:
    mean_known_faces = {}

# Initialize face detector and feature extractor
# detector = MTCNN()
detector = MTCNN()
embedder = FaceNet()

# Define the similarity threshold for face recognition
THRESHOLD = 1.0

def recognize_faces(image_path, detector):
    # print(image_path)
    try:
       # global detector

        # image_path = os.path.join('C:/Users/hp/Downloads/dlproject/dlproject/12ab/Testpic.jpg')

        img = cv2.cvtColor(cv2.imread(image_path), cv2.COLOR_BGR2RGB)
        print("abd")
        print(img)

        image= cv2.imread(image_path)

        faces = detector.detect_faces(img)
        print(faces)
        recognized_names = []

        for face in faces:
            x, y, width, height = face['box']
            face_crop = img[y:y+height, x:x+width]
            if face_crop.size == 0:
                continue

            face_features = embedder.embeddings([face_crop])[0]
            min_distance = float('inf')
            recognized_name = 'Unknown'

            for name, known_features in mean_known_faces.items():
                distance = np.linalg.norm(face_features - known_features)
                if distance < min_distance:
                    min_distance = distance
                    recognized_name = name

            if min_distance <= THRESHOLD:
                recognized_names.append(recognized_name)
            else:
                recognized_names.append('Unknown')
            
            print(f"Recognized face: {recognized_name} with distance {min_distance}")
            cv2.rectangle(image, (x, y), (x+width, y+height), (0, 255, 0), 2)
            cv2.putText(image, recognized_name, (x, y-10), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 0), 2)

        return recognized_names,image
    except Exception as e:
        print(f"Error processing image: {e}")
        return []

@app.route('/recognize', methods=['POST'])
def recognize():
    try:
        # print(request.data)
        if 'image' not in request.json:
            return jsonify({'error': 'No image data provided'}), 400
        
        image_data = request.json['image']
        image_data_match = re.match(r'data:image/(\w+);base64,(.*)', image_data)
        if not image_data_match:
            return jsonify({'error': 'Invalid image data format'}), 400
        
        image_extension = image_data_match.group(1)
        image_data_decoded = base64.b64decode(image_data_match.group(2))
        
        # Save the image
        
        image_path = os.path.join('C:/TempDL/', f'test123.{image_extension}')
        with open(image_path, 'wb') as f:
            f.write(image_data_decoded)

        # image_path = os.path.join('C:/Users/hp/Downloads/dlproject/dlproject/12ab/Testpic.jpg')

        recognized_faces,image = recognize_faces(image_path, detector)
        if not recognized_faces:
            raise ValueError('Face recognition failed or no faces found')

        encoded_image = base64.b64encode(cv2.imencode(f".{image_extension}", image)[1]).decode()

        # return jsonify({'recognized_faces': "test"})
        return jsonify({'recognized_faces': recognized_faces,'image':f"data:image/{image_extension};base64,{encoded_image}"})

    except Exception as e:
        print(f"Error in /recognize endpoint: {e}")
        return jsonify({'error': f"Error in /recognize endpoint: {e}"}), 500

@app.route('/test', methods=['GET'])
def test_endpoint():
    return jsonify({'status': 'success'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

