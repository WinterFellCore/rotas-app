/// Modelo de Endereço baseado na tabela `enderecos` do SQLite
class Endereco {
  final int id;
  final String codIbge;
  final int logradouroId;
  final String? numero;
  final int? numeroInt;
  final String? modificador;
  final String? complemento;
  final String? bairro;
  final String? cep;
  final double? lat;
  final double? lon;
  final int? precisao;
  final int? especie;
  final int? tipoEdificacao;
  final String? estabelecimento;
  final int? numQuadra;
  final int? numFace;
  final String? codSetor;
  final String? cepFonte;
  final int? malhaNo;
  final double? malhaMetros;
  final String origem;
  final String? codUnicoCnefe;
  final String? chaveCnefe;
  final bool verificado;
  final bool ativo;
  final String? obs;
  final DateTime criadoEm;
  final DateTime atualizadoEm;
  
  // Campos derivados/joinados
  final String? logradouroNome;
  final String? logradouroCompleto;
  final String? enderecoFormatado;

  const Endereco({
    required this.id,
    required this.codIbge,
    required this.logradouroId,
    this.numero,
    this.numeroInt,
    this.modificador,
    this.complemento,
    this.bairro,
    this.cep,
    this.lat,
    this.lon,
    this.precisao,
    this.especie,
    this.tipoEdificacao,
    this.estabelecimento,
    this.numQuadra,
    this.numFace,
    this.codSetor,
    this.cepFonte,
    this.malhaNo,
    this.malhaMetros,
    required this.origem,
    this.codUnicoCnefe,
    this.chaveCnefe,
    required this.verificado,
    required this.ativo,
    this.obs,
    required this.criadoEm,
    required this.atualizadoEm,
    this.logradouroNome,
    this.logradouroCompleto,
    this.enderecoFormatado,
  });

  /// Converte uma linha do SQLite ou um JSON da API.
  ///
  /// Tolerante a tipos: SQLite pode devolver inteiro onde se espera double,
  /// e a API pode omitir campos ou mandar booleanos/números como texto.
  factory Endereco.fromMap(Map<String, dynamic> map) {
    final id = _int(map['id']);
    if (id == null) {
      throw FormatException('Endereço sem id: $map');
    }

    return Endereco(
      id: id,
      codIbge: _str(map['cod_ibge']) ?? '',
      logradouroId: _int(map['logradouro_id']) ?? 0,
      numero: _str(map['numero']),
      numeroInt: _int(map['numero_int']),
      modificador: _str(map['modificador']),
      complemento: _str(map['complemento']),
      bairro: _str(map['bairro']),
      cep: _str(map['cep']),
      lat: _double(map['lat']),
      lon: _double(map['lon']),
      precisao: _int(map['precisao']),
      especie: _int(map['especie']),
      tipoEdificacao: _int(map['tipo_edificacao']),
      estabelecimento: _str(map['estabelecimento']),
      numQuadra: _int(map['num_quadra']),
      numFace: _int(map['num_face']),
      codSetor: _str(map['cod_setor']),
      cepFonte: _str(map['cep_fonte']),
      malhaNo: _int(map['malha_no']),
      malhaMetros: _double(map['malha_metros']),
      origem: _str(map['origem']) ?? 'cnefe',
      codUnicoCnefe: _str(map['cod_unico_cnefe']),
      chaveCnefe: _str(map['chave_cnefe']),
      verificado: _bool(map['verificado']) ?? false,
      ativo: _bool(map['ativo']) ?? true,
      obs: _str(map['obs']),
      criadoEm: _data(map['criado_em']),
      atualizadoEm: _data(map['atualizado_em']),
      logradouroNome: _str(map['logradouro_nome']),
      logradouroCompleto: _str(map['logradouro_completo']),
      enderecoFormatado: _str(map['endereco_formatado']),
    );
  }

  static String? _str(Object? v) => v?.toString();

  static int? _int(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _double(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static bool? _bool(Object? v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase();
    return s == '1' || s == 'true';
  }

  static DateTime _data(Object? v) {
    if (v != null) {
      final data = DateTime.tryParse(v.toString());
      if (data != null) return data;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cod_ibge': codIbge,
      'logradouro_id': logradouroId,
      'numero': numero,
      'numero_int': numeroInt,
      'modificador': modificador,
      'complemento': complemento,
      'bairro': bairro,
      'cep': cep,
      'lat': lat,
      'lon': lon,
      'precisao': precisao,
      'especie': especie,
      'tipo_edificacao': tipoEdificacao,
      'estabelecimento': estabelecimento,
      'num_quadra': numQuadra,
      'num_face': numFace,
      'cod_setor': codSetor,
      'cep_fonte': cepFonte,
      'malha_no': malhaNo,
      'malha_metros': malhaMetros,
      'origem': origem,
      'cod_unico_cnefe': codUnicoCnefe,
      'chave_cnefe': chaveCnefe,
      'verificado': verificado ? 1 : 0,
      'ativo': ativo ? 1 : 0,
      'obs': obs,
      'criado_em': criadoEm.toIso8601String(),
      'atualizado_em': atualizadoEm.toIso8601String(),
    };
  }

  String get enderecoDisplay {
    return enderecoFormatado ??
        '${logradouroCompleto ?? logradouroNome ?? ''} ${numero ?? 'S/N'}'.trim();
  }

  bool get temCoordenada => lat != null && lon != null;

  Endereco copyWith({
    int? id,
    String? codIbge,
    int? logradouroId,
    String? numero,
    int? numeroInt,
    String? modificador,
    String? complemento,
    String? bairro,
    String? cep,
    double? lat,
    double? lon,
    int? precisao,
    int? especie,
    int? tipoEdificacao,
    String? estabelecimento,
    int? numQuadra,
    int? numFace,
    String? codSetor,
    String? cepFonte,
    int? malhaNo,
    double? malhaMetros,
    String? origem,
    String? codUnicoCnefe,
    String? chaveCnefe,
    bool? verificado,
    bool? ativo,
    String? obs,
    DateTime? criadoEm,
    DateTime? atualizadoEm,
    String? logradouroNome,
    String? logradouroCompleto,
    String? enderecoFormatado,
  }) {
    return Endereco(
      id: id ?? this.id,
      codIbge: codIbge ?? this.codIbge,
      logradouroId: logradouroId ?? this.logradouroId,
      numero: numero ?? this.numero,
      numeroInt: numeroInt ?? this.numeroInt,
      modificador: modificador ?? this.modificador,
      complemento: complemento ?? this.complemento,
      bairro: bairro ?? this.bairro,
      cep: cep ?? this.cep,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      precisao: precisao ?? this.precisao,
      especie: especie ?? this.especie,
      tipoEdificacao: tipoEdificacao ?? this.tipoEdificacao,
      estabelecimento: estabelecimento ?? this.estabelecimento,
      numQuadra: numQuadra ?? this.numQuadra,
      numFace: numFace ?? this.numFace,
      codSetor: codSetor ?? this.codSetor,
      cepFonte: cepFonte ?? this.cepFonte,
      malhaNo: malhaNo ?? this.malhaNo,
      malhaMetros: malhaMetros ?? this.malhaMetros,
      origem: origem ?? this.origem,
      codUnicoCnefe: codUnicoCnefe ?? this.codUnicoCnefe,
      chaveCnefe: chaveCnefe ?? this.chaveCnefe,
      verificado: verificado ?? this.verificado,
      ativo: ativo ?? this.ativo,
      obs: obs ?? this.obs,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      logradouroNome: logradouroNome ?? this.logradouroNome,
      logradouroCompleto: logradouroCompleto ?? this.logradouroCompleto,
      enderecoFormatado: enderecoFormatado ?? this.enderecoFormatado,
    );
  }
}
