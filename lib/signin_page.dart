import 'helpers/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:upubsub_mobile/app_events.dart';
import 'package:upubsub_mobile/components/web_link.dart';
import 'package:upubsub_mobile/helpers/urllauncher.dart';
import 'dart:async';
import 'auth/auth_state.dart';
import 'dart:convert' as convert;
import 'package:http/http.dart' as http;
import 'dart:io';
import 'components/localStorage.dart';
import 'main.dart';

class SignInPage extends StatefulWidget {
  final StreamController<AuthenticationState> _streamController;

  SignInPage(this._streamController);
  // MyHomePage({Key key, this.title}) : super(key: key);

  @override
  SignInPageState createState() => SignInPageState(this._streamController);
}

class SignInPageState extends State<SignInPage> {
  final StreamController<AuthenticationState> _streamController;
  TextStyle style = TextStyle(fontFamily: 'Montserrat', fontSize: 20.0);

  SignInPageState(this._streamController);

  //TextEditingController emailController = TextEditingController();
  //TextEditingController passwordController = TextEditingController();
  // emailController = new TextEditingController(text: defaultuser);
  // passwordController = new TextEditingController(text: defaultpass);
  String _defaultUser;
  String _defaultPass;
  String _submittedUser;
  String _submittedPass;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
  }

  Future<void> getLocalUser() async {
    final usercred = await LocalStorage.getJSON(Constants.KEY_CRED);
    _defaultUser = usercred == null ? '' : usercred["username"] ?? '';
    _defaultPass = usercred == null ? '' : usercred["pass"] ?? '';
  }

  signIn() async {
    //validate email and password
    var username =  _submittedUser;
    var pass = _submittedPass;
    if (username?.length == 0 || pass?.length == 0) {
      print("NO TEXT TO VALIDATE");
      return false;
    }
    var authcheck = await valauth(username,pass);
    // auth:,user:
    if (authcheck["auth"] == true) {
      LocalStorage.putJSON(Constants.KEY_CRED, {"username":username,"pass":pass});
      LocalStorage.putJSON(Constants.KEY_USER, authcheck["user"]);
      _streamController.add(AuthenticationState.authenticated());
      AppEvents.publish('User logged in');
      GlobalNotifier.resume();
    } else {
      LocalStorage.putJSON(Constants.KEY_CRED, {});
      LocalStorage.putJSON(Constants.KEY_USER, {});
      _streamController.add(AuthenticationState.failed());
      AppEvents.publish('Login failed');
    }
  }

    // returns auth:bool, user: userinfo
    Future<dynamic> valauth(mbid, password) async {
    //get auth from api
    var url = 'https://api.bitcoinofthings.com/valauth';
      var response = await http.post(
        url,
        body: convert.jsonEncode({"p":mbid, "u":password}),
        headers: {HttpHeaders.contentTypeHeader: "application/json"},
        );
      if (response.statusCode == 200) {
        var jsonResponse = convert.jsonDecode(response.body);
        // var success = jsonResponse["auth"];
        // if (success != null ) {
        //   return jsonResponse;
        // } 
        return jsonResponse;
      } else {
        print('Request failed with status: ${response.statusCode}.');
      }
    return false;
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: SingleChildScrollView(
      child: Center(
        child: Container(
          color: Colors.white,
          child: FutureBuilder<void>(
            future: getLocalUser(),
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return _loginForm();
              } else {
                return new CircularProgressIndicator();
              }
            }
          ),
        ),
      )
    )
 );
}

Widget _loginForm() {
    final emailField = TextFormField(
      initialValue: _defaultUser,
      //controller: emailController,
      validator: validateUser,
      keyboardType: TextInputType.number,
      onSaved: (value) {
        setState(() => _submittedUser = value );
      },
      obscureText: true,
      style: style,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "MoneyButton Id",
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final passwordField = TextFormField(
      initialValue: _defaultPass,
      //controller: passwordController,
      validator: validatePassword,
      keyboardType: TextInputType.text,
      onSaved: (value) {
        setState(() => _submittedPass = value );
      },
      obscureText: true,
      style: style,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "API Password",
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final loginButon = Material(
      elevation: 5.0,
      borderRadius: BorderRadius.circular(30.0),
      color: Color(0xff01A0C7),
      child: MaterialButton(
        minWidth: MediaQuery.of(context).size.width,
        padding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
        onPressed: () {
          if (_formKey.currentState.validate()) {
            _formKey.currentState.save();
            signIn();
          }
        },
        child: Text("Login",
            textAlign: TextAlign.center,
            style: style.copyWith(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );

  return Form(
    key: _formKey,
    child: Padding(
            padding: const EdgeInsets.all(36.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  height: 45.0,
                  child:webLink('Use your API login from the web site')),
                SizedBox(height: 1.0),
                emailField,
                SizedBox(height: 15.0),
                passwordField,
                SizedBox(height: 15.0),
                loginButon,
                SizedBox(height: 15.0),
                SizedBox(
                  height: 75.0,
                  child:webLink('Create API login on web site')),
                SizedBox(height: 5.0),
                pubsubLogo(),
              ],
            ),
          )
  );
}

  String validateUser(String value) {
      if (value.isEmpty) {
        return 'Please enter MoneybuttonId';
      }
      return null;
      // Pattern pattern =
      //     r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
      // RegExp regex = new RegExp(pattern);
      // if (!regex.hasMatch(value))
      //   return 'Enter Valid MoneybuttonId';
      // else
      //   return null;
  }

  String validatePassword(String value) {
      if (value.isEmpty) {
        return 'Please enter Password';
      }
      return null;
      // Pattern pattern =
      //     r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
      // RegExp regex = new RegExp(pattern);
      // if (!regex.hasMatch(value))
      //   return 'Enter Valid MoneybuttonId';
      // else
      //   return null;
  }

Widget pubsubLogo () => 
  SizedBox(
    height: 175.0,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20.0),
      child: GestureDetector(
        onTap: () { UrlLauncher.goHome(); }, // handle your image tap here
        child: Image.asset(
      "assets/PubSublogo.png",
      fit: BoxFit.contain,
      ),
      ),
    ),
  );


}