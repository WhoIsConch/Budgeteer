import 'package:budget/services/providers/settings.dart';
import 'package:budget/utils/tools.dart';
import 'package:budget/utils/validators.dart';
import 'package:dynamic_system_colors/dynamic_system_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SignInType { signIn, signUp, google }

// TODO: Make login page look better. It's currently in an ALPHA state

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  bool passwordIsVisible = false;
  bool isLoading = false;
  SignInType? signInType;
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  String? usernameError;
  String? passwordError;

  SupabaseClient get supabase => Supabase.instance.client;

  void submitForm(SignInType type) async {
    setState(() {
      usernameError = null;
      passwordError = null;
      isLoading = true;
      signInType = type;
    });

    bool canFinish = false;

    if ([SignInType.signIn, SignInType.signUp].contains(type) &&
        !_formKey.currentState!.validate()) {
      setState(() => isLoading = false);
      return;
    }

    if (type == SignInType.signIn) {
      try {
        await supabase.auth.signInWithPassword(
          email: usernameController.text,
          password: passwordController.text,
        );
        canFinish = true;
      } on AuthException catch (e) {
        if (e.code == 'invalid_credentials') {
          setState(() => passwordError = 'Invalid username or password');
        } else {
          scaffoldMessengerKey.currentState!.showSnackBar(
            SnackBar(content: Text('An unknown error occurred: ${e.message}')),
          );
        }
        print(e.code);
      }
    } else if (type == SignInType.signUp) {
      try {
        await supabase.auth.signUp(
          email: usernameController.text,
          password: passwordController.text,
          data: {'full_name': 'user'},
        );
        canFinish = true;
        // Since the user successfully signed up, we need to make sure the
        // onboarding process runs. Therefore, always re-enable the
        // '_showTour` option.
        if (mounted) {
          final settings = context.read<SettingsService>();

          settings.setSetting('_showTour', true);
        }
      } catch (e) {
        // if (e.code == 'weak-password') {
        //   setState(() => passwordError = "Too weak");
        // } else if (e.code == 'email-already-in-use') {
        //   setState(() => usernameError = "Email already in use");
        // } else {
        //   scaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
        //       content: Text("An unknown error occurred: ${e.message}")));
        // }
        rethrow;
      }
    } else if (type == SignInType.google) {
      final GoogleSignInAccount? googleUser =
          await GoogleSignIn(
            scopes: ['email', 'profile', 'openid'],
            serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
          ).signIn();

      // Obtain the auth details from the request
      final GoogleSignInAuthentication? googleAuth =
          await googleUser?.authentication;

      if (googleAuth?.idToken == null) {
        scaffoldMessengerKey.currentState!.showSnackBar(
          const SnackBar(content: Text('Error: No Client ID')),
        );
      } else if (googleAuth?.accessToken == null) {
        scaffoldMessengerKey.currentState!.showSnackBar(
          const SnackBar(content: Text('Error: No Access Token')),
        );
      }

      if (googleAuth != null) {
        // Once signed in, return the UserCredential
        await supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: googleAuth.idToken!,
          accessToken: googleAuth.accessToken,
        );
        canFinish = true;
      }
    }

    // Make sure to re-enable all of the fields if the sign in fails
    if (!canFinish) {
      setState(() => isLoading = false);
    }
  }

  Widget get signInButton => LoginButton(
    text: 'Sign in',
    callback: isLoading ? null : () => submitForm(SignInType.signIn),
  );

  Widget get signUpButton => LoginButton(
    text: 'Sign up',
    callback: isLoading ? null : () => submitForm(SignInType.signUp),
  );

  Widget get googleButton => ElevatedButton(
    style: ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white.harmonizeWith(
        Theme.of(context).colorScheme.primaryContainer,
      ),
    ),
    onPressed: () => submitForm(SignInType.google),
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child:
          isLoading && signInType == SignInType.google
              ? const CircularProgressIndicator()
              : Text(
                'Sign in with Google',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall!.copyWith(color: Colors.black),
              ),
    ),
  );

  Widget get emailField => TextFormField(
    enabled: !isLoading,
    validator: validateEmail,
    forceErrorText: usernameError,
    keyboardType: TextInputType.emailAddress,
    controller: usernameController,
    decoration: const InputDecoration(
      label: Text('Email'),
      border: OutlineInputBorder(),
    ),
  );

  Widget get passwordField => TextFormField(
    enabled: !isLoading,
    controller: passwordController,
    autocorrect: false,
    obscureText: !passwordIsVisible,
    enableSuggestions: false,
    forceErrorText: passwordError,
    validator: (value) {
      if (value == null || value.trim().isEmpty) {
        return 'Required';
      }

      return null;
    },
    decoration: InputDecoration(
      suffixIcon: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: IconButton(
          icon:
              passwordIsVisible
                  ? const Icon(Icons.visibility_off)
                  : const Icon(Icons.visibility),
          onPressed:
              () => setState(() => passwordIsVisible = !passwordIsVisible),
        ),
      ),
      label: const Text('Password'),
      border: const OutlineInputBorder(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Log in',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        Text(
                          'To access your budget',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: emailField,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: passwordField,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child:
                        isLoading
                            ? DisabledButtonOverlay(child: signInButton)
                            : signInButton,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child:
                        isLoading
                            ? DisabledButtonOverlay(child: signUpButton)
                            : signUpButton,
                  ),
                ],
              ),
              isLoading
                  ? DisabledButtonOverlay(child: googleButton)
                  : googleButton,
            ],
          ),
        ),
      ),
    );
  }
}

class DisabledButtonOverlay extends StatelessWidget {
  final Widget child;

  const DisabledButtonOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(150),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginButton extends StatelessWidget {
  final String text;
  final void Function()? callback;

  const LoginButton({super.key, this.callback, required this.text});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        disabledBackgroundColor: Theme.of(context).colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      onPressed: callback,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          text,
          style: Theme.of(context).textTheme.headlineSmall!.copyWith(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
