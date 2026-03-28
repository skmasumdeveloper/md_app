(function () {
  var state = {
    socket: null,
    roomId: "",
    userId: "",
    fullName: "",
    callType: "video",
    joinEvent: "BE-join-room",
    leaveEvent: "BE-leave-room",
    localStream: null,
    sendTransport: null,
    recvTransport: null,
    device: null,
    audioProducer: null,
    videoProducer: null,
    consumers: {},
    consumedProducerIds: {},
    remoteStreams: {},
    remoteUserMeta: {},
    participantDirectory: {},
    isMicEnabled: true,
    isCameraEnabled: true,
    isSpeakerEnabled: true,
    hasRealDevices: false,
    facingMode: "user",
    groupName: "Group Call",
  };

  var mediasoupLoaderPromise = null;

  function postToFlutter(type, payload) {
    var msg = JSON.stringify({ type: type, payload: payload || {} });
    if (window.FlutterBridge && window.FlutterBridge.postMessage) {
      window.FlutterBridge.postMessage(msg);
    }
  }

  function setStatus(text, sub) {
    $("#statusPill").text(text);
    if (sub) {
      $("#subTitle").text(sub);
    }
    postToFlutter("state", { state: text });
  }

  function escapeHtml(value) {
    if (value == null) return "";
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function getDisplayName(userId) {
    if (!userId) return "Unknown";
    if (userId === state.userId) return "You";

    var meta = state.remoteUserMeta[userId] || {};
    var byMeta = meta.senderName || meta.name || meta.fullName;
    var byDirectory = state.participantDirectory[userId];
    if (byMeta) return String(byMeta);
    if (byDirectory) return String(byDirectory);

    if (String(userId).length > 8) {
      return "User " + String(userId).slice(0, 6) + "...";
    }
    return String(userId);
  }

  function setLocalAudioBadge(enabled) {
    var badge = document.getElementById("localBadge");
    if (!badge) return;
    if (enabled) {
      badge.classList.remove("muted");
      badge.textContent = "local";
    } else {
      badge.classList.add("muted");
      badge.textContent = "muted";
    }
  }

  function setRemoteAudioBadge(userId, enabled) {
    var badge = document.getElementById("badge-" + userId);
    var muteIcon = document.getElementById("mute-" + userId);

    if (!badge) return;

    if (enabled === false) {
      badge.classList.add("muted");
      badge.textContent = "muted";
      if (muteIcon) {
        muteIcon.classList.add("show");
      }
    } else {
      badge.classList.remove("muted");
      badge.textContent = "remote";
      if (muteIcon) {
        muteIcon.classList.remove("show");
      }
    }
  }

  function updateRemoteTileMeta(userId) {
    var name = document.getElementById("name-" + userId);
    if (name) {
      name.textContent = getDisplayName(userId);
    }

    var meta = state.remoteUserMeta[userId] || {};
    if (typeof meta.audio === "boolean") {
      setRemoteAudioBadge(userId, meta.audio);
    }
  }

  function updateGridLayout() {
    var grid = document.getElementById("grid");
    if (!grid) return;

    var remoteTiles = Array.from(
      grid.querySelectorAll(".tile[id^='remote-']")
    );

    remoteTiles.forEach(function (tile) {
      tile.classList.remove("primary-remote");
    });

    grid.classList.remove("layout-single", "layout-dual", "layout-multi");

    var remoteCount = remoteTiles.length;
    if (remoteCount === 0) {
      grid.classList.add("layout-single");
      grid.style.removeProperty("--remote-cols");
      return;
    }

    if (remoteCount === 1) {
      grid.classList.add("layout-dual");
      remoteTiles[0].classList.add("primary-remote");
      grid.style.removeProperty("--remote-cols");
      return;
    }

    grid.classList.add("layout-multi");

    var totalParticipants = remoteCount + 1;
    var cols = totalParticipants <= 4 ? 2 : 3;
    grid.style.setProperty("--remote-cols", String(cols));
  }

  function ensureMediasoupDeviceCtor() {
    var globalClient = window.mediasoupClient || window.mediasoupclient;
    if (!globalClient) return null;
    return globalClient.Device || (globalClient.default && globalClient.default.Device) || null;
  }

  function loadMediasoupClient() {
    if (ensureMediasoupDeviceCtor()) {
      return Promise.resolve();
    }

    if (mediasoupLoaderPromise) {
      return mediasoupLoaderPromise;
    }

    var urls = [
      "https://esm.sh/mediasoup-client@3.18.7?bundle",
      "https://esm.sh/mediasoup-client@3.18.7",
      "https://cdn.skypack.dev/mediasoup-client@3.18.7"
    ];

    mediasoupLoaderPromise = (async function () {
      for (var i = 0; i < urls.length; i += 1) {
        var url = urls[i];
        try {
          var mod = await import(url);
          if (mod) {
            window.mediasoupClient = mod;
            if (ensureMediasoupDeviceCtor()) {
              window.dispatchEvent(new Event("mediasoup-ready"));
              return;
            }
          }
        } catch (_) {}
      }

      throw new Error("mediasoup-load-failed");
    })();

    return mediasoupLoaderPromise;
  }

  function waitForMediasoupReady(timeoutMs) {
    timeoutMs = timeoutMs || 12000;
    return new Promise(function (resolve, reject) {
      if (ensureMediasoupDeviceCtor()) {
        resolve();
        return;
      }

      var done = false;
      var t = setTimeout(function () {
        if (!done) {
          done = true;
          reject(new Error("mediasoup-load-timeout"));
        }
      }, timeoutMs);

      function onReady() {
        if (done) return;
        done = true;
        clearTimeout(t);
        window.removeEventListener("mediasoup-ready", onReady);
        resolve();
      }

      window.addEventListener("mediasoup-ready", onReady);

      loadMediasoupClient().catch(function (err) {
        if (!done) {
          done = true;
          clearTimeout(t);
          window.removeEventListener("mediasoup-ready", onReady);
          reject(err);
        }
      });
    });
  }

  function createDummyStream(wantsVideo) {
    var stream = new MediaStream();

    try {
      var AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (AudioCtx) {
        var audioCtx = new AudioCtx();
        var oscillator = audioCtx.createOscillator();
        var gain = audioCtx.createGain();
        gain.gain.value = 0.0001;
        oscillator.connect(gain);
        var dest = audioCtx.createMediaStreamDestination();
        gain.connect(dest);
        oscillator.start();

        var audioTrack = dest.stream.getAudioTracks()[0];
        if (audioTrack) {
          stream.addTrack(audioTrack);
        }
      }
    } catch (_) {}

    if (wantsVideo) {
      try {
        var canvas = document.createElement("canvas");
        canvas.width = 640;
        canvas.height = 360;
        var ctx = canvas.getContext("2d");
        if (ctx) {
          ctx.fillStyle = "#0f172a";
          ctx.fillRect(0, 0, canvas.width, canvas.height);
          ctx.fillStyle = "#94a3b8";
          ctx.font = "bold 20px sans-serif";
          ctx.fillText("No Camera", 240, 180);
        }

        var canvasStream = canvas.captureStream(5);
        var videoTrack = canvasStream.getVideoTracks()[0];
        if (videoTrack) {
          stream.addTrack(videoTrack);
        }
      } catch (_) {}
    }

    return stream;
  }

  function emitAck(eventName, payload, timeoutMs, options) {
    timeoutMs = timeoutMs || 15000;
    options = options || {};
    return new Promise(function (resolve, reject) {
      if (!state.socket) {
        reject(new Error("socket-not-ready"));
        return;
      }

      var done = false;
      var t = setTimeout(function () {
        if (!done) {
          done = true;
          reject(new Error(eventName + " timeout"));
        }
      }, timeoutMs);

      try {
        var ack = function (res) {
          if (done) return;
          done = true;
          clearTimeout(t);
          resolve(res);
        };

        if (options.noPayload === true) {
          // Some backend handlers are callback-only: socket.on(event, (cb) => ...)
          // Sending a payload would shift the callback argument and cause timeouts.
          state.socket.emit(eventName, ack);
        } else {
          state.socket.emit(eventName, payload || {}, ack);
        }
      } catch (err) {
        if (!done) {
          done = true;
          clearTimeout(t);
          reject(err);
        }
      }
    });
  }

  function removeTracksOfKind(stream, kind) {
    var tracks = kind === "video" ? stream.getVideoTracks() : stream.getAudioTracks();
    tracks.forEach(function (t) {
      stream.removeTrack(t);
    });
  }

  function upsertRemoteTile(userId, stream, kind) {
    var tileId = "remote-" + userId;
    var existing = document.getElementById(tileId);

    if (!existing) {
      var tile = document.createElement("section");
      tile.id = tileId;
      tile.className = "tile remote";

      var video = document.createElement("video");
      video.autoplay = true;
      video.playsInline = true;
      video.id = "video-" + userId;
      tile.appendChild(video);

      var mute = document.createElement("div");
      mute.id = "mute-" + userId;
      mute.className = "mute-icon";
      mute.innerHTML = "<span class=\"mute-icon-symbol\">🔇</span>";
      tile.appendChild(mute);

      var meta = document.createElement("div");
      meta.className = "meta";
      meta.innerHTML = "<span class=\"name\" id=\"name-" + userId + "\">" +
        escapeHtml(getDisplayName(userId)) +
        "</span><span id=\"badge-" + userId + "\" class=\"badge\">remote</span>";
      tile.appendChild(meta);

      document.getElementById("grid").appendChild(tile);
      existing = tile;
    }

    var videoEl = document.getElementById("video-" + userId);
    if (videoEl && stream) {
      videoEl.srcObject = stream;
      videoEl.play().catch(function () {});
    }

    if (kind === "audio") {
      var audioEnabled = stream.getAudioTracks().some(function (track) {
        return track.enabled;
      });
      var meta = state.remoteUserMeta[userId] || {};
      meta.audio = audioEnabled;
      state.remoteUserMeta[userId] = meta;
      setRemoteAudioBadge(userId, audioEnabled);
      postToFlutter("remote_audio", {
        userId: userId,
        enabled: audioEnabled,
      });
    }

    updateRemoteTileMeta(userId);
    updateGridLayout();
  }

  async function initializeMedia() {
    var wantsVideo = state.callType === "video";
    state.hasRealDevices = false;
    setStatus("media_init", "Requesting microphone/camera...");

    var constraints = {
      audio: true,
      video: wantsVideo
        ? {
            facingMode: state.facingMode,
            width: { ideal: 960, max: 1280 },
            height: { ideal: 540, max: 720 },
            frameRate: { ideal: 15, max: 20 },
          }
        : false,
    };

    try {
      state.localStream = await navigator.mediaDevices.getUserMedia(constraints);
      state.hasRealDevices = true;
    } catch (err) {
      // Retry with simpler constraints before falling back.
      if (wantsVideo) {
        try {
          state.localStream = await navigator.mediaDevices.getUserMedia({
            audio: true,
            video: true,
          });
          state.hasRealDevices = true;
        } catch (_) {}
      }

      // Retry with audio-only before falling back to a dummy stream.
      try {
        if (!state.localStream) {
          state.localStream = await navigator.mediaDevices.getUserMedia({ audio: true, video: false });
          state.hasRealDevices = true;
        }
      } catch (_) {
        state.localStream = createDummyStream(wantsVideo);
      }
    }

    if (!state.localStream) {
      state.localStream = createDummyStream(wantsVideo);
    }

    var localVideo = document.getElementById("localVideo");
    localVideo.srcObject = state.localStream;
    localVideo.play().catch(function () {});

    state.isCameraEnabled = state.localStream.getVideoTracks().length > 0;
    state.isMicEnabled = state.localStream.getAudioTracks().length > 0;
    setLocalAudioBadge(state.isMicEnabled);

    if (!state.hasRealDevices) {
      setStatus("media_fallback", "Using fallback media stream (camera/mic unavailable).");
    }

    postToFlutter("mic", { enabled: state.isMicEnabled });
    postToFlutter("camera", { enabled: state.isCameraEnabled });
  }

  async function connectSocket(socketUrl) {
    if (state.socket) {
      try {
        state.socket.disconnect();
      } catch (_) {}
      state.socket = null;
    }

    state.socket = io(socketUrl, {
      transports: ["websocket"],
      reconnection: true,
      reconnectionAttempts: 12,
      reconnectionDelay: 1200,
      timeout: 20000,
    });

    state.socket.on("connect", function () {
      setStatus("socket_connected", "Socket connected. Joining call room...");
      postToFlutter("connected", { socketId: state.socket.id });
      state.socket.emit("joinSelf", state.userId);
    });

    state.socket.on("FE-user-join", function (users) {
      if (Array.isArray(users) && users.length === 1 && Array.isArray(users[0])) {
        users = users[0];
      }

      if (!Array.isArray(users)) return;

      users.forEach(function (entry) {
        if (!entry || typeof entry !== "object") return;

        var socketId = entry.userId ? String(entry.userId) : "";
        var info = entry.info && typeof entry.info === "object" ? entry.info : {};
        var userName = info.userName ? String(info.userName) : "";

        if (!userName) return;
        if (userName === state.userId) return;
        if (socketId && state.socket && socketId === state.socket.id) return;

        var displayName =
          info.senderName ||
          info.name ||
          info.fullName ||
          state.participantDirectory[userName] ||
          userName;

        state.participantDirectory[userName] = String(displayName);
        state.remoteUserMeta[userName] = {
          socketId: socketId,
          senderName: info.senderName || "",
          name: info.name || displayName,
          fullName: info.fullName || info.name || displayName,
          audio: info.audio !== false,
          video: info.video !== false,
        };

        if (!state.remoteStreams[userName]) {
          state.remoteStreams[userName] = new MediaStream();
        }

        upsertRemoteTile(userName, state.remoteStreams[userName], "video");

        if (typeof info.audio === "boolean") {
          setRemoteAudioBadge(userName, info.audio);
          postToFlutter("remote_audio", {
            userId: userName,
            enabled: info.audio,
          });
        }
      });

      updateGridLayout();
    });

    state.socket.on("MS-new-producer", async function (payload) {
      try {
        if (!payload || !payload.producerId) return;
        if (state.consumedProducerIds[payload.producerId]) return;
        await consumeProducer(payload.producerId, payload.userId, payload.kind);
      } catch (err) {
        console.error("MS-new-producer consume error", err);
      }
    });

    state.socket.on("FE-user-leave", function (payload) {
      var userName = payload && payload.userName;
      if (!userName) return;
      delete state.remoteStreams[userName];
      delete state.remoteUserMeta[userName];
      var tile = document.getElementById("remote-" + userName);
      if (tile) tile.remove();
      updateGridLayout();
    });

    state.socket.on("FE-toggle-camera", function (payload) {
      if (Array.isArray(payload) && payload.length > 0) {
        payload = payload[0];
      }

      if (!payload || typeof payload !== "object") return;

      var switchTarget = payload.switchTarget;
      if (switchTarget !== "audio") return;

      var socketUserId = payload.userId ? String(payload.userId) : "";
      var mappedUserId = "";

      Object.keys(state.remoteUserMeta).some(function (uid) {
        if (state.remoteUserMeta[uid] && state.remoteUserMeta[uid].socketId === socketUserId) {
          mappedUserId = uid;
          return true;
        }
        return false;
      });

      if (!mappedUserId && payload.userName) {
        mappedUserId = String(payload.userName);
      }

      // Some backends may emit ObjectId directly as userId.
      if (!mappedUserId && socketUserId && state.remoteUserMeta[socketUserId]) {
        mappedUserId = socketUserId;
      }

      if (!mappedUserId && socketUserId && document.getElementById("remote-" + socketUserId)) {
        mappedUserId = socketUserId;
      }

      if (!mappedUserId || mappedUserId === state.userId) {
        return;
      }

      var meta = state.remoteUserMeta[mappedUserId] || {};
      var enabled;
      if (typeof payload.isEnabled === "boolean") {
        enabled = payload.isEnabled;
      } else if (typeof payload.audio === "boolean") {
        enabled = payload.audio;
      } else if (typeof payload.enabled === "boolean") {
        enabled = payload.enabled;
      } else {
        enabled = meta.audio === false;
      }

      meta.audio = enabled;
      state.remoteUserMeta[mappedUserId] = meta;

      setRemoteAudioBadge(mappedUserId, enabled);
      postToFlutter("remote_audio", {
        userId: mappedUserId,
        enabled: enabled,
      });
    });

    state.socket.on("FE-call-ended", function () {
      postToFlutter("ended", {});
    });
  }

  async function joinRoomAndMediasoup() {
    setStatus("joining", "Joining room and preparing SFU transports...");

    await emitAck(state.joinEvent, {
      roomId: state.roomId,
      userName: state.userId,
      fullName: state.fullName,
      callType: state.callType,
      video: state.localStream.getVideoTracks().length > 0,
      audio: state.localStream.getAudioTracks().length > 0,
      hasRealDevices: state.hasRealDevices,
    });

    var rtpCapsRes = await emitAck("MS-get-rtp-capabilities", { roomId: state.roomId });
    if (!rtpCapsRes || !rtpCapsRes.ok || !rtpCapsRes.rtpCapabilities) {
      throw new Error("rtp-capabilities-failed");
    }

    var DeviceCtor = ensureMediasoupDeviceCtor();
    if (!DeviceCtor) {
      throw new Error("mediasoup-client-not-loaded");
    }

    state.device = new DeviceCtor();
    await state.device.load({ routerRtpCapabilities: rtpCapsRes.rtpCapabilities });

    var iceCfg = await emitAck("MS-get-ice-servers", null, 15000, {
      noPayload: true,
    });
    var iceServers = (iceCfg && iceCfg.ok && iceCfg.iceServers) ? iceCfg.iceServers : [];
    var iceTransportPolicy = (iceCfg && iceCfg.iceTransportPolicy) ? iceCfg.iceTransportPolicy : "all";

    var sendInfo = await emitAck("MS-create-transport", {
      roomId: state.roomId,
      userId: state.userId,
      direction: "send",
    });

    if (!sendInfo || !sendInfo.ok) {
      throw new Error("create-send-transport-failed");
    }

    state.sendTransport = state.device.createSendTransport({
      id: sendInfo.id,
      iceParameters: sendInfo.iceParameters,
      iceCandidates: sendInfo.iceCandidates,
      dtlsParameters: sendInfo.dtlsParameters,
      iceServers: iceServers,
      iceTransportPolicy: iceTransportPolicy,
    });

    state.sendTransport.on("connect", function (_ref, callback, errback) {
      emitAck("MS-connect-transport", {
        roomId: state.roomId,
        userId: state.userId,
        transportId: state.sendTransport.id,
        dtlsParameters: _ref.dtlsParameters,
      }).then(function (res) {
        if (res && res.ok) callback();
        else errback(new Error("send-connect-failed"));
      }).catch(errback);
    });

    state.sendTransport.on("produce", function (_ref2, callback, errback) {
      emitAck("MS-produce", {
        roomId: state.roomId,
        userId: state.userId,
        transportId: state.sendTransport.id,
        kind: _ref2.kind,
        rtpParameters: _ref2.rtpParameters,
      }).then(function (res) {
        if (res && res.ok && res.id) callback({ id: res.id });
        else errback(new Error("produce-failed"));
      }).catch(errback);
    });

    var recvInfo = await emitAck("MS-create-transport", {
      roomId: state.roomId,
      userId: state.userId,
      direction: "recv",
    });

    if (!recvInfo || !recvInfo.ok) {
      throw new Error("create-recv-transport-failed");
    }

    state.recvTransport = state.device.createRecvTransport({
      id: recvInfo.id,
      iceParameters: recvInfo.iceParameters,
      iceCandidates: recvInfo.iceCandidates,
      dtlsParameters: recvInfo.dtlsParameters,
      iceServers: iceServers,
      iceTransportPolicy: iceTransportPolicy,
    });

    state.recvTransport.on("connect", function (_ref3, callback, errback) {
      emitAck("MS-connect-transport", {
        roomId: state.roomId,
        userId: state.userId,
        transportId: state.recvTransport.id,
        dtlsParameters: _ref3.dtlsParameters,
      }).then(function (res) {
        if (res && res.ok) callback();
        else errback(new Error("recv-connect-failed"));
      }).catch(errback);
    });

    // Produce local tracks
    var audioTrack = state.localStream.getAudioTracks()[0];
    if (audioTrack) {
      state.audioProducer = await state.sendTransport.produce({ track: audioTrack });
    }

    if (state.callType === "video") {
      var videoTrack = state.localStream.getVideoTracks()[0];
      if (videoTrack) {
        state.videoProducer = await state.sendTransport.produce({
          track: videoTrack,
          encodings: [
            {
              maxBitrate: 450000,
              maxFramerate: 15,
              scalabilityMode: "L1T1",
            },
          ],
        });
      }
    }

    // Consume existing producers
    var producersRes = await emitAck("MS-get-producers", {
      roomId: state.roomId,
      userId: state.userId,
    });
    var producers = (producersRes && producersRes.ok && producersRes.producers) ? producersRes.producers : [];

    for (var i = 0; i < producers.length; i += 1) {
      var p = producers[i];
      await consumeProducer(p.producerId, p.userId, p.kind);
    }

    setStatus("in_call", "Connected with mediasoup SFU.");
  }

  async function consumeProducer(producerId, remoteUserId, kindHint) {
    if (!producerId || state.consumedProducerIds[producerId]) return;
    state.consumedProducerIds[producerId] = true;

    try {
      var consumeRes = await emitAck("MS-consume", {
        roomId: state.roomId,
        userId: state.userId,
        producerId: producerId,
        rtpCapabilities: state.device.rtpCapabilities,
      });

      if (!consumeRes || !consumeRes.ok) {
        throw new Error("consume-failed");
      }

      var consumer = await state.recvTransport.consume({
        id: consumeRes.id,
        producerId: consumeRes.producerId,
        kind: consumeRes.kind,
        rtpParameters: consumeRes.rtpParameters,
        paused: consumeRes.paused !== false,
      });

      state.consumers[consumer.id] = consumer;

      var userId = String(remoteUserId || "unknown");
      var stream = state.remoteStreams[userId];
      if (!stream) {
        stream = new MediaStream();
        state.remoteStreams[userId] = stream;
      }

      var kind = consumeRes.kind || kindHint || consumer.kind;
      removeTracksOfKind(stream, kind);
      stream.addTrack(consumer.track);

      var displayStream = new MediaStream(stream.getTracks());
      state.remoteStreams[userId] = displayStream;
      upsertRemoteTile(userId, displayStream, kind);

      state.socket.emit("MS-resume-consumer", {
        roomId: state.roomId,
        userId: state.userId,
        consumerId: consumer.id,
      });

      if (kind === "video") {
        state.socket.emit("MS-set-preferred-layers", {
          roomId: state.roomId,
          userId: state.userId,
          consumerId: consumer.id,
          spatialLayer: 0,
          temporalLayer: 0,
        });
      }
    } catch (err) {
      delete state.consumedProducerIds[producerId];
      console.error("consumeProducer error", err);
    }
  }

  async function startCall(payload) {
    state.roomId = payload.roomId;
    state.userId = payload.userId;
    state.fullName = payload.fullName || payload.userId;
    state.groupName = payload.groupName || "Group Call";
    state.callType = payload.callType || "video";
    state.joinEvent = payload.joinEvent || "BE-join-room";
    state.leaveEvent = payload.leaveEvent || "BE-leave-room";
    state.participantDirectory = {};
    state.remoteUserMeta = {};

    if (payload.participants && typeof payload.participants === "object") {
      Object.keys(payload.participants).forEach(function (uid) {
        var name = payload.participants[uid];
        if (uid && name) {
          state.participantDirectory[String(uid)] = String(name);
        }
      });
    }

    if (state.userId && state.fullName) {
      state.participantDirectory[state.userId] = state.fullName;
    }

    $("#roomTitle").text(state.groupName);

    if (!payload.socketUrl) {
      throw new Error("missing-socket-url");
    }

    await waitForMediasoupReady();

    await connectSocket(payload.socketUrl);

    // Wait for socket connect.
    await new Promise(function (resolve, reject) {
      var timeout = setTimeout(function () {
        reject(new Error("socket-connect-timeout"));
      }, 15000);
      state.socket.once("connect", function () {
        clearTimeout(timeout);
        resolve();
      });
      state.socket.once("connect_error", function (err) {
        clearTimeout(timeout);
        reject(err || new Error("socket-connect-error"));
      });
    });

    await initializeMedia();
    await joinRoomAndMediasoup();
  }

  async function stopCall() {
    try {
      if (state.socket) {
        state.socket.emit(state.leaveEvent || "BE-leave-room", {
          roomId: state.roomId,
          leaver: state.userId,
        });
        state.socket.emit("call_disconnect", {
          roomId: state.roomId,
          userId: state.socket.id,
        });
      }
    } catch (_) {}

    Object.keys(state.consumers).forEach(function (id) {
      try {
        state.consumers[id].close();
      } catch (_) {}
    });
    state.consumers = {};

    try {
      if (state.audioProducer) state.audioProducer.close();
    } catch (_) {}
    try {
      if (state.videoProducer) state.videoProducer.close();
    } catch (_) {}
    try {
      if (state.sendTransport) state.sendTransport.close();
    } catch (_) {}
    try {
      if (state.recvTransport) state.recvTransport.close();
    } catch (_) {}

    if (state.localStream) {
      state.localStream.getTracks().forEach(function (t) {
        try {
          t.stop();
        } catch (_) {}
      });
    }

    if (state.socket) {
      try {
        state.socket.off("FE-user-join");
        state.socket.off("MS-new-producer");
        state.socket.off("FE-user-leave");
        state.socket.off("FE-toggle-camera");
        state.socket.off("FE-call-ended");
        state.socket.disconnect();
      } catch (_) {}
    }

    state.localStream = null;
    state.socket = null;
    state.sendTransport = null;
    state.recvTransport = null;
    state.device = null;
    state.audioProducer = null;
    state.videoProducer = null;
    state.remoteStreams = {};
    state.remoteUserMeta = {};
    state.participantDirectory = {};
    state.consumedProducerIds = {};

    var tiles = document.querySelectorAll(".tile[id^='remote-']");
    tiles.forEach(function (el) {
      el.remove();
    });

    updateGridLayout();

    setStatus("left", "You left the call.");
    postToFlutter("ended", {});
  }

  async function toggleMic(enabled) {
    if (!state.localStream) return;
    var tracks = state.localStream.getAudioTracks();
    if (!tracks.length) return;
    tracks.forEach(function (t) {
      t.enabled = enabled;
    });

    if (state.audioProducer) {
      if (enabled && state.audioProducer.paused) {
        await state.audioProducer.resume();
      } else if (!enabled && !state.audioProducer.paused) {
        await state.audioProducer.pause();
      }
    }

    state.isMicEnabled = enabled;
    setLocalAudioBadge(enabled);

    if (state.socket && state.roomId) {
      state.socket.emit("BE-toggle-camera-audio", {
        roomId: state.roomId,
        switchTarget: "audio",
      });
    }

    postToFlutter("mic", { enabled: enabled });
  }

  async function toggleCamera(enabled) {
    if (!state.localStream) return;
    var tracks = state.localStream.getVideoTracks();
    if (!tracks.length) return;

    tracks.forEach(function (t) {
      t.enabled = enabled;
    });

    if (state.videoProducer) {
      if (enabled && state.videoProducer.paused) {
        await state.videoProducer.resume();
      } else if (!enabled && !state.videoProducer.paused) {
        await state.videoProducer.pause();
      }
    }

    state.isCameraEnabled = enabled;

    if (state.socket && state.roomId) {
      state.socket.emit("BE-toggle-camera-audio", {
        roomId: state.roomId,
        switchTarget: "video",
      });
    }

    postToFlutter("camera", { enabled: enabled });
  }

  async function switchCamera() {
    if (state.callType !== "video") return;

    var nextFacing = state.facingMode === "user" ? "environment" : "user";
    var newStream;
    try {
      newStream = await navigator.mediaDevices.getUserMedia({
        audio: false,
        video: {
          facingMode: nextFacing,
          width: { ideal: 960, max: 1280 },
          height: { ideal: 540, max: 720 },
          frameRate: { ideal: 15, max: 20 },
        },
      });
    } catch (_) {
      // Keep existing track if alternate camera is unavailable.
      return;
    }

    var newTrack = newStream.getVideoTracks()[0];
    if (!newTrack) return;

    var oldTrack = state.localStream && state.localStream.getVideoTracks().length
      ? state.localStream.getVideoTracks()[0]
      : null;

    if (state.localStream && oldTrack) {
      state.localStream.removeTrack(oldTrack);
      try {
        oldTrack.stop();
      } catch (_) {}
    }

    if (state.localStream) {
      state.localStream.addTrack(newTrack);
    }

    if (state.videoProducer) {
      await state.videoProducer.replaceTrack({ track: newTrack });
    }

    var localVideo = document.getElementById("localVideo");
    localVideo.srcObject = state.localStream;
    localVideo.play().catch(function () {});

    state.facingMode = nextFacing;
  }

  function toggleSpeaker(enabled) {
    state.isSpeakerEnabled = enabled;
    postToFlutter("speaker", { enabled: enabled });
  }

  function receiveFromFlutter(raw) {
    try {
      var parsed = JSON.parse(raw);
      var action = parsed.action;
      var payload = parsed.payload || {};

      if (action === "bootstrap") {
        setStatus("bootstrapping", "Connecting to call service...");
        startCall(payload).catch(function (err) {
          console.error("bootstrap failed", err);
          setStatus("error", "Failed to initialize call.");
          postToFlutter("error", {
            message: (err && err.name ? err.name + ": " : "") + (err && err.message ? err.message : String(err)),
          });
        });
      } else if (action === "rejectCall") {
        if (state.socket && payload.roomId) {
          state.socket.emit("BE-reject-call", {
            roomId: payload.roomId,
          });
        }
        stopCall();
      } else if (action === "leaveCall") {
        stopCall();
      } else if (action === "toggleMic") {
        toggleMic(!!payload.enabled);
      } else if (action === "toggleCamera") {
        toggleCamera(!!payload.enabled);
      } else if (action === "switchCamera") {
        switchCamera().catch(function (err) {
          postToFlutter("error", {
            message: "switch-camera-failed: " + (err && err.message ? err.message : String(err)),
          });
        });
      } else if (action === "toggleSpeaker") {
        toggleSpeaker(!!payload.enabled);
      } else if (action === "reconnect") {
        if (state.socket && !state.socket.connected) {
          state.socket.connect();
        }
      }
    } catch (err) {
      postToFlutter("error", { message: "bridge-parse-error" });
    }
  }

  window.CU_EMBEDDED = {
    receiveFromFlutter: receiveFromFlutter,
  };

  // Start loading mediasoup immediately to reduce bootstrap latency.
  loadMediasoupClient().catch(function (err) {
    postToFlutter("error", {
      message: (err && err.name ? err.name + ": " : "") + (err && err.message ? err.message : "mediasoup-load-failed"),
    });
  });

  updateGridLayout();

  // Ready signal for Flutter side.
  postToFlutter("ready", {});
})();
