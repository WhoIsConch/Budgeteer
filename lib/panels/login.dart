import 'package:budget/tools/enums.dart';
import 'package:budget/tools/validators.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  String? usernameError;
  String? passwordError;

  void submitForm(SignInType type) async {
    setState(() {
      usernameError = null;
      passwordError = null;
      isLoading = true;
    });

    bool canFinish = false;

    if (!_formKey.currentState!.validate()) {
      setState(() => isLoading = false);
      return;
    }

    if (type == SignInType.signIn) {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: usernameController.text, password: passwordController.text);
        canFinish = true;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          setState(() => usernameError = "Account doesn't exist");
        } else if (e.code == 'wrong-password') {
          setState(() => passwordError = "Incorrect password");
        } else if (e.code == 'invalid-email') {
          setState(() => usernameError = "Invalid email address");
        } else {
          scaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
              content: Text("An unknown error occurred: ${e.message}")));
        }
      }
    } else if (type == SignInType.signUp) {
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: usernameController.text, password: passwordController.text);
        canFinish = true;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          setState(() => passwordError = "Too weak");
        } else if (e.code == 'email-already-in-use') {
          setState(() => usernameError = "Email already in use");
        } else {
          scaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
              content: Text("An unknown error occurred: ${e.message}")));
        }
      }
    }

    // Make sure to re-enable all of the fields if the sign in fails
    if (!canFinish) {
      setState(() => isLoading = false);
    }
  }

  Widget get signInButton => LoginButton(
        text: "Sign in",
        callback: isLoading ? null : () => submitForm(SignInType.signIn),
      );

  Widget get signUpButton => LoginButton(
        text: "Sign up",
        callback: isLoading ? null : () => submitForm(SignInType.signUp),
      );

  Widget get emailField => TextFormField(
        enabled: !isLoading,
        validator: validateEmail,
        forceErrorText: usernameError,
        controller: usernameController,
        decoration: const InputDecoration(
            label: Text("Email"), border: OutlineInputBorder()),
      );

  Widget get passwordField => TextFormField(
        enabled: !isLoading,
        controller: passwordController,
        autocorrect: false,
        obscureText: !passwordIsVisible,
        enableSuggestions: false,
        forceErrorText: passwordError,
        decoration: InputDecoration(
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: passwordIsVisible
                    ? const Icon(Icons.visibility_off)
                    : const Icon(Icons.visibility),
                onPressed: () =>
                    setState(() => passwordIsVisible = !passwordIsVisible),
              ),
            ),
            label: const Text("Password"),
            border: const OutlineInputBorder()),
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
                padding: EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Log in",
                            style: Theme.of(context).textTheme.headlineLarge),
                        Text("To access your budget",
                            style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 16),
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: emailField),
                        Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: passwordField),
                      ]),
                ),
              )),
          Row(
            children: [
              Expanded(
                  child: isLoading
                      ? DisabledButtonOverlay(child: signInButton)
                      : signInButton),
              const SizedBox(width: 8.0),
              Expanded(
                  child: isLoading
                      ? DisabledButtonOverlay(child: signUpButton)
                      : signUpButton),
            ],
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                backgroundColor: Colors.white.harmonizeWith(
                    Theme.of(context).colorScheme.primaryContainer)),
            onPressed: null,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("Sign in with Google",
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall!
                      .copyWith(color: Colors.black)),
            ),
          ),
        ],
      ),
    )));
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
                borderRadius: BorderRadius.circular(12)),
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
          disabledBackgroundColor:
              Theme.of(context).colorScheme.primaryContainer,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer),
      onPressed: callback,
      child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(text,
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer))),
    );
  }
}
