import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart'; // <-- IMPORTANTE PARA LEER LA FOTO

class VehiculoService {
  static const String baseUrl =
      'https://cresal-backend-dev.onrender.com/api/v1/vehiculos';

  // 1. GET: Se mantiene exactamente igual
  Future<String> obtenerSiguienteIngreso() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/siguiente-ingreso'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['siguiente_ingreso'];
      }
      return "ERROR";
    } catch (e) {
      print("Error de conexión: $e");
      return "ERROR";
    }
  }

  Future<Map<String, dynamic>?> buscarDatosPorPatente(String patente) async {
    try {
      // Ajusta esta URL a la ruta exacta donde viva tu scraping en FastAPI
      final url = Uri.parse('$baseUrl/scraping/$patente');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Retornamos el diccionario JSON con los datos del vehículo
        return json.decode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      print("Error en scraping: $e");
      return null;
    }
  }

  // 2. POST MULTIPART: La nueva forma de enviar datos + foto
  // Fíjate que ahora exige recibir el Map (datos) y el XFile (foto)
  Future<bool> guardarIngreso(
    Map<String, dynamic> datosVehiculo,
    XFile foto,
  ) async {
    try {
      var uri = Uri.parse('$baseUrl/');
      var request = http.MultipartRequest('POST', uri);

      // Compartimento 1: Empaquetamos todo tu JSON en un solo campo de texto llamado 'datos'
      request.fields['datos'] = jsonEncode(datosVehiculo);

      // Compartimento 2: Leemos la foto y la empaquetamos como un archivo binario
      var bytes = await foto.readAsBytes();
      var multipartFile = http.MultipartFile.fromBytes(
        'foto', // Así se llamará el campo que Python va a recibir
        bytes,
        filename: foto
            .name, // Mantiene el nombre original del archivo (ej: imagen.jpg)
      );
      request.files.add(multipartFile);

      // Disparamos el misil al backend
      var streamedResponse = await request.send();

      // Traducimos la respuesta del servidor para poder leerla
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print("Error del backend: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error de conexión: $e");
      return false;
    }
  }
}
