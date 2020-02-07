// App shell
import 'dart:async';
import 'package:upubsub_mobile/BitcoinOfThings_feed.dart';
import 'package:flutter/material.dart';
import 'components/notifications.dart';
import 'home_page.dart';
import 'package:logging/logging.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:event_bus/event_bus.dart';


//
// added to route the logging info - the file and where in the file
// the message came from.
//

void main() {
  initLogger();
  GlobalNotifier.wireUp();
  runApp(BOTApp());
}

class AppMessage {
  final String topic;
  final Map<String, dynamic> payload;
  AppMessage(this.topic, this.payload);
}

typedef void WhenSomethingFunc(AppMessage event);

// Application Event bus
class Bus {
  static final EventBus _bus = EventBus();
  // publish an event
  static void publishMessage(AppMessage event) => _bus.fire(event);
  static void publish(String topic, Map<String, dynamic> payload) => _bus.fire(
    AppMessage(topic, payload));

  // subscribe to events
  static void subscribe(WhenSomethingFunc func) =>
  _bus.on<AppMessage>().listen((event) => func(event));

}

// one notifier for all sub streams (for now)
// could cause memory leaks if not careful
class GlobalNotifier {
  // anywhere in app call 
  // GlobalNotifier.notifications.show(...)
  static Notifications notifications = new Notifications();
  static StreamSubscription botMux;

  static void wireUp () {
    GlobalNotifier.botMux = BitcoinOfThingsMux.stream.listen( (botmsg) {
      var notemsg = NotificationMessage(
        botmsg.streamName != null ? botmsg.streamName : "unknown topic", 
        //TODO: decode, use .object
        botmsg.rawString);
      // then just show a notification
      GlobalNotifier.notifications.show(notemsg);
    } );
  }

  static void show(something) {
    var notemsg = NotificationMessage(
        'You ought to know...', 
        something);
    GlobalNotifier.notifications.show(notemsg);
  }

  static void cancel() { 
    botMux?.cancel(); 
    BitcoinOfThingsMux.close();
  }

  static void pause() { botMux?.pause(); }
  static void resume() { botMux?.resume(); }

}

class BOTApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BOT Mobile',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(title: 'uPub\$ub'),
    );
  }
}

void initLogger() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((LogRecord rec) {
      final List<Frame> frames = Trace.current().frames;
      try {
        final Frame f = frames.skip(0).firstWhere((Frame f) =>
            f.library.toLowerCase().contains(rec.loggerName.toLowerCase()) &&
            f != frames.first);
        print(
            '${rec.level.name}: ${f.member} (${rec.loggerName}:${f.line}): ${rec.message}');
      } catch (e) {
        print(e.toString());
      }
    });
  }
