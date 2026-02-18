/// ECU protokol bilgilerini ve request tanımlarını içeren model
class EcuProtocolConfig {
  final String ecuName;
  final OBDConfig? obd;
  final String endian;
  final List<RequestDefinition> requests;

  EcuProtocolConfig({
    required this.ecuName,
    this.obd,
    required this.endian,
    required this.requests,
  });

  factory EcuProtocolConfig.fromJson(Map<String, dynamic> json) {
    return EcuProtocolConfig(
      ecuName: json['ecuname'] as String? ?? '',
      obd:
          json['obd'] != null
              ? OBDConfig.fromJson(json['obd'] as Map<String, dynamic>)
              : null,
      endian: json['endian'] as String? ?? 'Big',
      requests:
          (json['requests'] as List<dynamic>? ?? [])
              .map((r) => RequestDefinition.fromJson(r as Map<String, dynamic>))
              .toList(),
    );
  }
}

/// OBD protokol ayarları
class OBDConfig {
  final int baudrate;
  final String protocol;
  final String recvId;
  final String sendId;
  final String funcname;
  final String funcaddr;

  OBDConfig({
    required this.baudrate,
    required this.protocol,
    required this.recvId,
    required this.sendId,
    required this.funcname,
    required this.funcaddr,
  });

  factory OBDConfig.fromJson(Map<String, dynamic> json) {
    return OBDConfig(
      baudrate: json['baudrate'] as int? ?? 10400,
      protocol: json['protocol'] as String? ?? 'CAN',
      recvId: json['recv_id'] as String? ?? '',
      sendId: json['send_id'] as String? ?? '',
      funcname: json['funcname'] as String? ?? '',
      funcaddr: json['funcaddr'] as String? ?? '',
    );
  }
}

/// Request tanımı
class RequestDefinition {
  final String name;
  final String sentbytes;
  final String replybytes;
  final int minbytes;
  final bool manualsend;
  final Map<String, dynamic>? receivebyteDatitems;
  final Map<String, dynamic>? sendbyteDatitems;

  RequestDefinition({
    required this.name,
    required this.sentbytes,
    required this.replybytes,
    required this.minbytes,
    this.manualsend = false,
    this.receivebyteDatitems,
    this.sendbyteDatitems,
  });

  factory RequestDefinition.fromJson(Map<String, dynamic> json) {
    return RequestDefinition(
      name: json['name'] as String? ?? '',
      sentbytes: json['sentbytes'] as String? ?? '',
      replybytes: json['replybytes'] as String? ?? '',
      minbytes: json['minbytes'] as int? ?? 0,
      manualsend: json['manualsend'] as bool? ?? false,
      receivebyteDatitems:
          json['receivebyte_dataitems'] as Map<String, dynamic>?,
      sendbyteDatitems: json['sendbyte_dataitems'] as Map<String, dynamic>?,
    );
  }
}
