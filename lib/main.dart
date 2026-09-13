import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DEKK FOOD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepOrange),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Liste officielle et vérifiée des restaurants de DEKK FOOD
  final List<Map<String, dynamic>> restaurants = const [
    {
      'name': 'Seven Seven Dakar',
      'neighborhood': 'Ngor',
      'cuisine': 'International & Grillades',
      'rating': 4.8,
      'reviews': 2122,
      'price': '3 000 – 10 000 FCFA',
      'phone': '+221 78 593 78 78',
      'whatsapp': '+221 78 593 78 78',
      'image': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4',
      'description': 'Restaurant spécialisé dans la cuisine internationale et les grillades de premier choix à Ngor.',
      'menu': [
        {'name': 'Brochettes géantes de gambas', 'price': '8 500 FCFA', 'desc': 'Gambas fraîches marinées aux herbes.'},
        {'name': 'Filet de zébu sauce poivre', 'price': '7 000 FCFA', 'desc': 'Tendre morceau de zébu et frites.'},
        {'name': 'Jus de Bissap frais', 'price': '1 000 FCFA', 'desc': 'Fait maison à la menthe.'},
      ]
    },
    {
      'name': 'Restaurant Le Lagon 1',
      'neighborhood': 'Plateau',
      'cuisine': 'Française & Poissons',
      'rating': 4.4,
      'reviews': 2345,
      'price': '5 000 – 15 000 FCFA',
      'phone': '+221 33 821 53 22',
      'whatsapp': '+221 33 821 53 22',
      'image': 'https://images.unsplash.com/photo-1544025162-d76694265947',
      'description': 'Gastronomie française et poissons frais avec vue panoramique sur l’océan au Plateau.',
      'menu': [
        {'name': 'Langouste grillée au beurre blanc', 'price': '14 000 FCFA', 'desc': 'Pêche locale du jour.'},
        {'name': 'Fondant au chocolat noir', 'price': '3 500 FCFA', 'desc': 'Cœur coulant maison.'},
      ]
    },
    {
      'name': 'Chez Fatou',
      'neighborhood': 'Almadies',
      'cuisine': 'Sénégalaise & Grillades',
      'rating': 4.0,
      'reviews': 2265,
      'price': '3 000 – 8 000 FCFA',
      'phone': '+221 33 820 92 38',
      'whatsapp': '+221 33 820 92 38',
      'image': 'https://images.unsplash.com/photo-1537047902294-62a40c20a6ae',
      'description': 'La référence incontournable de la cuisine sénégalaise traditionnelle les pieds dans l’eau.',
      'menu': [
        {'name': 'Ceebu Jën (Riz au poisson)', 'price': '3 500 FCFA', 'desc': 'Le plat national authentique.'},
        {'name': 'Poulet Yassa', 'price': '3 000 FCFA', 'desc': 'Poulet mariné oignons et citron.'},
      ]
    },
    {
      'name': 'Reine Margarita',
      'neighborhood': 'Plateau',
      'cuisine': 'Italienne & Pizzeria',
      'rating': 4.4,
      'reviews': 396,
      'price': '3 000 – 7 000 FCFA',
      'phone': '+221 78 444 99 55',
      'whatsapp': '+221 78 444 99 55',
      'image': 'https://images.unsplash.com/photo-1513104890138-7c749659a591',
      'description': 'Authentiques pizzas italiennes cuites au feu de bois et pâtes fraîches au cœur de Dakar.',
      'menu': [
        {'name': 'Pizza Margherita di Bufala', 'price': '5 500 FCFA', 'desc': 'Mozzarella di bufala et basilic frais.'},
        {'name': 'Tiramisu classique', 'price': '3 000 FCFA', 'desc': 'Recette italienne traditionnelle.'},
      ]
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DEKK FOOD - Sénégal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: restaurants.length,
        itemBuilder: (context, index) {
          final r = restaurants[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            elevation: 2,
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(r['image'], width: 60, height: 60, fit: BoxFit.cover),
              ),
              title: Text(r['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${r['neighborhood']} · ⭐ ${r['rating']} (${r['reviews']} avis)'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.deepOrange),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RestaurantDetailScreen(restaurant: r),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class RestaurantDetailScreen extends StatelessWidget {
  final Map<String, dynamic> restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  Future<void> _makePhoneCall(String phone) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phone);
    await launchUrl(launchUri);
  }

  Future<void> _openWhatsApp(String whatsapp) async {
    final Uri uri = Uri.parse('https://wa.me/${whatsapp.replaceAll(RegExp(r'[^0-9]'), '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = restaurant['menu'] as List;

    return Scaffold(
      appBar: AppBar(
        title: Text(restaurant['name'], style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepOrange,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(restaurant['image'], height: 220, width: double.infinity, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(restaurant['name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      Text(' ${restaurant['rating']} (${restaurant['reviews']} avis) · 📍 ${restaurant['neighborhood']}'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('💰 ${restaurant['price']}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),

                  // Boutons d'action rapide
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: () => _makePhoneCall(restaurant['phone']),
                        icon: const Icon(Icons.phone),
                        label: const Text('Appeler'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                        onPressed: () => _openWhatsApp(restaurant['whatsapp']),
                        icon: const Icon(Icons.chat),
                        label: const Text('WhatsApp'),
                      ),
                    ],
                  ),
                  const Divider(height: 30),

                  const Text('À propos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(restaurant['description'], style: const TextStyle(color: Colors.black87, height: 1.4)),
                  const Divider(height: 30),

                  const Text('⭐ Spécialités & Menu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...menu.map((item) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(item['desc']),
                          trailing: Text(item['price'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
