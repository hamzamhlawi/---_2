
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String serverUrl = 'http://node3.serverix.cloud';

void main() {
  runApp(const ZolStoreApp());
}

class ZolStoreApp extends StatelessWidget {
  const ZolStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ZOL STORE',
      locale: const Locale('ar'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF12A878),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF073B2D),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: const StorePage(),
    );
  }
}

class Product {
  final String id;
  final String name;
  final dynamic price;

  const Product({
    required this.id,
    required this.name,
    required this.price,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['id'] ??
              json['code'] ??
              json['product_id'] ??
              json['key'] ??
              '')
          .toString(),
      name: (json['name'] ??
              json['title'] ??
              json['product_name'] ??
              json['label'] ??
              'منتج')
          .toString(),
      price: json['price'] ?? json['price_sdg'] ?? json['amount'],
    );
  }

  bool get hasPrice =>
      price != null && price.toString().trim().isNotEmpty;
}

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  List<Product> products = [];
  bool loading = true;
  String? error;
  String paymentInfo = '';

  @override
  void initState() {
    super.initState();
    loadStore();
  }

  Future<void> loadStore() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$serverUrl/api/products'))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('السيرفر رد برمز ${response.statusCode}');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      dynamic listData = decoded;

      if (decoded is Map) {
        listData = decoded['products'] ??
            decoded['items'] ??
            decoded['data'] ??
            [];
      }

      if (listData is! List) {
        throw Exception('صيغة قائمة المنتجات غير متوقعة');
      }

      final loaded = listData
          .whereType<Map>()
          .map((item) => Product.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((p) => p.id.isNotEmpty)
          .toList();

      String info = '';
      try {
        final paymentResponse = await http
            .get(Uri.parse('$serverUrl/api/payment-info'))
            .timeout(const Duration(seconds: 12));

        if (paymentResponse.statusCode == 200) {
          final data = jsonDecode(
            utf8.decode(paymentResponse.bodyBytes),
          );

          if (data is Map) {
            info = (data['payment_info'] ??
                    data['instructions'] ??
                    data['message'] ??
                    data['details'] ??
                    '')
                .toString();

            if (info.isEmpty) {
              info = data.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join('\n');
            }
          } else {
            info = data.toString();
          }
        }
      } catch (_) {
        info = '';
      }

      if (!mounted) return;
      setState(() {
        products = loaded;
        paymentInfo = info;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'تعذر تحميل المتجر.\nتحقق من اتصال الإنترنت والسيرفر.\n$e';
      });
    }
  }

  void openProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderPage(
          product: product,
          paymentInfo: paymentInfo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'ZOL STORE',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              onPressed: loadStore,
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث المنتجات',
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off,
                              size: 60, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: loadStore,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: loadStore,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF073B2D),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'مرحباً بك في زول ستور 👋',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'اشحن ألعابك وخدماتك الرقمية بسهولة',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'المنتجات المتاحة',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (products.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'لا توجد منتجات لعرضها حالياً.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ...products.map(
                          (product) => Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE0F4EB),
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  color: Color(0xFF087F5B),
                                ),
                              ),
                              title: Text(
                                product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  product.hasPrice
                                      ? 'السعر: ${product.price} ج.س'
                                      : 'السعر غير محدد حالياً',
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_left),
                              onTap: () => openProduct(product),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.payments_outlined),
                            title: const Text('معلومات الدفع'),
                            subtitle: Text(
                              paymentInfo.isEmpty
                                  ? 'تعليمات الدفع غير متاحة حالياً.'
                                  : paymentInfo,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class OrderPage extends StatefulWidget {
  final Product product;
  final String paymentInfo;

  const OrderPage({
    super.key,
    required this.product,
    required this.paymentInfo,
  });

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final recipientController = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    recipientController.dispose();
    super.dispose();
  }

  Future<void> submitOrder() async {
    final recipient = recipientController.text.trim();

    if (recipient.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل ID أو اسم المستلم بشكل صحيح')),
      );
      return;
    }

    setState(() => sending = true);

    try {
      final response = await http
          .post(
            Uri.parse('$serverUrl/api/orders'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'product_id': widget.product.id,
              'recipient': recipient,
            }),
          )
          .timeout(const Duration(seconds: 25));

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map &&
          decoded['ok'] == true) {
        final orderId = decoded['order_id'] ??
            decoded['id'] ??
            decoded['order']?['id'] ??
            'تم الاستلام';

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('تم إرسال الطلب'),
            content: Text('رقم الطلب: $orderId'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      } else {
        final message = decoded is Map
            ? (decoded['error'] ??
                    decoded['message'] ??
                    'لم يتم قبول الطلب')
                .toString()
            : 'استجابة غير متوقعة من السيرفر';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرسال الطلب: $e')),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تأكيد الطلب')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('المنتج المختار'),
                    const SizedBox(height: 8),
                    Text(
                      widget.product.name,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.product.hasPrice
                          ? 'السعر: ${widget.product.price} ج.س'
                          : 'السعر غير محدد — تأكد منه مع الإدارة قبل الدفع',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'بيانات المستلم',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: recipientController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Player ID أو اسم المستخدم',
                hintText: 'أدخل بيانات الحساب المطلوب شحنه',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'لا تدخل كلمة المرور أو رمز تسجيل الدخول الخاص بحسابك.',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 20),
            if (widget.paymentInfo.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('تعليمات الدفع:\n${widget.paymentInfo}'),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: sending ? null : submitOrder,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: sending
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('إرسال الطلب'),
            ),
          ],
        ),
      ),
    );
  }
}
