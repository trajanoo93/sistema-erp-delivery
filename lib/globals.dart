// globals.dart
const Map<int, String> users = {
  7: 'Alline',
  73: 'Carlos Júnior',
  77: 'Maria Eduarda',
  78: 'Cássio Vinicius',
  100: 'Freelancer 1',
  52: 'Luciene'
};

// NOVO: mapa reverso (nome → ID)
final Map<String, int> userIds = users.map((id, name) => MapEntry(name, id));