import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';


class VirtualTeacherService {
  static String _apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
  static const String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  Future<String> getFeedback({
    required String instrument,
    required int durationInSeconds,
    required String notes,
  }) async {
    final int minutes = (durationInSeconds / 60).round();

final String systemPrompt = '''
    Musika irakasle aditua, hurbila eta zuzena zara. Zure ikaslearekin ari zara hizketan aurrez aurre.
    Zure helburua ikaslearen azken entsegua aztertu eta feedback oso zehatza eta laburra ematea da, euskaraz.
    
    ARAU ZORROTZAK:
    - Ez egin sarrerarik, ez agurrik, ezta "Kaixo" ere. Joan zuzenean mamiari.
    - Ez luzatu azalpen teorikoekin. Ikasleak badaki zer den musika; esan soilik NOLA konpondu arazoa.
    - Erabili tonu motibatzailea baina zorrotza (irakasle ona bezala).
    - Gehienez 3 paragrafo labur erabili.
    
    EGITURA (Ezinbestekoa):
    1. Paragrafoa (Balorazioa): Aipatu saioaren iraupena esaldi bakarrean eta eman animo labur bat.
    2. Paragrafoa (Konponbidea): Ikasleak oharretan aipatutako arazoari irtenbide fisiko edo tekniko zuzena eman (Adibidez: presioa, embokadura, posizioa...).
    3. Paragrafoa (Ariketa): Eman hurrengo saiorako ariketa edo pauso oso zehatz bat (Adibidez: metronomoa jaitsi, nota luzeak egin...).
    ''';

    final String userPrompt = '''
    - Instrumentua: $instrument
    - Saioaren iraupena: $minutes minutu
    - Ikaslearen oharrak: "$notes"
    ''';

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile', 
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt}
          ],
          'temperature': 0.7, // Sormen apur bat aholkuetarako
        }),
      );

      if (response.statusCode == 200) {
        // UTF-8 garrantzitsua da euskarazko karaktereak (ñ, azentuak) ondo irakurtzeko
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'].trim();
      } else {
        print('Errorea Groq APIarekin: ${response.statusCode} - ${response.body}');
        return 'Zerbitzaria saturatuta dago une honetan. Jarraitu praktikatzen!';
      }
    } catch (e) {
      print('HTTP Excepcion: $e');
      return 'Arazo bat egon da irakasle birtualarekin konektatzean. Egiaztatu konexioa.';
    }
  }

  // BERRIA: Errutinak automatikoki sortzeko funtzioa (JSON itzultzen du)
  Future<List<Map<String, dynamic>>?> generateRoutine({
    required String instrument,
    required int totalMinutes,
    required String focus,
  }) async {
    final String systemPrompt = '''
    Musika irakasle aditua zara. Zure helburua ikaslearentzat entsegu errutina matematiko eta egituratu bat sortzea da.
    
    ARAU ZORROTZAK:
    - ERANTZUN BAKARRIK JSON FORMATUAN. Ez idatzi sarrerarik, ez agurrik, ez markdown (```json) etiketarik. Sormenik ez.
    - JSON-a array bat izan behar da, barruan ariketa bakoitzaren objektuekin.
    - Ariketa guztien "durationMinutes" batuketak ZEHATZ-MEHATZ $totalMinutes minutu izan behar ditu.
    - Izenak eta azalpenak euskaraz izan behar dira.

    JSON EGITURA ESPERO DENA:
    [
      {
        "name": "Nota luzeak eta beroketa",
        "durationMinutes": 10,
        "description": "Birikak irekitzeko eta soinu garbia bilatzeko ariketa."
      },
      {
        "name": "Eskalak",
        "durationMinutes": 15,
        "description": "Do nagusiko eta La minorreko eskalak bi zortzidunetan."
      }
    ]
    ''';

    final String userPrompt = '''
    Mesedez, sortu errutina bat datu hauekin:
    - Instrumentua: $instrument
    - Helburua: $focus
    - Denbora osoa: $totalMinutes minutu
    ''';

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt}
          ],
          'temperature': 0.2, // Tenperatura oso baxua JSON-a ez apurtzeko
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        String rawContent = data['choices'][0]['message']['content'].trim();
        
        // Batzuetan IAk ```json ``` jartzen du nahiz eta ezetz esan. Hori garbitu behar da.
        if (rawContent.startsWith('```json')) {
          rawContent = rawContent.replaceAll('```json', '').replaceAll('```', '').trim();
        }

        // String-a (JSON) Dart-eko Lista batean bihurtu
        final List<dynamic> jsonList = jsonDecode(rawContent);
        
        // Formatu egokira mapeatu
        return jsonList.map((item) => Map<String, dynamic>.from(item)).toList();
        
      } else {
        print('Errorea Groq APIarekin sortzean: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('HTTP Excepcion errutina sortzean: $e');
      return null;
    }
  }

  // BERRIA: Azken saioetako oharrak aztertu eta eboluzio txosten bat sortu
  Future<String> getEvolutionReport({required List<String> pastNotes}) async {
    if (pastNotes.isEmpty) {
      return 'Oraindik ez daukazu aztertzeko ohar nahikorik. Jarraitu entseguko oharrak idazten!';
    }

    final String systemPrompt = '''
    Musika irakasle eta aholkulari pedagogiko aditua zara. 
    Ikasleak bere azken entseguetan idatzitako oharrak aztertuko dituzu joerak eta arazoak bilatzeko.
    Eman eboluzioaren diagnostiko labur, zorrotz eta motibatzaile bat euskaraz.
    
    ARAU ZORROTZAK:
    - Ez egin sarrerarik, ez agurrik ("Kaixo", "Hona hemen..."). Joan zuzenean mamiari.
    - Gehienez 3 paragrafo labur erabili.
    - Erabili tonu hurbila baina profesionala.

    EGITURA:
    1. Paragrafoa (Joera orokorra): Azken egunetako progresioaren balorazioa (indarguneak).
    2. Paragrafoa (Ahulguneak): Oharretan errepikatzen diren arazoak detektatu (embokadura, airearen kontrola, erritmoa, nekea...). Esan NOLA hobetu.
    3. Paragrafoa (Aholku nagusia): Hurrengo asterako helburu estrategiko bat proposatu.
    ''';

    // Ohar guztiak testu bakarrean batu lista gisa bidaltzeko
    final String userPrompt = 'Hona hemen nire azken saioetako ohar errealak:\n' + 
        pastNotes.map((nota) => '- "$nota"').join('\n');

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt}
          ],
          'temperature': 0.5, // Oreka analisia eta sormen pedagogikoaren artean
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'].trim();
      } else {
        print('Errorea Groq APIarekin txostena sortzean: ${response.statusCode}');
        return 'Ezin izan da txostena sortu une honetan. Jarraitu jotzen!';
      }
    } catch (e) {
      print('HTTP Excepcion txostenean: $e');
      return 'Konexio arazo bat egon da irakaslearekin. Ziurtatu internet baduzula.';
    }
  }
}

