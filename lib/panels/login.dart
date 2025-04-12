import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
            child: Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Sign In",
                            style: Theme.of(context).textTheme.headlineLarge),
                      ]),
                ))));
  }
}
