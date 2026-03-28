import 'package:get_storage/get_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../Api/urls.dart';

class BackgroundSocketController {
  IO.Socket? socket;

  Future<void> initSocket() async {
    await GetStorage.init();
    final ownId = GetStorage().read("userId") ?? "";

    socket = IO.io(
      ApiPath.socketUrl, // 🔴 change to your socket server URL
      IO.OptionBuilder()
          .setTransports(["websocket"])
          .enableAutoConnect()
          .enableForceNew()
          .build(),
    );

    socket?.onConnect((_) {
      //  print("✅ Background Socket connected with ID: $ownId");
      socket?.emit("join", {"userId": ownId});
    });

    socket?.onDisconnect((_) {
      // print("❌ Background Socket disconnected");
    });
  }

  void emitDelivery({
    required String msgId,
    required String userId,
    required List<String> receiverId,
  }) {
    if (socket == null || socket?.connected == false) {
      //  print("⚠️ Socket not connected in background, reconnecting...");
      initSocket();
    }

    socket?.emit("deliver", {
      "msgId": msgId,
      "userId": userId,
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "receiverId": receiverId,
    });
    //  print("📩 Background deliver event emitted");
  }

  void dispose() {
    socket?.dispose();
  }
}
