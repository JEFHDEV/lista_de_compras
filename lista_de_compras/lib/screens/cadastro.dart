import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home.dart';
import 'login.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _isLoading = false; // Controle para evitar múltiplos cliques seguidos

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Se o formulário não passar na validação visual, interrompe aqui
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final nome = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final supabase = Supabase.instance.client;

      // 1. Cria a conta no sistema de Autenticação do Supabase
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'nome': nome}, // Envia o nome como metadado
      );

      final userId = response.user?.id;
      
      // 2. Se o usuário foi criado com sucesso, salva os dados na tabela pública
      if (userId != null) {
        await supabase.from('usuarios').insert({
          'id': userId,
          'nome': nome,
          'email': email,
        });
      }

      if (!mounted) return;

      // 3. Verifica se a conta já está ativa ou aguardando confirmação por e-mail
      if (response.user != null && response.session != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cadastro realizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        
        final usuarioLogado = Supabase.instance.client.auth.currentUser;
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen(usuario: usuarioLogado)),
        );
      } else {
        // Caso a confirmação de e-mail esteja ligada nas configurações do Supabase
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verifique seu e-mail para concluir o cadastro.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context); // Retorna para a tela de login
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocorreu um erro inesperado. Tente novamente.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 72,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Crie sua conta',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Preencha os dados abaixo para começar',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Campo de Nome
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final name = value?.trim() ?? '';
                        if (name.isEmpty) return 'Informe seu nome';
                        if (name.length < 2) return 'Nome muito curto';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Campo de E-mail
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Informe seu e-mail';
                        if (!RegExp(r'^.+@.+\..+$').hasMatch(email)) {
                          return 'Informe um e-mail válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Campo de Senha
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _hidePassword ? 'Mostrar senha' : 'Ocultar senha',
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(
                            _hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Informe sua senha';
                        }
                        if (value.length < 6) {
                          return 'A senha deve ter pelo menos 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Campo de Confirmar Senha
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _hideConfirmPassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Confirmar senha',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _hideConfirmPassword ? 'Mostrar senha' : 'Ocultar senha',
                          onPressed: () => setState(() => _hideConfirmPassword = !_hideConfirmPassword),
                          icon: Icon(
                            _hideConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Confirme sua senha';
                        }
                        if (value != _passwordController.text) {
                          return 'As senhas não coincidem';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Botão Cadastrar com indicador de progresso
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Cadastrar'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Voltar para o Login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Flexible(child: Text('Já possui uma conta?')),
                        TextButton(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          ),
                          child: const Text('Entrar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
