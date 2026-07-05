import 'package:http/http.dart' as http;

abstract class BaseScraper {
  String get name;
  
  Future<List<Map<String, dynamic>>> search(String query);
  
  Future<String> fetchHtml(String url, {Map<String, String>? headers}) async {
    final defaultHeaders = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    };
    
    final response = await http.get(
      Uri.parse(url),
      headers: {...defaultHeaders, ...?headers},
    );
    
    if (response.statusCode == 200) {
      return response.body;
    }
    throw Exception('Failed to fetch: ${response.statusCode}');
  }
  
  Future<String> postHtml(String url, {Map<String, String>? headers, String? body}) async {
    final defaultHeaders = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    };
    
    final response = await http.post(
      Uri.parse(url),
      headers: {...defaultHeaders, ...?headers},
      body: body,
    );
    
    if (response.statusCode == 200) {
      return response.body;
    }
    throw Exception('Failed to post: ${response.statusCode}');
  }
}
