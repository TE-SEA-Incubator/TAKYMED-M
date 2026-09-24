
class Dose {
  final int id;
  final String medicationName;
  final String clientName;
  final double dose;
  final String time;
  final String scheduledAt;
  final bool statusTaken;

  Dose({
    required this.id,
    required this.medicationName,
    required this.clientName,
    required this.dose,
    required this.time,
    required this.scheduledAt,
    required this.statusTaken,
  });

  factory Dose.fromJson(Map<String, dynamic> json) {
    return Dose(
      id: json['id'],
      medicationName: json['medicationName'],
      clientName: json['clientName'],
      dose: json['dose'] is int ? json['dose'].toDouble() : json['dose'] as double,
      time: json['time'],
      scheduledAt: json['scheduledAt'],
      statusTaken: json['statusTaken'] is int ? json['statusTaken'] == 1 : json['statusTaken'] as bool,
    );
  }
}
