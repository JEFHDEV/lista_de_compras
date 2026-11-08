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
  final _dialogController = TextEditingController();
  late final User? _usuario;
  late final Stream<List<Map<String, dynamic>>> _produtosStream;

  // Lista dinâmica de abas
  final List<String> _listasTab = ['Geral'];

  @override
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
    _dialogController.dispose();
    super.dispose();
  }

  // 1. CRIAR NOVA ABA
  void _criarNovaAba() {
    _dialogController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova Categoria'),
        content: TextField(
          controller: _dialogController,
          decoration: const InputDecoration(
            hintText: 'Ex: Açougue, Farmácia...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final nome = _dialogController.text.trim();
              if (nome.isNotEmpty && !_listasTab.contains(nome)) {
                setState(() => _listasTab.add(nome));
                Navigator.pop(context);
              }
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }

  // 2. EDITAR ABA
  void _editarAba(String nomeAntigo, int index) {
    _dialogController.text = nomeAntigo;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Categoria'),
        content: TextField(
          controller: _dialogController,
          decoration: const InputDecoration(hintText: 'Novo nome...'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final novoNome = _dialogController.text.trim();
              if (novoNome.isNotEmpty && !_listasTab.contains(novoNome)) {
                setState(() => _listasTab[index] = novoNome);
                Navigator.pop(context);
                // NOTA: Se quiser atualizar no Supabase os produtos antigos desta aba,
                // você precisará rodar um update na tabela filtrando por nomeAntigo.
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  // 3. DELETAR ABA
  void _deletarAba(int index) {
    setState(() => _listasTab.removeAt(index));
  }

  // Função para adicionar produto mapeado para a categoria/aba correta
  Future<void> _adicionarProduto(String nomeDaAba) async {
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
  // marcar todos os produtos da aba como comprados
  Future<void> _marcarTodosComoComprados(String nomeDaAba, usuario ) async {
    try {
      await _supabase
          .from('produtos')
          .update({
            'comprado': true,
            'ultima_compra': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('usuario_id', usuario?.id)
          .eq('categoria', nomeDaAba);
    } catch (error) {
      _mostrarErro('Não foi possível marcar todos como comprados: $error');
    }
  }

  // marcar todos os produtos da aba como comprar
  Future<void> _marcarTodosComoComprar(String nomeDaAba, usuario ) async {
    try {
      await _supabase
          .from('produtos')
          .update({
            'comprado': false,
            'ultima_compra': null,
          })
          .eq('usuario_id', usuario?.id)
          .eq('categoria', nomeDaAba);
    } catch (error) {
      _mostrarErro('Não foi possível marcar todos como comprar: $error');
    }
  }

  // excluir todos os produtos da aba
  Future<void> _excluirTodosDaAba(String nomeDaAba, usuario ) async {
    //criar um popup de confirmação antes de excluir todos os produtos da aba
    bool confirmado = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Tem certeza que deseja excluir todos os produtos desta categoria?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmado) return;

    try {
      await _supabase
          .from('produtos')
          .delete()
          .eq('usuario_id', usuario?.id)
          .eq('categoria', nomeDaAba);
    } catch (error) {
      _mostrarErro('Não foi possível excluir todos os produtos da aba: $error');
    }
  }

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
      // Chave dinâmica baseada nas strings evita travamentos e bugs visuais na barra de abas
      key: ValueKey(_listasTab.join(',')),
      length: _listasTab.length,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              PerfilWidget(usuario: _usuario),
              const Text('🛒 Lista de Compras Online'),
            ],
          ),
          // Garante que as ações fiquem visíveis no topo direito
          actions: [
            IconButton(
              icon: const Icon(
                Icons.create_new_folder,
                color: Color.fromARGB(255, 255, 198, 75), // Força uma cor contrastante (mude para a cor do seu tema se necessário)
                size: 30,
              ),
              tooltip: 'Nova Categoria',
              onPressed: _criarNovaAba,
            ),
            const SizedBox(width: 8), // Um pequeno espaçamento da borda da tela
          ],
          bottom: _listasTab.isEmpty
              ? null
              : TabBar(
                  isScrollable: true,
                  tabs: _listasTab
                      .map((String name) => Tab(text: name))
                      .toList(),
                ),
        ),
        body: _listasTab.isEmpty
            ? const Center(
                child: Text('Nenhuma categoria criada. Toque no ícone acima!'),
              )
            : TabBarView(
                children: List.generate(_listasTab.length, (index) {
                  final nomeDaAba = _listasTab[index];

                  return Column(
                    children: [
                      // Cabeçalho de controle interno da aba ativa (Editar / Excluir)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'editar') {
                                  _editarAba(nomeDaAba, index);
                                }
                                if (value == 'deletar') {
                                  _deletarAba(index);
                                }
                                if (value == 'marcar_comprado') {
                                  // Marcar todos os produtos da aba como comprados
                                  _marcarTodosComoComprados(nomeDaAba, _usuario);
                                }
                                if (value == 'marcar_comprar') {
                                  // Marcar todos os produtos da aba como comprar
                                  _marcarTodosComoComprar(nomeDaAba, _usuario);
                                }
                                if (value == 'excluir_todos') {
                                  // Excluir todos os produtos da aba
                                  _excluirTodosDaAba(nomeDaAba, _usuario);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'editar',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('Renomear Categoria'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'deletar',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Excluir Categoria',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'marcar_comprado',
                                  child: Row(
                                    children: [
                                      Icon(Icons.check, size: 20),
                                      SizedBox(width: 8),
                                      Text('Marcar todos como comprados'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'marcar_comprar',
                                  child: Row(
                                    children: [
                                      Icon(Icons.add_shopping_cart, size: 20),
                                      SizedBox(width: 8),
                                      Text('Marcar todos como comprar'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'excluir_todos',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Excluir todos os produtos',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              icon: const Icon(Icons.more_horiz),
                            ),
                            Text(
                              'Menu',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                    color: Colors.grey.shade700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      // Input para adicionar novos itens
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
                                onSubmitted: (_) =>
                                    _adicionarProduto(nomeDaAba),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: () => _adicionarProduto(nomeDaAba),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                      // Lista contendo os produtos filtrados da aba atual
                      Expanded(
                        child: _buildLista(
                          abaAtual: nomeDaAba,
                          somenteComprados: false,
                        ),
                      ),
                    ],
                  );
                }),
              ),
      ),
    );
  }

  // Lista com filtro dinâmico por categoria vinda do Supabase
  Widget _buildLista({
    required String abaAtual,
    required bool somenteComprados,
  }) {
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

        // Filtra os produtos salvos pela aba atual E pelo status de comprado
        final produtos = (snapshot.data ?? []).where((produto) {
          final pertenceABA =
              produto['categoria'] == abaAtual ||
              (abaAtual == 'Geral' && produto['categoria'] == null);
          final atendeStatus = !somenteComprados || produto['comprado'] == true;
          return pertenceABA && atendeStatus;
        }).toList();
        if (produtos.isEmpty) {
          return Center(
            child: Text(
              somenteComprados
                  ? 'Nenhuma compra registrada.'
                  : 'Nenhum produto nesta categoria.',
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

// Renomeado e ajustado o NewWidget para seguir as boas práticas de nomenclatura (PascalCase)
class PerfilWidget extends StatelessWidget {
  const PerfilWidget({super.key, required this.usuario});
  final User? usuario;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
          child: Image.asset(
            'lib/assets/images/icons8-esquerda-96.png',
            width: 30,
            height: 30,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.arrow_back, size: 30, color: Colors.grey),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
