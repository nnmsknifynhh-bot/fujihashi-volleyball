class Player {
  final String id;
  String name;
  String number;
  String team; // 'A' or 'B'
  int sortOrder;

  Player({
    required this.id,
    required this.name,
    this.number = '',
    this.team = 'A',
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'number': number,
        'team': team,
        'sortOrder': sortOrder,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'],
        name: json['name'],
        number: json['number'] ?? '',
        team: json['team'] ?? 'A',
        sortOrder: json['sortOrder'] ?? 0,
      );
}
