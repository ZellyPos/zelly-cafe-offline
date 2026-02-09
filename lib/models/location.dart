class Location {
  final int? id;
  final String name;

  Location({this.id, required this.name});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name};
  }

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(id: map['id'], name: map['name']);
  }
}
