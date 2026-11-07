import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cadastro.dart';
import 'home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
  if (_formKey.currentState!.validate()) {
    try {
        final supabase = Supabase.instance.client;
        // 2. Tenta realizar o login usando o e-mail e a senha digitados
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(), // .trim() remove espaços acidentais
          password: _passwordController.text,
        );
        // 3. Se o login for bem-sucedido, redireciona para a HomeScreen
        if (mounted) { // Garante que o componente ainda existe na tela antes de navegar
        
        final usuarioLogado = Supabase.instance.client.auth.currentUser;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen(usuario: usuarioLogado)),
          );
        }

      } on AuthException catch (error) {
        // 4. Captura erros específicos de autenticação do Supabase
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.message), // Exibe o erro (ex: "Invalid login credentials")
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (error) {
        // 5. Captura qualquer outro erro inesperado (ex: falta de internet)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ocorreu um erro inesperado. Tente novamente.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }



  Future<bool> isRegistered(String email) async {
    final supabase = Supabase.instance.client;
    final data = await supabase.from('usuarios').select().eq('email', email);
    return data.isNotEmpty;
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
                      Icons.shopping_basket_rounded,
                      size: 72,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Lista de Compras',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Entre na sua conta para continuar',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
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
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _hidePassword
                              ? 'Mostrar senha'
                              : 'Ocultar senha',
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Informe sua senha'
                          : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text('Esqueceu a senha?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _submit,
                        child: const Text('Entrar'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Flexible(child: Text('Ainda não tem uma conta?')),
                        TextButton(
                          onPressed: () => 
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const CadastroScreen()),
                            ),
                          child: const Text('Cadastre-se'),
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
