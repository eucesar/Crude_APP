// Importa utilitários para trabalhar com JSON
import 'dart:convert';

// Flutter UI e cliente HTTP
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Centralização da URL da API
class ApiConfig {
  static const String baseUrl = "https://easy-address-app-15d989ca7c47.herokuapp.com";
  // Endpoint: lista/cria endereços
  static String addresses() => "$baseUrl/addresses";
  // Endpoint: obtém/atualiza/deleta por id
  static String addressById(int id) => "$baseUrl/addresses/$id";
  // Endpoint: consulta CEP e retorna dados de endereço
  static String cep(String cep) => "$baseUrl/cep/$cep";
}

/// Classe que representa um endereço do backend
class Address {
  final int id;
  final String nomeUsuario;
  final String cep;
  final String logradouro;
  final String bairro;
  final String cidade;
  final String uf;
  final String tipo;

  Address({
    required this.id,
    required this.nomeUsuario,
    required this.cep,
    required this.logradouro,
    required this.bairro,
    required this.cidade,
    required this.uf,
    required this.tipo,
  });

  /// Transforma o Map<String,dynamic> (JSON) vindo da API em uma instância Address
  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'],
      nomeUsuario: json['nomeUsuario'],
      cep: json['cep'],
      logradouro: json['logradouro'],
      bairro: json['bairro'],
      cidade: json['cidade'],
      uf: json['uf'],
      tipo: json['tipo'],
    );
  }
}

/// HomePage é um StatefulWidget porque precisa armazenar e atualizar a lista de endereços
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Estado local com a lista de endereços renderizada na tela
  List<Address> addresses = [];

  @override
  void initState() {
    super.initState();
    fetchAddresses();
  }

  /// Carrega a lista de endereços da API
  Future<void> fetchAddresses() async {
    // Faz GET na API para obter a listagem de endereços
    final response = await http.get(Uri.parse(ApiConfig.addresses()));
    if (response.statusCode == 200) {
      // Decodifica JSON em lista dinâmica
      final List<dynamic> data = json.decode(response.body);
      // Converte cada item em Address e atualiza o estado (re-render)
      setState(() {
        addresses = data.map((e) => Address.fromJson(e)).toList();
      });
    }
  }

  /// Abre o formulário e, ao retornar, recarrega a listagem
  void goToForm({Address? address}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddressFormPage(address: address)),
    );
    fetchAddresses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Endereços")),
      body: ListView.builder(
        itemCount: addresses.length,
        itemBuilder: (context, index) {
          final addr = addresses[index];
          return ListTile(
            title: Text(addr.nomeUsuario),
            subtitle: Text("${addr.logradouro}, ${addr.bairro} - ${addr.cidade}/${addr.uf}"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => goToForm(address: addr),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => goToForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Tela de formulário para criação/edição de Address
class AddressFormPage extends StatefulWidget {
  final Address? address;

  const AddressFormPage({super.key, this.address});

  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  // Chave para validar e manipular o formulário
  final _formKey = GlobalKey<FormState>();
  // Controllers dos campos (lê/escreve programaticamente)
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController cepController = TextEditingController();
  final TextEditingController logradouroController = TextEditingController();
  final TextEditingController bairroController = TextEditingController();
  final TextEditingController cidadeController = TextEditingController();
  final TextEditingController ufController = TextEditingController();
  final TextEditingController tipoController = TextEditingController();
  @override
  void initState() {
    super.initState();
    // Prefill: se for edição, preenche os campos com os valores do endereço
    if (widget.address != null) {
      nomeController.text = widget.address!.nomeUsuario;
      cepController.text = widget.address!.cep;
      logradouroController.text = widget.address!.logradouro;
      bairroController.text = widget.address!.bairro;
      cidadeController.text = widget.address!.cidade;
      ufController.text = widget.address!.uf;
      tipoController.text = widget.address!.tipo;
    }
  }

  /// Salva endereço: cria (POST) ou atualiza (PUT) conforme presença de id
  Future<void> saveAddress() async {
    if (_formKey.currentState!.validate()) {
      // Monta o payload a partir dos campos
      final Map<String, dynamic> data = {
        "nomeUsuario": nomeController.text,
        "cep": cepController.text,
        "logradouro": logradouroController.text,
        "bairro": bairroController.text,
        "cidade": cidadeController.text,
        "uf": ufController.text,
        "tipo": tipoController.text,
      };

      http.Response response;
      if (widget.address == null) {
        // Criação (POST)
        response = await http.post(
          Uri.parse(ApiConfig.addresses()),
          headers: {"Content-Type": "application/json"},
          body: json.encode(data),
        );
      } else {
        // Edição (PUT) usando o id
        response = await http.put(
          Uri.parse(ApiConfig.addressById(widget.address!.id)),
          headers: {"Content-Type": "application/json"},
          body: json.encode(data),
        );
      }

      // Se sucesso (2xx), fecha retornando para a lista
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (mounted) Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao salvar')),
        );
      }
    } else {
      // Form inválido: dá feedback ao usuário
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao salvar')),
      );
    }
  }

  /// Deleta endereço via DELETE /addresses/{id}
  Future<void> deleteAddress() async {
    if (widget.address == null) return;
    final response = await http.delete(
      Uri.parse(ApiConfig.addressById(widget.address!.id)),
    );
    // Se deletar com sucesso, fecha a tela
    if (response.statusCode == 200) {
      if (mounted) Navigator.pop(context);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro ao excluir endereço")),
      );
    }
  }

  /// Busca CEP e preenche demais campos
  Future<void> fetchCep() async {
    final cep = cepController.text.trim();
    if (cep.isEmpty) return;
    // Consulta a API de CEP para pré-preencher os campos
    final response = await http.get(Uri.parse(ApiConfig.cep(cep)));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      setState(() {
        logradouroController.text = data['logradouro'] ?? '';
        bairroController.text = data['bairro'] ?? '';
        cidadeController.text = data['cidade'] ?? '';
        ufController.text = data['uf'] ?? '';
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CEP não encontrado')),
      );
    }
  }

  // Diálogo de confirmação (retorna true/false)
  Future<bool> showConfirmDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmação"),
        content: const Text("Deseja realmente excluir este endereço?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Excluir"),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.address != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "Editar Endereço" : "Novo Endereço"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Nome do usuário (obrigatório)
              TextFormField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: "Nome do Usuário"),
                validator: (v) => (v == null || v.isEmpty) ? 'Preencha o nome' : null,
              ),
              // CEP + botão para buscar dados e preencher campos
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: cepController,
                      decoration: const InputDecoration(labelText: "CEP"),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: fetchCep,
                  ),
                ],
              ),
              // Campos de endereço com validação básica
              TextFormField(
                controller: logradouroController,
                decoration: const InputDecoration(labelText: "Logradouro"),
                validator: (v) => (v == null || v.isEmpty) ? 'Preencha o logradouro' : null,
              ),
              TextFormField(
                controller: bairroController,
                decoration: const InputDecoration(labelText: "Bairro"),
                validator: (v) => (v == null || v.isEmpty) ? 'Preencha o bairro' : null,
              ),
              TextFormField(
                controller: cidadeController,
                decoration: const InputDecoration(labelText: "Cidade"),
                validator: (v) => (v == null || v.isEmpty) ? 'Preencha a cidade' : null,
              ),
              TextFormField(
                controller: ufController,
                decoration: const InputDecoration(labelText: "UF"),
                validator: (v) => (v == null || v.isEmpty) ? 'Preencha o UF' : null,
              ),
              TextFormField(
                controller: tipoController,
                decoration: const InputDecoration(labelText: "Tipo"),
                validator: (v) => (v == null || v.isEmpty) ? 'Preencha o tipo' : null,
              ),
              // Botões de ação
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: saveAddress,
                child: const Text("Salvar"),
              ),
              if (isEditing) ...[
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    final confirm = await showConfirmDialog(context);
                    if (confirm == true) {
                      deleteAddress();
                    }
                  },
                  child: const Text("Excluir"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  // Libera todos os controllers para evitar vazamento de memória
  void dispose() {
    nomeController.dispose();
    cepController.dispose();
    logradouroController.dispose();
    bairroController.dispose();
    cidadeController.dispose();
    ufController.dispose();
    tipoController.dispose();
    super.dispose();
  }
}

void main() {
  runApp(const AddressApp());
}

class AddressApp extends StatelessWidget {
const AddressApp({super.key});
@override
Widget build(BuildContext context) {
 return MaterialApp(
 title: 'Address App',
 theme: ThemeData(primarySwatch:
Colors.blue),
 home: const HomePage(),
 debugShowCheckedModeBanner: false,
 );
 }
}
