// Show chat
// 1. fix scrolling, top and bottom cut off couple dozen pixels
// 2. fix display images on ios
// ============================

import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'app_events.dart';
import 'chat/dash_chat.dart';
import 'package:upubsub_mobile/models/Subscription.dart';
import 'components/bus.dart';
import 'components/exception_reporter.dart';
import 'mqtt_stream.dart';
import 'helpers/constants.dart' as PubSubConstants;

// display chat in a page
class ChatView extends StatefulWidget {
  @override
  _ChatState createState() => _ChatState();
}

class _ChatState extends State<ChatView> {
  final GlobalKey<DashChatState> _chatViewKey = GlobalKey<DashChatState>();
  StreamSubscription _chatSubscription;

  // bot injects some auto generated messages into stream
  ChatUser _bot = ChatUser(
    name: "Chat Bot",
    uid: "0123",
    avatar: 
    "https://upubsub.com/static/images/Customer-Support-Icon.jpg"
    //"https://encrypted-tbn0.gstatic.com/images?q=tbn%3AANd9GcTiTK6pMtIb5hAtMBd93Fr_XIbYmzvl9n-4h6tq0HooGqvQjWST"
    //"https://cdn1.iconfinder.com/data/icons/user-pictures/100/supportfemale-512.png",
  );

  // the current user, loaded from local storage
  ChatUser _me; 

  List<ChatMessage> messages = List<ChatMessage>();
  var m = List<ChatMessage>();

  Subscription _sub;

  var i = 0;

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void initState() {
    super.initState();
    _chatSubscription = Bus.subscribe((msg) {
      if (msg.topic == PubSubConstants.Constants.KEY_CHATUSER) {
        this.setState(() => this._me = new ChatUser(
          name: msg.payload["name"],
          uid: msg?.payload["moneyButtonId"] == null
            ? msg.payload["name"] : msg?.payload["moneyButtonId"],
          avatar: msg?.payload["avatar"] == null
            ? '' : msg?.payload["avatar"],
          password: msg?.payload["pass"] == null
            ? '' : msg?.payload["pass"]
          )
        );
      }
      if (msg.topic == PubSubConstants.Constants.STREAM_ERROR) {
        //todo how to know it was chat error
        this.messages.add(ChatMessage(
          text: msg?.payload["error"],
          user: this._bot
        ));
      }
    });
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    super.dispose();
  }

  // _me will be populated when dialog closed
  Future<void> getUser() async {
    if (_me == null) return; // should never be null
    // subscribe to group/support
    try {
      this._sub = await _getSubscription(this._me);
      if (this._sub != null) {
        this._sub.setSingleplexStream();
        this._sub.pubsub = new PubSubConnection(this._sub);
        this._sub.enabled = true;
        var welcome;
        try {
          await this._sub.subscribe();
          welcome = ChatMessage(
            text:"Hello ${this._me.name}! Welcome to Pub\$ub support chat. Ask your support question here and someone should be available shortly to answer.", 
            user: this._bot);
        }
        catch (ex) {
          // ${ex.toString()}.
          welcome = ChatMessage(
            text:"Hello ${this._me.name}! ${ex.toString()}. There was an error. Chat is not available. Contact support at http://upubsub.com", 
            user: this._bot);
        }
        _sub.stream.add(
          StreamMessage(
            _sub.topic,
            jsonEncode(welcome.toJson())
        ));
      }
    }
    catch (ex, st) {
      ExceptionReporter.reportException(ex, st);
      AppEvents.publish(ex.toString());
    }
  }

  void systemMessage() {
    Timer(Duration(milliseconds: 300), () {
      if (i < 6) {
        setState(() {
          messages = [...messages, m[i]];
        });
        i++;
      }
      Timer(Duration(milliseconds: 300), () {
        _chatViewKey.currentState.scrollController
          ..animateTo(
            _chatViewKey.currentState.scrollController.position.maxScrollExtent,
            curve: Curves.easeOut,
            duration: const Duration(milliseconds: 300),
          );
      });
    });
  }

  // send a chat message == publish
  void onSend(ChatMessage message) {
    // message could have control chars if
    // user typed in emoji
    var jmess = message.toJson();
    //publish on customer service topic
    this._sub.publish(jsonEncode(jmess));
  }

  Widget waiting() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return this._me == null 
    ? waiting()
    : Container(
          child:
          FutureBuilder<void>(
        future: getUser(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return _chatStream();
          } else {
            return waiting();
          }
        }
      )
    );
  }

  Widget _chatStream() {
  return
    StreamBuilder(
      stream: _sub.stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return waiting();
        } else {
          //print(snapshot);
          final streammessage = snapshot.data;
          ChatMessage message;
          if (streammessage.object != null) {
            try {
              message = ChatMessage.fromJson(streammessage.object);
            }
            catch (err) {
              message = new ChatMessage(text: streammessage.rawString, 
              user: _bot);
            }
          } else {
              message = new ChatMessage(text: streammessage.rawString, 
              user: _bot);
          }
          messages.add(message);
          // var messages =
          //     items.map((i) => ChatMessage.fromJson(i.data)).toList();
          return DashChat(
            key: _chatViewKey,
            inverted: false,
            onSend: onSend,
            user: _me,
            inputDecoration:
                InputDecoration.collapsed(hintText: "Add message here..."),
            dateFormat: DateFormat('yyyy-MMM-dd'),
            timeFormat: DateFormat('HH:mm'),
            messages: messages,
            showUserAvatar: true,
            showAvatarForEveryMessage: true,
            scrollToBottom: true,
            onPressAvatar: (ChatUser user) {
                // user avatar popup action menu
                showDialog(
                  context: context,
                  builder: (BuildContext context) => 
                    _buildAvatarDialog(user),
              );
            },
            onLongPressAvatar: (ChatUser user) {
              print("OnLongPressAvatar: ${user.name}");
            },
            inputMaxLines: 5,
            messageContainerPadding: EdgeInsets.only(left: 5.0, right: 5.0),
            alwaysShowSend: true,
            inputTextStyle: TextStyle(fontSize: 16.0),
            inputContainerStyle: BoxDecoration(
              border: Border.all(width: 0.0),
              color: Colors.white,
            ),
            onQuickReply: (Reply reply) {
              setState(() {
                messages.add(ChatMessage(
                  text: reply.value,
                  createdAt: DateTime.now(),
                  user: _me));

                messages = [...messages];
              });

              Timer(Duration(milliseconds: 300), () {
                _chatViewKey.currentState.scrollController
                  ..animateTo(
                    _chatViewKey.currentState.scrollController.position
                        .maxScrollExtent,
                    curve: Curves.easeOut,
                    duration: const Duration(milliseconds: 300),
                  );

                if (i == 0) {
                  systemMessage();
                  Timer(Duration(milliseconds: 600), () {
                    systemMessage();
                  });
                } else {
                  systemMessage();
                }
              });
            },
            onLoadEarlier: () {
              print("loading...");
            },
            shouldShowLoadEarlier: false,
            showTraillingBeforeSend: true,
            trailing: <Widget>[
              IconButton(
                icon: Icon(Icons.photo),
                onPressed: () async {
                  File result = await ImagePicker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 80,
                    maxHeight: 400,
                    maxWidth: 400,
                  );
                  if (result != null) {
                    // when user selected an image... 
                    Uint8List bytes = await result.readAsBytes();
                    // set text as empty string, null produces exception
                    ChatMessage image = new ChatMessage(text: '', user: _me, 
                      image: base64Encode(bytes));
                    onSend(image);                      
                  }
                },
              )
            ],
          );
        }
      });
  }

  Widget _buildAvatarDialog(ChatUser user) {
    return new AlertDialog(
      title: Text(user.name),
      content: new Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Something good coming...'),
        ],
      ),
      actions: <Widget>[
        new FlatButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          textColor: Theme.of(context).primaryColor,
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<Subscription> _getSubscription(ChatUser user) async {

    // auth is either user/pwd from localstorage
    // or chatuser.username
    var auth = {"p":user.name, "u": user.password};

    var response = await http.post(
        "https://api.bitcoinofthings.com/getchat",
        body: jsonEncode(auth),
        headers: {HttpHeaders.contentTypeHeader: "application/json"},
        );
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        var data = jsonResponse;
        if (data != null ) {
          var sub = Subscription.fromJSON(data);
          return sub;
        } else {
          print('Not Authorized!');
        }
      } else {
        print('Request failed with status: ${response.statusCode}.');
      }
    return null;

  }


}
