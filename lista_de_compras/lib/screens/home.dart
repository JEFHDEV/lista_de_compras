import 'dart:async';
import 'package:uuid/uuid.dart';
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
  List<_ListaCompras> _listas = [];
  List<Map<String, dynamic>> _produtos = [];
  String? _erroProdutos;
  int _geracaoCargaProdutos = 0;
  bool _carregandoListas = true;
  bool _carregandoProdutos = false;

  @override
  void initState() {
    super.initState();
    _usuario = widget.usuario ?? _supabase.auth.currentUser;
    unawaited(_carregarListas());
  }

  @override
  void dispose() {
    _controller.dispose();
    _dialogController.dispose();
    super.dispose();
  }

  Future<void> _carregarListas() async {
    if (_usuario == null) {
      if (mounted) {
        setState(() {
          _listas = [];
          _carregandoListas = false;
        });
        await _carregarProdutos([]);
      }
      return;
    }

    try {
      final listasProprias = await _supabase
          .from('lista')
          .select('id')
          .eq('dono', _usuario.id);
      final listasCompartilhadas = await _supabase
          .from('usuarios_autorizados')
          .select('lista_id')
          .eq('usuarios_id', _usuario.id);

      final ids = <int>{
        for (final item in listasProprias) (item['id'] as num).toInt(),
        for (final item in listasCompartilhadas)
          (item['lista_id'] as num).toInt(),
      };

      final List<_ListaCompras> listas;
      if (ids.isEmpty) {
        listas = [];
      } else {
        final response = await _supabase
            .from('lista')
            .select('id, nome, dono')
            .inFilter('id', ids.toList())
            .order('created_at');
        listas = response
            .map(
              (item) => _ListaCompras(
                id: (item['id'] as num).toInt(),
                nome: item['nome'] as String,
                donoId: item['dono'] as String,
              ),
            )
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _listas = listas;
        _carregandoListas = false;
      });
      await _carregarProdutos(listas);
    } catch (error) {
      if (!mounted) return;
      setState(() => _carregandoListas = false);
      _mostrarErro('Não foi possível carregar as listas: $error');
    }
  }

  Future<void> _carregarProdutos(List<_ListaCompras> listas) async {
    final geracao = ++_geracaoCargaProdutos;
    if (mounted) {
      setState(() {
        _carregandoProdutos = true;
        _erroProdutos = null;
      });
    }

    try {
      final ids = listas.map((lista) => lista.id).toList();
      final produtos = _usuario == null || ids.isEmpty
          ? <Map<String, dynamic>>[]
          : await _supabase
                .from('produtos')
                .select()
                .inFilter('lista_id', ids)
                .order('created_at');

      if (!mounted || geracao != _geracaoCargaProdutos) return;
      setState(() {
        _produtos = produtos;
        _carregandoProdutos = false;
      });
    } catch (error) {
      if (!mounted || geracao != _geracaoCargaProdutos) return;
      setState(() {
        _erroProdutos = 'Não foi possível carregar os produtos: $error';
        _carregandoProdutos = false;
      });
    }
  }

  Future<void> _criarNovaAba() async {
    if (_usuario == null) {
      _mostrarErro('Entre na sua conta para criar uma lista.');
      return;
    }

    _dialogController.clear();
    final criada = await showDialog<bool>(
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nome = _dialogController.text.trim();
              if (nome.isEmpty) {
                _mostrarErro('Informe um nome para a categoria.');
                return;
              }
              if (_listas.any((lista) => lista.nome == nome)) {
                _mostrarErro('Essa categoria já existe.');
                return;
              }

              try {
                await _supabase.from('lista').insert({
                  'nome': nome,
                  'dono': _usuario.id,
                });
                if (context.mounted) Navigator.pop(context, true);
              } catch (error) {
                _mostrarErro('Não foi possível criar a categoria: $error');
              }
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );

    if (criada == true && mounted) {
      await _carregarListas();
    }
  }

  Future<void> _editarAba(_ListaCompras lista) async {
    if (lista.donoId != _usuario?.id) {
      _mostrarErro('Somente o dono pode renomear esta lista.');
      return;
    }

    _dialogController.text = lista.nome;
    final novoNome = await showDialog<String>(
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
            onPressed: () =>
                Navigator.pop(context, _dialogController.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (novoNome == null || novoNome.isEmpty || !mounted) return;
    if (_listas.any((item) => item.nome == novoNome && item.id != lista.id)) {
      _mostrarErro('Essa categoria já existe.');
      return;
    }

    try {
      await _supabase
          .from('lista')
          .update({'nome': novoNome})
          .eq('id', lista.id)
          .eq('dono', _usuario!.id);
      await _carregarListas();
    } catch (error) {
      _mostrarErro('Não foi possível renomear a categoria: $error');
    }
  }

  Future<void> _deletarAba(_ListaCompras lista) async {
    if (lista.donoId != _usuario?.id) {
      _mostrarErro('Somente o dono pode excluir esta lista.');
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Excluir a lista "${lista.nome}"?'),
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
    );
    if (confirmado != true) return;

    try {
      await _supabase
          .from('lista')
          .delete()
          .eq('id', lista.id)
          .eq('dono', _usuario!.id);
      await _carregarListas();
    } catch (error) {
      _mostrarErro('Não foi possível excluir a lista: $error');
    }
  }

  Future<void> _adicionarProduto(_ListaCompras lista) async {
    final nome = _controller.text.trim();
    if (nome.isEmpty || _usuario == null) return;

    try {
      await _supabase.from('produtos').insert({
        'nome': nome,
        'comprado': false,
        'lista_id': lista.id,
        'categoria': lista.nome,
      });
      if (mounted) _controller.clear();
      await _carregarProdutos(_listas);
    } catch (error) {
      _mostrarErro('Não foi possível adicionar o produto: $error');
    }
  }

  Future<void> _marcarTodosComoComprados(_ListaCompras lista) async {
    try {
      await _supabase
          .from('produtos')
          .update({
            'comprado': true,
            'ultima_compra': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('lista_id', lista.id);
      await _carregarProdutos(_listas);
    } catch (error) {
      _mostrarErro('Não foi possível marcar todos como comprados: $error');
    }
  }

  Future<void> _marcarTodosComoComprar(_ListaCompras lista) async {
    try {
      await _supabase
          .from('produtos')
          .update({'comprado': false, 'ultima_compra': null})
          .eq('lista_id', lista.id);
      await _carregarProdutos(_listas);
    } catch (error) {
      _mostrarErro('Não foi possível marcar todos como a comprar: $error');
    }
  }

  Future<void> _excluirTodosDaAba(_ListaCompras lista) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: const Text(
          'Tem certeza que deseja excluir todos os produtos desta categoria?',
        ),
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
    );
    if (confirmado != true) return;

    try {
      await _supabase.from('produtos').delete().eq('lista_id', lista.id);
      await _carregarProdutos(_listas);
    } catch (error) {
      _mostrarErro('Não foi possível excluir os produtos: $error');
    }
  }

  Future<void> _alternarStatus(Map<String, dynamic> produto) async {
    final novoStatus = produto['comprado'] != true;
    try {
      await _supabase
          .from('produtos')
          .update({
            'comprado': novoStatus,
            'ultima_compra': novoStatus
                ? DateTime.now().toUtc().toIso8601String()
                : null,
          })
          .eq('id', produto['id']);
      await _carregarProdutos(_listas);
    } catch (error) {
      _mostrarErro('Não foi possível atualizar o produto: $error');
    }
  }

  Future<void> _deletarProduto(dynamic id) async {
    try {
      await _supabase.from('produtos').delete().eq('id', id);
      await _carregarProdutos(_listas);
    } catch (error) {
      _mostrarErro('Não foi possível excluir o produto: $error');
    }
  }

  Future<void> _compartilharLista(_ListaCompras lista) async {
    final compartilhar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compartilhar esta lista'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Preencha o email com quem quer compartilhar a lista ${lista.nome}', 
            ),
            TextField(
              controller: _dialogController,
              decoration: const InputDecoration(
                hintText: 'Email do usuário',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Compartilhar'),
          ),
        ],
      ),
    );
    if (compartilhar != true) return;
    
    _adicionarUsuarioNaLista(lista);  
  }
    
    
  Future<void> _adicionarUsuarioNaLista(_ListaCompras lista) async {
  try {
    final emailDigitado = _dialogController.text.trim();

    // 1. Verifica se o usuário já existe na tabela 'usuarios' pelo email
    final existingUser = await _supabase
        .from('usuarios')
        .select('id')
        .eq('email', emailDigitado)
        .maybeSingle();

    String usuarioId;
    var uuid = const Uuid();
    String novoId = uuid.v4();

    // 2. Se não existir, cria o usuário na tabela 'usuarios' e pega o ID gerado
    if (existingUser == null) {
        final novoUsuario = await _supabase.from('usuarios').insert({
          'id': novoId,
          'email': emailDigitado,
          'nome': emailDigitado.split('@').first,
        }).select('id').single();

        usuarioId = novoUsuario['id'];
      } else {
        // Se já existir, aproveita o ID encontrado
        usuarioId = existingUser['id'];
      }

      // 3. Insere o ID obtido na tabela de relacionamento 'usuarios_autorizados'
      await _supabase.from('usuarios_autorizados').insert({
        'lista_id': lista.id,
        'role': 'guess', // ou 'editor'
        'usuarios_id': usuarioId,
      });

      // Limpa o campo e recarrega os produtos/listas
      _dialogController.clear();

      if (mounted) {
        _mostrarErro('Lista compartilhada com sucesso!');
      }

    } catch (error) {
      print('Erro detalhado ao compartilhar: $error');
      if (mounted) {
        _mostrarErro('Não foi possível compartilhar a lista: $error');
      }
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoListas) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_listas.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(
          child: Text('Nenhuma categoria criada. Toque no ícone acima!'),
        ),
      );
    }

    return DefaultTabController(
      key: ValueKey(_listas.map((lista) => lista.id).join(',')),
      length: _listas.length,
      child: Scaffold(
        appBar: _buildAppBar(
          bottom: TabBar(
            isScrollable: true,
            tabs: _listas.map((lista) => Tab(text: lista.nome)).toList(),
          ),
        ),
        body: _carregandoProdutos
            ? const Center(child: CircularProgressIndicator())
            : _erroProdutos != null
            ? Center(child: Text(_erroProdutos!))
            : TabBarView(
                children: _listas.map((lista) {
                  final produtosDaLista = _produtos
                      .where((produto) => produto['lista_id'] == lista.id)
                      .toList();
                  return _buildConteudoLista(lista, produtosDaLista);
                }).toList(),
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({PreferredSizeWidget? bottom}) {
    return AppBar(
      title: Row(
        children: [
          LogoutButtonWidget(user: _usuario),
          const Text('🛒 Lista de Compras Online'),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.create_new_folder,
            color: Theme.of(context).colorScheme.primary,
            size: 30,
          ),
          tooltip: 'Nova Categoria',
          onPressed: _criarNovaAba,
        ),
        const SizedBox(width: 8),
      ],
      bottom: bottom,
    );
  }

  Widget _buildConteudoLista(
    _ListaCompras lista,
    List<Map<String, dynamic>> produtos,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'editar':
                      _editarAba(lista);
                    case 'deletar':
                      _deletarAba(lista);
                    case 'marcar_comprado':
                      _marcarTodosComoComprados(lista);
                    case 'marcar_comprar':
                      _marcarTodosComoComprar(lista);
                    case 'excluir_todos':
                      _excluirTodosDaAba(lista);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'editar',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Renomear Categoria'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'deletar',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Excluir Categoria',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'marcar_comprado',
                    child: Row(
                      children: [
                        Icon(Icons.check, size: 20),
                        SizedBox(width: 8),
                        Text('Marcar todos como comprados'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'marcar_comprar',
                    child: Row(
                      children: [
                        Icon(Icons.add_shopping_cart, size: 20),
                        SizedBox(width: 8),
                        Text('Marcar todos como comprar'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'excluir_todos',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Excluir todos os produtos',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
                icon: Icon(
                  Icons.more_horiz,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                'Menu',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  color: Colors.grey.shade700,
                ),
              ),
              Expanded(
                child: Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    lista.donoId == _usuario?.id
                    ? const SizedBox.shrink() // Retorna um widget invisível/vazio se a lista for do próprio usuário
                    : FutureBuilder(
                        future: _supabase.from('usuarios').select('nome').eq('id', lista.donoId).single(),
                        builder: (context, snapshot) {
                          // Exibe um texto temporário enquanto a consulta está em andamento
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Text('Compartilhada de (carregando...)');
                          }
                          
                          // Trata o caso em que o ID não foi encontrado ou ocorreu um erro
                          if (snapshot.hasError || !snapshot.hasData) {
                            return const Text('Compartilhada (dono desconhecido)');
                          }

                          // O Supabase retorna um Map {'nome': 'Valor'}, então extraímos a chave 'nome'
                          final nomeDoDono = snapshot.data!['nome'].toString();

                          return Text('Compartilhada de $nomeDoDono');
                        },
                      )
                  ],
                ),
              ),
              Text(
                'Compartilhar',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  color: Colors.grey.shade700,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.share,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () {
                  _compartilharLista(lista);
                },
              ),
            ],
          ),
        ),
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
                  onSubmitted: (_) => _adicionarProduto(lista),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _adicionarProduto(lista),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: produtos.isEmpty
              ? const Center(child: Text('Nenhum produto nesta categoria.'))
              : ListView.builder(
                  itemCount: produtos.length,
                  itemBuilder: (context, index) {
                    final produto = produtos[index];
                    final comprado = produto['comprado'] == true;
                    final ultimaCompra = produto['ultima_compra'] == null
                        ? null
                        : DateTime.parse(produto['ultima_compra'].toString())
                              .toLocal();

                    return ListTile(
                      leading: IconButton(
                        icon: Icon(
                          comprado
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: comprado ? Colors.green : Colors.grey,
                        ),
                        onPressed: () => _alternarStatus(produto),
                      ),
                      title: Text(
                        produto['nome']?.toString() ?? 'Produto',
                        style: TextStyle(
                          decoration: comprado
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: comprado ? Colors.grey : Colors.black,
                        ),
                      ),
                      subtitle: ultimaCompra == null
                          ? null
                          : Text(
                              'Última compra: ${DateFormat('dd/MM/yyyy').format(ultimaCompra)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deletarProduto(produto['id']),
                      ),
                      onTap: () => _alternarStatus(produto),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ListaCompras {
  const _ListaCompras({
    required this.id,
    required this.nome,
    required this.donoId,
  });

  final int id;
  final String nome;
  final String donoId;
}

class LogoutButtonWidget extends StatelessWidget {
  const LogoutButtonWidget({super.key, required this.user});

  final User? user;

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
                const Icon(Icons.logout, size: 30, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
