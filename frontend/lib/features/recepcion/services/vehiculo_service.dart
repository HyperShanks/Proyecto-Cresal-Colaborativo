import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:crypto/crypto.dart'; // ⚠️ NUEVO: Para el cifrado HMAC-SHA256
import 'package:html/parser.dart' as html_parser; // ⚠️ NUEVO: Para leer el HTML

class VehiculoService {
  static const String baseUrl =
      'https://cresal-backend-dev.onrender.com/api/v1/vehiculos';

  // ==========================================
  // 1. GET: Siguiente Ingreso (Se mantiene)
  // ==========================================
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

  // ==========================================
  // 2. EL NUEVO SCRAPING NATIVO EN FLUTTER
  // ==========================================
  // Replicamos la función Python para generar la firma HMAC-SHA256
  String _cifrarData(String mensaje) {
    const secret =
        "b708574124a2742b5eecab4993a7f3e91528b8a99d38e1a663b2fcbe92e38a8c";
    final key = utf8.encode(secret);
    final bytes = utf8.encode(mensaje);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString();
  }

  Future<Map<String, dynamic>?> buscarDatosPorPatente(String patente) async {
    try {
      final patenteLimpia = patente
          .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
          .toUpperCase();

      final Map<String, String> headers = {
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": "es-ES,es;q=0.9",
      };

      // PASO 1: Obtener las Cookies iniciales
      final homeRes = await http.get(
        Uri.parse('https://www.patentechile.com/'),
        headers: headers,
      );
      final rawCookie = homeRes.headers['set-cookie'];
      if (rawCookie != null) {
        // Extraemos solo la primera parte de la cookie de sesión
        headers['cookie'] = rawCookie.split(';')[0];
      }

      headers['Origin'] = 'https://www.patentechile.com';
      headers['Referer'] = 'https://www.patentechile.com/';
      headers['Content-Type'] = 'application/json';

      // PASO 2: Generar Payload y solicitar Token JWT
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
          .toString();
      final valor = 'vehiculo|$patenteLimpia|$timestamp';
      final valorCifrado = _cifrarData(valor);

      final payload = {
        "opt": "vehiculo",
        "valor": patenteLimpia,
        "x": valor,
        "z": valorCifrado,
      };

      final tokenRes = await http.post(
        Uri.parse('https://www.patentechile.com/v3/token'),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (tokenRes.statusCode == 200) {
        final rpta = jsonDecode(tokenRes.body);

        if (rpta['status'] == true && rpta['jwt'] != null) {
          final token = rpta['jwt'];
          headers['Content-Type'] = 'application/x-www-form-urlencoded';
          final payloadToken = 'q=$token';

          // PASO 3: Obtener el HTML con los resultados reales
          final dataRes = await http.post(
            Uri.parse('https://www.patentechile.com/resultados/'),
            headers: headers,
            body: payloadToken,
          );

          if (dataRes.statusCode == 200) {
            // Analizamos el HTML como lo hacía BeautifulSoup en Python
            final document = html_parser.parse(dataRes.body);
            final filas = document.querySelectorAll('tr');

            Map<String, dynamic> datosVehiculo = {
              "marca": "",
              "modelo": "",
              "anio": "",
              "cilindrada": "",
              "numero_motor": "",
            };

            for (var fila in filas) {
              final celdas = fila.querySelectorAll('th, td');
              if (celdas.length >= 2) {
                final etiqueta = celdas[0].text.trim().toLowerCase();
                final valorCelda = celdas[1].text.trim();

                if (etiqueta.contains('marca')) {
                  datosVehiculo['marca'] = valorCelda;
                } else if (etiqueta.contains('modelo')) {
                  datosVehiculo['modelo'] = valorCelda;
                  // Extraemos la cilindrada usando Regex (Ej: "1.6" de "PEUGEOT 208 1.6")
                  final match = RegExp(r'(\d\.\d)').firstMatch(valorCelda);
                  if (match != null)
                    datosVehiculo['cilindrada'] = match.group(1);
                } else if (etiqueta.contains('año') ||
                    etiqueta.contains('ano')) {
                  datosVehiculo['anio'] = valorCelda;
                } else if (etiqueta.contains('motor')) {
                  datosVehiculo['numero_motor'] = valorCelda;
                }
              }
            }

            // Si encontró al menos la marca, consideramos que el scraping fue exitoso
            if (datosVehiculo['marca'] != "") {
              return datosVehiculo;
            }
          }
        }
      }
      return null;
    } catch (e) {
      print("Error en scraping nativo: $e");
      return null;
    }
  }

  // ==========================================
  // 3. POST MULTIPART: Guardar (Se mantiene)
  // ==========================================
  Future<Map<String, dynamic>> guardarIngresoConRespuesta(
    Map<String, dynamic> datosVehiculo,
    XFile foto,
  ) async {
    try {
      var uri = Uri.parse('$baseUrl/');
      var request = http.MultipartRequest('POST', uri);

      request.fields['datos'] = jsonEncode(datosVehiculo);

      var bytes = await foto.readAsBytes();
      var multipartFile = http.MultipartFile.fromBytes(
        'foto',
        bytes,
        filename: foto.name,
      );
      request.files.add(multipartFile);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'exito': true, 'mensaje': 'Guardado exitoso'};
      } else {
        final errorBody = jsonDecode(response.body);
        final mensajeDetail =
            errorBody['detail'] ?? 'Error al guardar el ingreso';
        return {'exito': false, 'mensaje': mensajeDetail};
      }
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión: $e'};
    }
  }
}
