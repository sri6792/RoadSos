// lib/models/models.dart

class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relation;
  final bool isPrimary;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
    this.isPrimary = false,
  });
}

class NearbyService {
  final String id;
  final String name;
  final String address;
  final double distance; // km
  final String phone;
  final double rating;
  final bool isOpen;
  final ServiceType type;

  NearbyService({
    required this.id,
    required this.name,
    required this.address,
    required this.distance,
    required this.phone,
    required this.rating,
    required this.isOpen,
    required this.type,
  });
}

enum ServiceType { hospital, police, towing, mechanic }

class UserProfile {
  final String name;
  final String phone;
  final String bloodGroup;
  final String allergies;
  final String medicalConditions;
  final String emergencyNote;

  UserProfile({
    required this.name,
    required this.phone,
    required this.bloodGroup,
    this.allergies = '',
    this.medicalConditions = '',
    this.emergencyNote = '',
  });
}

// Sample data
class SampleData {
  static List<EmergencyContact> contacts = [
    EmergencyContact(
      id: '1',
      name: 'Priya Sharma',
      phone: '+91 98765 43210',
      relation: 'Spouse',
      isPrimary: true,
    ),
    EmergencyContact(
      id: '2',
      name: 'Rahul Sharma',
      phone: '+91 87654 32109',
      relation: 'Brother',
    ),
    EmergencyContact(
      id: '3',
      name: 'Dr. Anita Nair',
      phone: '+91 76543 21098',
      relation: 'Family Doctor',
    ),
  ];

  static List<NearbyService> hospitals = [
    NearbyService(
      id: 'h1',
      name: 'Goa Medical College',
      address: 'Bambolim, Goa',
      distance: 1.2,
      phone: '0832-2458700',
      rating: 4.2,
      isOpen: true,
      type: ServiceType.hospital,
    ),
    NearbyService(
      id: 'h2',
      name: 'Manipal Hospital',
      address: 'Dona Paula, Goa',
      distance: 2.8,
      phone: '0832-2520888',
      rating: 4.5,
      isOpen: true,
      type: ServiceType.hospital,
    ),
    NearbyService(
      id: 'h3',
      name: 'Apollo Clinic',
      address: 'Panaji, Goa',
      distance: 3.5,
      phone: '0832-2224455',
      rating: 4.1,
      isOpen: false,
      type: ServiceType.hospital,
    ),
  ];

  static List<NearbyService> policeStations = [
    NearbyService(
      id: 'p1',
      name: 'Ponda Police Station',
      address: 'Ponda Town, Goa',
      distance: 0.8,
      phone: '0832-2312233',
      rating: 4.0,
      isOpen: true,
      type: ServiceType.police,
    ),
    NearbyService(
      id: 'p2',
      name: 'Panaji Police HQ',
      address: 'Panaji, Goa',
      distance: 4.2,
      phone: '0832-2224488',
      rating: 4.3,
      isOpen: true,
      type: ServiceType.police,
    ),
  ];

  static List<NearbyService> towingServices = [
    NearbyService(
      id: 't1',
      name: 'Goa Auto Rescue',
      address: 'NH 748, Near Ponda',
      distance: 1.5,
      phone: '+91 98500 11122',
      rating: 4.4,
      isOpen: true,
      type: ServiceType.towing,
    ),
    NearbyService(
      id: 't2',
      name: 'Rapid Tow Services',
      address: 'Margao Highway',
      distance: 3.1,
      phone: '+91 87600 33344',
      rating: 3.9,
      isOpen: true,
      type: ServiceType.towing,
    ),
  ];

  static List<NearbyService> mechanics = [
    NearbyService(
      id: 'm1',
      name: 'GoaMech Pro',
      address: 'Ponda Industrial Area',
      distance: 0.6,
      phone: '+91 96700 55566',
      rating: 4.6,
      isOpen: true,
      type: ServiceType.mechanic,
    ),
    NearbyService(
      id: 'm2',
      name: 'Speed Fix Garage',
      address: 'Old Goa Road',
      distance: 2.3,
      phone: '+91 75400 77788',
      rating: 4.2,
      isOpen: false,
      type: ServiceType.mechanic,
    ),
  ];
}
