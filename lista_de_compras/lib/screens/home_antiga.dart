import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.usuario});

  final User? usuario;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  late final User? _usuario;
  late final Stream<List<Map<String, dynamic>>> _produtosStream;
  final List<String> _listasTab = ['Geral'];

  void initState() {
    super.initState();
    _usuario = widget.usuario ?? _supabase.auth.currentUser;
    _produtosStream = _usuario == null
        ? Stream.value(<Map<String, dynamic>>[])
        : _supabase
              .from('produtos')
              .stream(primaryKey: ['id'])
              .eq('usuario_id', _usuario.id)
              .order('created_at');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Função para adicionar produto ao Supabase
  Future<void> _adicionarProduto() async {
    final nome = _controller.text.trim();
    if (nome.isEmpty || _usuario == null) return;

    try {
      await _supabase.from('produtos').insert({
        'nome': nome,
        'comprado': false,
        'usuario_id': _usuario.id,
      });

      if (mounted) _controller.clear();
    } catch (error) {
      _mostrarErro('Não foi possível adicionar o produto: $error');
    }
  }

  // Função para alternar o status do produto ao clicar
  Future<void> _alternarStatus(Map<String, dynamic> produto) async {
    final novoStatus = !produto['comprado'];
    final DateTime agora = DateTime.now();

    try {
      await _supabase
          .from('produtos')
          .update({
            'comprado': novoStatus,
            'ultima_compra': novoStatus
                ? agora.toUtc().toIso8601String()
                : null,
          })
          .eq('id', produto['id']);
    } catch (error) {
      _mostrarErro('Não foi possível atualizar o produto: $error');
    }
  }

  // Função para deletar o produto do Supabase
  Future<void> _deletarProduto(dynamic id) async {
    try {
      await _supabase.from('produtos').delete().eq('id', id);
    } catch (error) {
      _mostrarErro('Não foi possível excluir o produto: $error');
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _listasTab.length,
      child: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            isScrollable: true,
            tabs: _listasTab.map((String name) => Tab(text: name)).toList(),
          ),
          title: const Text('🛒 Lista de Compras Online'),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                decoration: const InputDecoration(
                                  hintText: 'Adicionar novo produto...',
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _adicionarProduto(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _adicionarProduto,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: _buildLista(somenteComprados: false)),
                    ],
                  ),
                  _buildLista(somenteComprados: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLista({required bool somenteComprados}) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _produtosStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Erro ao carregar produtos: ${snapshot.error}'),
          );
        }

        final produtos = (snapshot.data ?? [])
            .where(
              (produto) => !somenteComprados || produto['comprado'] == true,
            )
            .toList();
        if (produtos.isEmpty) {
          return Center(
            child: Text(
              somenteComprados
                  ? 'Nenhuma compra registrada.'
                  : 'Nenhum produto na lista.',
            ),
          );
        }

        return ListView.builder(
          itemCount: produtos.length,
          itemBuilder: (context, index) {
            final produto = produtos[index];
            final comprado = produto['comprado'] == true;
            final ultimaCompra = produto['ultima_compra'];

            return ListTile(
              leading: IconButton(
                icon: Icon(
                  comprado ? Icons.check_box : Icons.check_box_outline_blank,
                  color: comprado ? Colors.green : Colors.grey,
                ),
                onPressed: () => _alternarStatus(produto),
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      produto['nome']?.toString() ?? 'Produto',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        decoration: comprado
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: comprado ? Colors.grey : Colors.black87,
                        fontWeight: comprado
                            ? FontWeight.normal
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (ultimaCompra != null)
                    Text(
                      ' ${DateFormat('dd/MM/yy HH:mm').format(DateTime.parse(ultimaCompra.toString()).toLocal())}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(
                    label: Text(
                      comprado ? 'Comprado' : 'A comprar',
                      style: TextStyle(
                        color: comprado
                            ? Colors.green.shade800
                            : Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: comprado
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    side: BorderSide.none,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _deletarProduto(produto['id']),
                  ),
                ],
              ),
              onTap: () => _alternarStatus(produto),
            );
          },
        );
      },
    );
  }
}

class NewWidget extends StatelessWidget {
  const new({
    super.key,
    required this._usuario,
  });

  final User? _usuario;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: InkWell(
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            ),
          );
        },
        child: Image.asset(
          'lib/assets/images/perfil.png',
          width: 30,
          height: 30,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.account_circle, size: 30),
        ),
      ),
      title: Text(
        _usuario?.email ?? 'Usuário não logado',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
