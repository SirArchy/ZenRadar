class MatchaProduct {
  final String id;
  final String name;
  final String site;
  final String url;
  final bool isInStock;
  final DateTime lastChecked;
  final String? price;
  final String? imageUrl;

  MatchaProduct({
    required this.id,
    required this.name,
    required this.site,
    required this.url,
    required this.isInStock,
    required this.lastChecked,
    this.price,
    this.imageUrl,
  });

  factory MatchaProduct.fromJson(Map<String, dynamic> json) {
    return MatchaProduct(
      id: json['id'],
      name: json['name'],
      site: json['site'],
      url: json['url'],
      isInStock: json['isInStock'] == 1,
      lastChecked: DateTime.parse(json['lastChecked']),
      price: json['price'],
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'site': site,
      'url': url,
      'isInStock': isInStock ? 1 : 0,
      'lastChecked': lastChecked.toIso8601String(),
      'price': price,
      'imageUrl': imageUrl,
    };
  }

  MatchaProduct copyWith({
    String? id,
    String? name,
    String? site,
    String? url,
    bool? isInStock,
    DateTime? lastChecked,
    String? price,
    String? imageUrl,
  }) {
    return MatchaProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      site: site ?? this.site,
      url: url ?? this.url,
      isInStock: isInStock ?? this.isInStock,
      lastChecked: lastChecked ?? this.lastChecked,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class UserSettings {
  final int checkFrequencyHours;
  final String startTime; // "08:00"
  final String endTime; // "20:00"
  final bool notificationsEnabled;
  final List<String> enabledSites;

  UserSettings({
    this.checkFrequencyHours = 6,
    this.startTime = "08:00",
    this.endTime = "20:00",
    this.notificationsEnabled = true,
    this.enabledSites = const ["tokichi", "marukyu", "ippodo"],
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      checkFrequencyHours: json['checkFrequencyHours'] ?? 6,
      startTime: json['startTime'] ?? "08:00",
      endTime: json['endTime'] ?? "20:00",
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      enabledSites: List<String>.from(
        json['enabledSites'] ?? ["tokichi", "marukyu", "ippodo"],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'checkFrequencyHours': checkFrequencyHours,
      'startTime': startTime,
      'endTime': endTime,
      'notificationsEnabled': notificationsEnabled,
      'enabledSites': enabledSites,
    };
  }

  UserSettings copyWith({
    int? checkFrequencyHours,
    String? startTime,
    String? endTime,
    bool? notificationsEnabled,
    List<String>? enabledSites,
  }) {
    return UserSettings(
      checkFrequencyHours: checkFrequencyHours ?? this.checkFrequencyHours,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      enabledSites: enabledSites ?? this.enabledSites,
    );
  }
}
