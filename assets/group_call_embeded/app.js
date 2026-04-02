(function () {
  var state = {
    socket: null,
    socketUrl: "",
    roomId: "",
    userId: "",
    fullName: "",
    callType: "video",
    joinEvent: "BE-join-room",
    leaveEvent: "BE-leave-room",
    localStream: null,
    sendTransport: null,
    recvTransport: null,
    sendIceParameters: null,
    recvIceParameters: null,
    sendConnectionState: "new",
    recvConnectionState: "new",
    device: null,
    audioProducer: null,
    videoProducer: null,
    consumers: {},
    consumedProducerIds: {},
    remoteStreams: {},
    remoteUserMeta: {},
    participantDirectory: {},
    socketToUserMap: {},
    userToSocketMap: {},
    isMicEnabled: true,
    isCameraEnabled: true,
    isSpeakerEnabled: true,
    hasRealDevices: false,
    facingMode: "user",
    groupName: "Group Call",
    callerName: "",
    groupImage: "",
    viewMode: "normal",
    bootstrapPayload: null,
    isStopping: false,
    isRecovering: false,
    isRestartingIce: false,
    recvIceRestartTimer: null,
    sendIceRestartTimer: null,
    recoveryTimer: null,
    lastIceRestartAt: 0,
    iceRestartWindowStart: 0,
    iceRestartBurstCount: 0,
    startToken: 0,
    enableVerboseLogs: true,
    remoteRenderReady: {},
    localRenderReady: false,
    fallbackIceServers: [],
    fallbackIceTransportPolicy: "all",
  };

  var mediasoupLoaderPromise = null;

  function safeStringify(value) {
    try {
      return JSON.stringify(value);
    } catch (_) {
      try {
        return String(value);
      } catch (_) {
        return "[unserializable]";
      }
    }
  }

  function postToFlutter(type, payload) {
    try {
      var msg = JSON.stringify({ type: type, payload: payload || {} });
      if (window.FlutterBridge && window.FlutterBridge.postMessage) {
        window.FlutterBridge.postMessage(msg);
      }
    } catch (err) {
      console.error("postToFlutter failed", err);
    }
  }

  function trace(level, scope, message, details) {
    var normalizedLevel = level || "debug";
    var normalizedScope = scope || "general";
    var text = "[EmbeddedCall][" + normalizedScope + "] " + message;

    if (details !== undefined) {
      if (normalizedLevel === "error") {
        console.error(text, details);
      } else if (normalizedLevel === "warn") {
        console.warn(text, details);
      } else {
        console.log(text, details);
      }
    } else if (normalizedLevel === "error") {
      console.error(text);
    } else if (normalizedLevel === "warn") {
      console.warn(text);
    } else {
      console.log(text);
    }

    if (
      !state.enableVerboseLogs &&
      normalizedLevel !== "error" &&
      normalizedLevel !== "warn"
    ) {
      return;
    }

    postToFlutter("log", {
      level: normalizedLevel,
      scope: normalizedScope,
      message: message,
      details: details !== undefined ? safeStringify(details) : "",
      time: new Date().toISOString(),
    });
  }

  function setLocalPlaceholderText(text) {
    var localPlaceholderText = document.getElementById("localPlaceholderText");
    if (!localPlaceholderText) return;
    localPlaceholderText.textContent = text || "Starting camera...";
  }

  function markLocalRenderReady(isReady, reason) {
    state.localRenderReady = !!isReady;
    trace("debug", "local-video", "local render readiness changed", {
      ready: !!isReady,
      reason: reason || "unknown",
    });
    updateLocalVisualState(state.localStream);
  }

  function markRemoteRenderReady(userId, isReady, reason) {
    if (!userId) return;
    state.remoteRenderReady[userId] = !!isReady;
    trace("debug", "remote-video", "remote render readiness changed", {
      userId: userId,
      ready: !!isReady,
      reason: reason || "unknown",
    });
    updateRemoteVisualState(userId, state.remoteStreams[userId]);
  }

  function configureVideoElement(videoEl, options) {
    if (!videoEl) return;
    options = options || {};
    var isLocal = options.isLocal === true;
    var userId = options.userId ? String(options.userId) : "";

    videoEl.autoplay = true;
    videoEl.playsInline = true;
    videoEl.controls = false;
    videoEl.muted = isLocal ? true : !!options.muted;
    videoEl.disablePictureInPicture = true;
    videoEl.setAttribute("playsinline", "true");
    videoEl.setAttribute("webkit-playsinline", "true");
    videoEl.setAttribute(
      "controlsList",
      "nodownload noplaybackrate noremoteplayback",
    );
    videoEl.removeAttribute("controls");

    videoEl.onloadeddata = function () {
      if (isLocal) {
        markLocalRenderReady(true, "loadeddata");
      } else {
        markRemoteRenderReady(userId, true, "loadeddata");
      }
    };

    videoEl.onplaying = function () {
      if (isLocal) {
        markLocalRenderReady(true, "playing");
      } else {
        markRemoteRenderReady(userId, true, "playing");
      }
    };

    videoEl.onwaiting = function () {
      if (isLocal) {
        markLocalRenderReady(false, "waiting");
      } else {
        markRemoteRenderReady(userId, false, "waiting");
      }
    };

    videoEl.onstalled = function () {
      if (isLocal) {
        markLocalRenderReady(false, "stalled");
      } else {
        markRemoteRenderReady(userId, false, "stalled");
      }
    };

    videoEl.onerror = function (event) {
      trace(
        "warn",
        isLocal ? "local-video" : "remote-video",
        "video element error",
        {
          userId: userId,
          error: event ? safeStringify(event) : "unknown",
        },
      );

      if (isLocal) {
        markLocalRenderReady(false, "video-error");
      } else {
        markRemoteRenderReady(userId, false, "video-error");
      }
    };
  }

  function updateLocalVisualState(stream) {
    var localVideo = document.getElementById("localVideo");
    var localPlaceholder = document.getElementById("localPlaceholder");
    if (!localVideo || !localPlaceholder) {
      return;
    }

    var hasVideoTrack = false;
    if (stream && typeof stream.getVideoTracks === "function") {
      hasVideoTrack = stream.getVideoTracks().some(function (track) {
        return track && track.readyState !== "ended";
      });
    }

    var showVideo = hasVideoTrack && state.localRenderReady === true;
    localVideo.classList.toggle("is-ready", showVideo);

    if (showVideo) {
      localPlaceholder.classList.add("hidden");
      return;
    }

    localPlaceholder.classList.remove("hidden");

    if (!hasVideoTrack) {
      setLocalPlaceholderText(
        state.callType === "audio" ? "Audio call" : "Camera unavailable",
      );
    }
  }

  function setStatus(text, sub) {
    $("#statusPill").text(text);
    if (sub) {
      $("#subTitle").text(sub);
    }
    trace("debug", "state", "status updated", {
      state: text,
      subtitle: sub || "",
    });
    postToFlutter("state", { state: text });
  }

  function normalizeTransportState(rawState) {
    if (!rawState) return "unknown";
    if (typeof rawState === "string") return rawState;
    if (typeof rawState === "object") {
      if (typeof rawState.connectionState === "string") {
        return rawState.connectionState;
      }
      if (typeof rawState.state === "string") {
        return rawState.state;
      }
    }
    return "unknown";
  }

  function clearTimer(key) {
    var timer = state[key];
    if (timer) {
      clearTimeout(timer);
      state[key] = null;
    }
  }

  function clearRecoveryTimers() {
    clearTimer("recvIceRestartTimer");
    clearTimer("sendIceRestartTimer");
    clearTimer("recoveryTimer");
  }

  function getInitials(name) {
    var text = String(name || "User").trim();
    if (!text) return "U";

    var words = text.split(/\s+/).filter(Boolean);
    if (words.length === 1) {
      return words[0].slice(0, 2).toUpperCase();
    }

    return (words[0][0] + words[1][0]).toUpperCase();
  }

  function setViewMode(mode) {
    var normalized = mode === "pip" ? "pip" : "normal";
    state.viewMode = normalized;

    var isCompact = normalized === "pip";
    document.body.classList.toggle("compact-mode", isCompact);
    trace("debug", "ui", "view mode changed", { mode: normalized });
    updateGridLayout();
  }

  function setPipOverflowBadge(extraCount) {
    var localTile = document.querySelector(".tile.local");
    if (!localTile) {
      return;
    }

    var badge = document.getElementById("pipOverflowBadge");
    if (extraCount > 0 && state.viewMode === "pip") {
      if (!badge) {
        badge = document.createElement("div");
        badge.id = "pipOverflowBadge";
        badge.className = "pip-overflow-badge";
        localTile.appendChild(badge);
      }
      badge.textContent = "+" + extraCount;
      return;
    }

    if (badge) {
      badge.remove();
    }
  }

  function updateRemotePlaceholderText(userId) {
    var placeholder = document.getElementById("placeholder-" + userId);
    if (!placeholder) return;

    var meta = state.remoteUserMeta[userId] || {};
    var textEl = placeholder.querySelector(".remote-connecting-text");
    if (!textEl) return;

    if (meta.video === false) {
      textEl.textContent = "Camera is off";
      return;
    }

    if (meta.audio === false) {
      textEl.textContent = "Muted";
      return;
    }

    textEl.textContent = "Connecting...";
  }

  function updateRemoteVisualState(userId, stream) {
    var placeholder = document.getElementById("placeholder-" + userId);
    var videoEl = document.getElementById("video-" + userId);

    var hasVideo = false;
    if (stream && typeof stream.getVideoTracks === "function") {
      hasVideo = stream.getVideoTracks().some(function (track) {
        return track && track.readyState !== "ended";
      });
    }

    var showVideo = hasVideo && state.remoteRenderReady[userId] === true;

    if (placeholder) {
      if (showVideo) {
        placeholder.classList.add("hidden");
      } else {
        placeholder.classList.remove("hidden");
      }
    }

    if (videoEl) {
      videoEl.classList.toggle("is-ready", showVideo);
    }

    if (!showVideo) {
      updateRemotePlaceholderText(userId);
    }
  }

  function normalizeIceServers(rawServers) {
    if (!Array.isArray(rawServers)) {
      return [];
    }

    var normalized = [];
    rawServers.forEach(function (server) {
      if (!server || typeof server !== "object") {
        return;
      }

      var urlsValue = server.urls;
      var urls = [];
      if (Array.isArray(urlsValue)) {
        urls = urlsValue
          .map(function (url) {
            return String(url || "").trim();
          })
          .filter(function (url) {
            return url.length > 0;
          });
      } else if (urlsValue != null) {
        var one = String(urlsValue).trim();
        if (one) {
          urls = [one];
        }
      }

      if (!urls.length) {
        return;
      }

      var entry = {
        urls: urls.length === 1 ? urls[0] : urls,
      };

      if (
        server.username != null &&
        String(server.username).trim().length > 0
      ) {
        entry.username = String(server.username).trim();
      }

      if (
        server.credential != null &&
        String(server.credential).trim().length > 0
      ) {
        entry.credential = String(server.credential).trim();
      }

      normalized.push(entry);
    });

    return normalized;
  }

  function resolveRemoteUserId(socketUserId, userName) {
    var normalizedUserName = userName ? String(userName) : "";
    if (normalizedUserName) {
      return normalizedUserName;
    }

    var normalizedSocketId = socketUserId ? String(socketUserId) : "";
    if (!normalizedSocketId) {
      return "";
    }

    if (state.socketToUserMap[normalizedSocketId]) {
      return state.socketToUserMap[normalizedSocketId];
    }

    if (state.remoteUserMeta[normalizedSocketId]) {
      return normalizedSocketId;
    }

    var mapped = "";
    Object.keys(state.remoteUserMeta).some(function (uid) {
      var meta = state.remoteUserMeta[uid] || {};
      if (meta.socketId && String(meta.socketId) === normalizedSocketId) {
        mapped = uid;
        return true;
      }
      return false;
    });

    return mapped;
  }

  function resolveRemoteUserIdFromPayload(payload) {
    if (Array.isArray(payload) && payload.length > 0) {
      payload = payload[0];
    }

    if (!payload || typeof payload !== "object") {
      return "";
    }

    var userName = payload.userName ? String(payload.userName) : "";
    var socketUserId = payload.userId ? String(payload.userId) : "";

    return resolveRemoteUserId(socketUserId, userName);
  }

  function removeRemoteUser(userId, reason) {
    if (!userId || userId === state.userId) {
      return;
    }

    var normalizedUserId = String(userId);
    var meta = state.remoteUserMeta[normalizedUserId] || {};
    var socketId =
      state.userToSocketMap[normalizedUserId] ||
      (meta.socketId ? String(meta.socketId) : "");

    if (socketId) {
      delete state.socketToUserMap[socketId];
    }
    delete state.userToSocketMap[normalizedUserId];

    delete state.remoteStreams[normalizedUserId];
    delete state.remoteUserMeta[normalizedUserId];
    delete state.remoteRenderReady[normalizedUserId];

    var tile = document.getElementById("remote-" + normalizedUserId);
    if (tile) {
      tile.remove();
    }

    trace("debug", "socket", "remote user removed", {
      userId: normalizedUserId,
      reason: reason || "unknown",
      socketId: socketId,
    });

    updateGridLayout();
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
    var displayName = state.fullName || "You";
    if (enabled) {
      badge.classList.remove("muted");
      badge.textContent = displayName;
    } else {
      badge.classList.add("muted");
      badge.textContent = displayName + " (muted)";
    }
  }

  function setRemoteAudioBadge(userId, enabled) {
    var badge = document.getElementById("badge-" + userId);
    var muteIcon = document.getElementById("mute-" + userId);

    if (!badge) return;

    var displayName = getDisplayName(userId);
    if (enabled === false) {
      badge.classList.add("muted");
      badge.textContent = displayName + " (muted)";
      if (muteIcon) {
        muteIcon.classList.add("show");
      }
    } else {
      badge.classList.remove("muted");
      badge.textContent = displayName;
      if (muteIcon) {
        muteIcon.classList.remove("show");
      }
    }
  }

  function updateRemoteTileMeta(userId) {
    var badge = document.getElementById("badge-" + userId);
    if (badge) {
      var meta = state.remoteUserMeta[userId] || {};
      var displayName = getDisplayName(userId);
      if (typeof meta.audio === "boolean") {
        setRemoteAudioBadge(userId, meta.audio);
      } else {
        badge.textContent = displayName;
      }
    }

    updateRemotePlaceholderText(userId);
  }

  function updateGridLayout() {
    var grid = document.getElementById("grid");
    if (!grid) return;

    var remoteTiles = Array.from(grid.querySelectorAll(".tile[id^='remote-']"));

    remoteTiles.forEach(function (tile) {
      tile.classList.remove("primary-remote");
      tile.classList.remove("pip-hidden");
    });

    grid.classList.remove(
      "layout-single",
      "layout-dual",
      "layout-multi",
      "layout-pip",
    );

    var visibleRemoteTiles = remoteTiles;
    if (state.viewMode === "pip" && remoteTiles.length > 3) {
      visibleRemoteTiles = remoteTiles.slice(0, 3);
      remoteTiles.slice(3).forEach(function (tile) {
        tile.classList.add("pip-hidden");
      });
    }

    if (state.viewMode === "pip") {
      var visibleCount = visibleRemoteTiles.length + 1;
      grid.classList.add("layout-pip");
      // 2 users: stacked vertically (1 column), 3+ users: grid (2 columns)
      var pipCols = visibleCount <= 2 ? 1 : 2;
      grid.style.setProperty("--pip-cols", String(pipCols));
      grid.style.removeProperty("--remote-cols");
      setPipOverflowBadge(
        Math.max(0, remoteTiles.length - visibleRemoteTiles.length),
      );
      return;
    }

    setPipOverflowBadge(0);

    var remoteCount = visibleRemoteTiles.length;
    if (remoteCount === 0) {
      grid.classList.add("layout-single");
      grid.style.removeProperty("--remote-cols");
      return;
    }

    if (remoteCount === 1) {
      grid.classList.add("layout-dual");
      visibleRemoteTiles[0].classList.add("primary-remote");
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
    return (
      globalClient.Device ||
      (globalClient.default && globalClient.default.Device) ||
      null
    );
  }

  function loadMediasoupClient() {
    if (ensureMediasoupDeviceCtor()) {
      trace("debug", "mediasoup", "mediasoup client already loaded");
      return Promise.resolve();
    }

    if (mediasoupLoaderPromise) {
      return mediasoupLoaderPromise;
    }

    var urls = [
      "https://esm.sh/mediasoup-client@3.18.7?bundle",
      "https://esm.sh/mediasoup-client@3.18.7",
      "https://cdn.skypack.dev/mediasoup-client@3.18.7",
    ];

    mediasoupLoaderPromise = (async function () {
      for (var i = 0; i < urls.length; i += 1) {
        var url = urls[i];
        trace("debug", "mediasoup", "loading mediasoup client", { url: url });
        try {
          var mod = await import(url);
          if (mod) {
            window.mediasoupClient = mod;
            if (ensureMediasoupDeviceCtor()) {
              trace("debug", "mediasoup", "mediasoup client loaded", {
                url: url,
              });
              window.dispatchEvent(new Event("mediasoup-ready"));
              return;
            }
          }
        } catch (err) {
          trace("warn", "mediasoup", "mediasoup import failed", {
            url: url,
            error: err && err.message ? err.message : String(err),
          });
        }
      }

      throw new Error("mediasoup-load-failed");
    })();

    return mediasoupLoaderPromise;
  }

  function waitForMediasoupReady(timeoutMs) {
    timeoutMs = timeoutMs || 12000;
    trace("debug", "mediasoup", "waiting for mediasoup", {
      timeoutMs: timeoutMs,
    });
    return new Promise(function (resolve, reject) {
      if (ensureMediasoupDeviceCtor()) {
        trace("debug", "mediasoup", "mediasoup already ready");
        resolve();
        return;
      }

      var done = false;
      var t = setTimeout(function () {
        if (!done) {
          done = true;
          trace("error", "mediasoup", "mediasoup load timeout", {
            timeoutMs: timeoutMs,
          });
          reject(new Error("mediasoup-load-timeout"));
        }
      }, timeoutMs);

      function onReady() {
        if (done) return;
        done = true;
        clearTimeout(t);
        window.removeEventListener("mediasoup-ready", onReady);
        trace("debug", "mediasoup", "mediasoup ready event received");
        resolve();
      }

      window.addEventListener("mediasoup-ready", onReady);

      loadMediasoupClient().catch(function (err) {
        if (!done) {
          done = true;
          clearTimeout(t);
          window.removeEventListener("mediasoup-ready", onReady);
          trace("error", "mediasoup", "mediasoup loading failed", {
            error: err && err.message ? err.message : String(err),
          });
          reject(err);
        }
      });
    });
  }

  function createDummyStream(wantsVideo) {
    var stream = new MediaStream();
    trace("warn", "media", "using dummy stream", { wantsVideo: !!wantsVideo });

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
    trace("debug", "socket-ack", "emitAck start", {
      eventName: eventName,
      timeoutMs: timeoutMs,
      noPayload: options.noPayload === true,
      payload: payload,
    });

    return new Promise(function (resolve, reject) {
      if (!state.socket) {
        trace("error", "socket-ack", "emitAck socket not ready", {
          eventName: eventName,
        });
        reject(new Error("socket-not-ready"));
        return;
      }

      var done = false;
      var t = setTimeout(function () {
        if (!done) {
          done = true;
          trace("error", "socket-ack", "emitAck timeout", {
            eventName: eventName,
          });
          reject(new Error(eventName + " timeout"));
        }
      }, timeoutMs);

      try {
        var ack = function (res) {
          if (done) return;
          done = true;
          clearTimeout(t);
          trace("debug", "socket-ack", "emitAck response", {
            eventName: eventName,
            response: res,
          });
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
          trace("error", "socket-ack", "emitAck exception", {
            eventName: eventName,
            error: err && err.message ? err.message : String(err),
          });
          reject(err);
        }
      }
    });
  }

  function removeTracksOfKind(stream, kind) {
    var tracks =
      kind === "video" ? stream.getVideoTracks() : stream.getAudioTracks();
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
      configureVideoElement(video, {
        userId: userId,
        isLocal: false,
        muted: false,
      });
      tile.appendChild(video);

      var placeholder = document.createElement("div");
      placeholder.id = "placeholder-" + userId;
      placeholder.className = "remote-connecting";
      placeholder.innerHTML =
        '<div class="remote-avatar">' +
        escapeHtml(getInitials(getDisplayName(userId))) +
        "</div>" +
        '<div class="remote-connecting-text">Connecting...</div>';
      tile.appendChild(placeholder);

      var mute = document.createElement("div");
      mute.id = "mute-" + userId;
      mute.className = "mute-icon";
      mute.innerHTML = '<span class="mute-icon-symbol">🔇</span>';
      tile.appendChild(mute);

      var meta = document.createElement("div");
      meta.className = "meta";
      meta.innerHTML =
        '<span id="badge-' +
        userId +
        '" class="badge">' +
        escapeHtml(getDisplayName(userId)) +
        "</span>";
      tile.appendChild(meta);

      document.getElementById("grid").appendChild(tile);
      existing = tile;
    }

    var videoEl = document.getElementById("video-" + userId);
    if (videoEl && stream) {
      configureVideoElement(videoEl, {
        userId: userId,
        isLocal: false,
        muted: false,
      });
      if (kind === "video" || videoEl.srcObject !== stream) {
        state.remoteRenderReady[userId] = false;
      }
      videoEl.srcObject = stream;
      videoEl.play().catch(function (err) {
        trace("warn", "remote-video", "video play() rejected", {
          userId: userId,
          error: err && err.message ? err.message : String(err),
        });
      });
    }

    updateRemoteVisualState(userId, stream);

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

      updateRemotePlaceholderText(userId);
    }

    updateRemoteTileMeta(userId);
    updateGridLayout();
  }

  async function initializeMedia() {
    var wantsVideo = state.callType === "video";
    state.hasRealDevices = false;
    trace("debug", "media", "initializeMedia start", {
      wantsVideo: wantsVideo,
      facingMode: state.facingMode,
    });
    setStatus("media_init", "Requesting microphone/camera...");

    var constraints = {
      audio: true,
      video: wantsVideo
        ? {
            facingMode: state.facingMode,
            width: { ideal: 640, max: 960 },
            height: { ideal: 360, max: 540 },
            frameRate: { ideal: 15, max: 20 },
          }
        : false,
    };

    try {
      state.localStream =
        await navigator.mediaDevices.getUserMedia(constraints);
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
          state.localStream = await navigator.mediaDevices.getUserMedia({
            audio: true,
            video: false,
          });
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
    configureVideoElement(localVideo, {
      isLocal: true,
      userId: state.userId,
      muted: true,
    });
    state.localRenderReady = false;
    setLocalPlaceholderText(wantsVideo ? "Starting camera..." : "Audio call");
    localVideo.srcObject = state.localStream;
    localVideo.play().catch(function (err) {
      trace("warn", "local-video", "local play() rejected", {
        error: err && err.message ? err.message : String(err),
      });
    });

    state.isCameraEnabled = state.localStream.getVideoTracks().length > 0;
    state.isMicEnabled = state.localStream.getAudioTracks().length > 0;
    setLocalAudioBadge(state.isMicEnabled);

    if (!state.hasRealDevices) {
      setStatus(
        "media_fallback",
        "Using fallback media stream (camera/mic unavailable).",
      );
    }

    updateLocalVisualState(state.localStream);
    trace("debug", "media", "initializeMedia complete", {
      hasRealDevices: state.hasRealDevices,
      audioTracks: state.localStream.getAudioTracks().length,
      videoTracks: state.localStream.getVideoTracks().length,
    });

    postToFlutter("mic", { enabled: state.isMicEnabled });
    postToFlutter("camera", { enabled: state.isCameraEnabled });
  }

  function forceReattachRemoteVideos() {
    Object.keys(state.remoteStreams).forEach(function (userId) {
      var stream = state.remoteStreams[userId];
      var videoEl = document.getElementById("video-" + userId);
      if (!videoEl || !stream) {
        return;
      }

      state.remoteRenderReady[userId] = false;
      updateRemoteVisualState(userId, stream);

      try {
        videoEl.srcObject = null;
      } catch (_) {}

      setTimeout(function () {
        try {
          configureVideoElement(videoEl, {
            userId: userId,
            isLocal: false,
            muted: false,
          });
          videoEl.srcObject = stream;
          videoEl.play().catch(function (err) {
            trace("warn", "remote-video", "re-attach play() rejected", {
              userId: userId,
              error: err && err.message ? err.message : String(err),
            });
          });
        } catch (_) {}
        updateRemoteVisualState(userId, stream);
      }, 80);
    });
  }

  function scheduleFullRecover(reason, delayMs) {
    if (state.isStopping) {
      return;
    }

    if (!state.bootstrapPayload || !state.bootstrapPayload.socketUrl) {
      return;
    }

    clearTimer("recoveryTimer");
    trace("warn", "recover", "scheduling full recover", {
      reason: reason,
      delayMs: delayMs || 1200,
    });
    state.recoveryTimer = setTimeout(
      function () {
        recoverCall(reason).catch(function (err) {
          console.error("recoverCall failed", err);
        });
      },
      Math.max(0, delayMs || 1200),
    );
  }

  function scheduleIceRestart(target, delayMs) {
    if (state.isStopping || state.isRecovering || state.isRestartingIce) {
      return;
    }

    var key = target === "send" ? "sendIceRestartTimer" : "recvIceRestartTimer";
    clearTimer(key);
    trace("warn", "ice", "scheduling ICE restart", {
      target: target,
      delayMs: delayMs || 1000,
    });
    state[key] = setTimeout(
      function () {
        attemptIceRestart(target).catch(function (err) {
          console.error("attemptIceRestart failed", err);
        });
      },
      Math.max(0, delayMs || 1000),
    );
  }

  async function restartTransportIceWithServer(direction, transport) {
    if (!transport || !transport.id) {
      return false;
    }

    if (!state.socket || state.socket.connected !== true) {
      return false;
    }

    try {
      trace("warn", "ice", "requesting transport ICE restart", {
        direction: direction,
        transportId: transport.id,
      });
      var response = await emitAck(
        "MS-restart-ice",
        {
          roomId: state.roomId,
          userId: state.userId,
          transportId: transport.id,
        },
        8000,
      );

      var iceParameters =
        response && response.ok === true && response.iceParameters
          ? response.iceParameters
          : null;

      if (!iceParameters) {
        iceParameters =
          direction === "recv"
            ? state.recvIceParameters
            : state.sendIceParameters;
      }

      if (!iceParameters) {
        return false;
      }

      if (direction === "recv") {
        state.recvIceParameters = iceParameters;
      } else {
        state.sendIceParameters = iceParameters;
      }

      await transport.restartIce({ iceParameters: iceParameters });
      trace("debug", "ice", "transport ICE restart applied", {
        direction: direction,
        transportId: transport.id,
      });
      return true;
    } catch (err) {
      trace("error", "ice", "transport ICE restart error", {
        direction: direction,
        transportId: transport.id,
        error: err && err.message ? err.message : String(err),
      });
      console.error(direction + " ICE restart error", err);
      return false;
    }
  }

  async function recoverRemoteConsumers() {
    trace("warn", "recover", "rebuilding remote consumers");
    if (
      !state.recvTransport ||
      !state.socket ||
      state.socket.connected !== true
    ) {
      return;
    }

    Object.keys(state.consumers).forEach(function (consumerId) {
      try {
        state.consumers[consumerId].close();
      } catch (_) {}
    });

    state.consumers = {};
    state.consumedProducerIds = {};

    Object.keys(state.remoteStreams).forEach(function (userId) {
      var stream = state.remoteStreams[userId];
      if (!stream) return;

      stream.getAudioTracks().forEach(function (track) {
        try {
          stream.removeTrack(track);
        } catch (_) {}
      });

      stream.getVideoTracks().forEach(function (track) {
        try {
          stream.removeTrack(track);
        } catch (_) {}
      });

      updateRemoteVisualState(userId, stream);
    });

    var producersRes = await emitAck("MS-get-producers", {
      roomId: state.roomId,
      userId: state.userId,
    });

    var producers =
      producersRes && producersRes.ok && producersRes.producers
        ? producersRes.producers
        : [];

    trace("debug", "recover", "remote producers snapshot", {
      producerCount: producers.length,
    });

    for (var i = 0; i < producers.length; i += 1) {
      var producer = producers[i];
      if (!producer) continue;
      if (String(producer.userId || "") === state.userId) {
        continue;
      }

      await consumeProducer(
        producer.producerId,
        producer.userId,
        producer.kind,
      );
    }

    forceReattachRemoteVideos();
  }

  async function attemptIceRestart(target) {
    trace("warn", "ice", "attempting ICE restart", {
      target: target,
      recvState: state.recvConnectionState,
      sendState: state.sendConnectionState,
    });
    if (state.isStopping || state.isRecovering || state.isRestartingIce) {
      return;
    }

    if (
      !state.roomId ||
      !state.userId ||
      !state.socket ||
      state.socket.connected !== true
    ) {
      scheduleFullRecover("ice-restart-no-socket", 900);
      return;
    }

    clearTimer("recvIceRestartTimer");
    clearTimer("sendIceRestartTimer");

    var now = Date.now();
    if (state.lastIceRestartAt && now - state.lastIceRestartAt < 4000) {
      trace("debug", "ice", "ICE restart skipped due cooldown", {
        elapsedMs: now - state.lastIceRestartAt,
      });
      return;
    }
    state.lastIceRestartAt = now;

    if (
      !state.iceRestartWindowStart ||
      now - state.iceRestartWindowStart > 20000
    ) {
      state.iceRestartWindowStart = now;
      state.iceRestartBurstCount = 0;
    }
    state.iceRestartBurstCount += 1;

    if (state.iceRestartBurstCount >= 5) {
      trace("error", "ice", "ICE restart burst threshold reached", {
        burstCount: state.iceRestartBurstCount,
      });
      state.iceRestartBurstCount = 0;
      state.iceRestartWindowStart = 0;
      scheduleFullRecover("ice-flapping", 300);
      return;
    }

    var shouldRestartRecv = target === "recv" || target === "both";
    var shouldRestartSend = target === "send" || target === "both";

    if (shouldRestartRecv && !state.recvTransport) {
      shouldRestartRecv = false;
    }
    if (shouldRestartSend && !state.sendTransport) {
      shouldRestartSend = false;
    }

    if (!shouldRestartRecv && !shouldRestartSend) {
      scheduleFullRecover("ice-missing-transports", 200);
      return;
    }

    state.isRestartingIce = true;
    setStatus("ice_recovering", "Reconnecting media...");

    try {
      var recvRestarted = false;
      var sendRestarted = false;

      if (shouldRestartRecv && state.recvTransport) {
        recvRestarted = await restartTransportIceWithServer(
          "recv",
          state.recvTransport,
        );
      }

      if (shouldRestartSend && state.sendTransport) {
        sendRestarted = await restartTransportIceWithServer(
          "send",
          state.sendTransport,
        );
      }

      if (!recvRestarted && !sendRestarted) {
        trace("error", "ice", "ICE restart failed for both transports");
        scheduleFullRecover("ice-restart-failed", 500);
        return;
      }

      await new Promise(function (resolve) {
        setTimeout(resolve, 250);
      });

      if (recvRestarted) {
        await recoverRemoteConsumers();
      }

      forceReattachRemoteVideos();
      setStatus("in_call", "Connected with mediasoup SFU.");
      trace("debug", "ice", "ICE restart flow completed", {
        recvRestarted: recvRestarted,
        sendRestarted: sendRestarted,
      });
    } finally {
      state.isRestartingIce = false;
    }
  }

  function onSendTransportStateChanged(rawState) {
    var nextState = normalizeTransportState(rawState);
    trace("debug", "transport-send", "connection state changed", {
      previous: state.sendConnectionState,
      next: nextState,
    });
    state.sendConnectionState = nextState;

    if (nextState === "connected") {
      clearTimer("sendIceRestartTimer");
      state.iceRestartBurstCount = 0;
      state.iceRestartWindowStart = 0;
      return;
    }

    if (nextState === "failed") {
      scheduleIceRestart("both", 1000);
      return;
    }

    if (nextState === "disconnected") {
      scheduleIceRestart("both", 8000);
    }
  }

  function onRecvTransportStateChanged(rawState) {
    var previousState = state.recvConnectionState;
    var nextState = normalizeTransportState(rawState);
    trace("debug", "transport-recv", "connection state changed", {
      previous: previousState,
      next: nextState,
    });
    state.recvConnectionState = nextState;

    if (nextState === "connected") {
      clearTimer("recvIceRestartTimer");
      state.iceRestartBurstCount = 0;
      state.iceRestartWindowStart = 0;

      if (previousState === "disconnected" || previousState === "failed") {
        recoverRemoteConsumers().catch(function (err) {
          console.error("recoverRemoteConsumers failed", err);
        });
      } else {
        forceReattachRemoteVideos();
      }
      return;
    }

    if (nextState === "failed") {
      scheduleIceRestart("both", 1000);
      return;
    }

    if (nextState === "disconnected") {
      scheduleIceRestart("both", 8000);
    }
  }

  async function recoverCall(reason) {
    trace("warn", "recover", "recover call start", {
      reason: reason || "unknown",
    });
    if (state.isRecovering || state.isStopping) {
      return;
    }

    if (!state.bootstrapPayload || !state.bootstrapPayload.socketUrl) {
      return;
    }

    state.isRecovering = true;

    try {
      setStatus("reconnecting", "Connection unstable, recovering call...");
      await startCall(Object.assign({}, state.bootstrapPayload), {
        skipCleanup: false,
        isRecovery: true,
        reason: reason || "unknown",
      });
    } catch (err) {
      trace("error", "recover", "recover call exception", {
        reason: reason || "unknown",
        error: err && err.message ? err.message : String(err),
      });
      console.error("recoverCall exception", err);
      setStatus("reconnect_retry", "Retrying call connection...");
      scheduleFullRecover("retry-" + String(reason || "unknown"), 2200);
    } finally {
      state.isRecovering = false;
      trace("debug", "recover", "recover call end", {
        reason: reason || "unknown",
      });
    }
  }

  async function connectSocket(socketUrl) {
    trace("debug", "socket", "connecting socket", { socketUrl: socketUrl });
    if (state.socket) {
      try {
        state.socket.disconnect();
      } catch (_) {}
      state.socket = null;
    }

    state.socket = io(socketUrl, {
      transports: ["websocket"],
      reconnection: true,
      reconnectionAttempts: 40,
      reconnectionDelay: 900,
      reconnectionDelayMax: 5000,
      randomizationFactor: 0.35,
      timeout: 20000,
      forceNew: true,
    });

    trace("debug", "socket", "socket object created", {
      opts: {
        reconnectionAttempts: 40,
        reconnectionDelay: 900,
        reconnectionDelayMax: 5000,
        timeout: 20000,
      },
    });

    state.socket.on("connect", function () {
      clearRecoveryTimers();
      setStatus("socket_connected", "Socket connected. Joining call room...");
      trace("debug", "socket", "socket connected", {
        socketId: state.socket.id,
      });
      postToFlutter("connected", { socketId: state.socket.id });
      state.socket.emit("joinSelf", state.userId);
    });

    state.socket.on("reconnect", function () {
      clearRecoveryTimers();
      setStatus("socket_reconnected", "Reconnected. Restoring media...");
      scheduleFullRecover("socket-reconnect", 350);
    });

    state.socket.on("disconnect", function (reason) {
      trace("warn", "socket", "socket disconnected", { reason: reason });
      if (state.isStopping) {
        return;
      }

      setStatus("socket_disconnected", "Connection lost. Reconnecting...");
      if (reason !== "io client disconnect") {
        scheduleFullRecover("socket-disconnect", 1200);
      }
    });

    state.socket.on("connect_error", function () {
      trace("warn", "socket", "socket connect_error");
      if (state.isStopping) {
        return;
      }

      setStatus("socket_error", "Network issue. Reconnecting...");
      scheduleFullRecover("socket-connect-error", 1700);
    });

    state.socket.on("FE-user-join", function (users) {
      trace("debug", "socket", "FE-user-join received", {
        isArray: Array.isArray(users),
        length: Array.isArray(users) ? users.length : -1,
      });
      if (
        Array.isArray(users) &&
        users.length === 1 &&
        Array.isArray(users[0])
      ) {
        users = users[0];
      }

      if (!Array.isArray(users)) return;

      users.forEach(function (entry) {
        if (!entry || typeof entry !== "object") return;

        var socketId = entry.userId ? String(entry.userId) : "";
        var info =
          entry.info && typeof entry.info === "object" ? entry.info : {};
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

        var previousSocketId = state.userToSocketMap[userName] || "";
        if (previousSocketId && socketId && previousSocketId !== socketId) {
          delete state.socketToUserMap[previousSocketId];
        }

        if (socketId) {
          state.socketToUserMap[socketId] = userName;
          state.userToSocketMap[userName] = socketId;
        }

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
      trace("debug", "mediasoup", "MS-new-producer received", payload);
      try {
        if (!payload || !payload.producerId) return;
        if (state.consumedProducerIds[payload.producerId]) return;
        await consumeProducer(payload.producerId, payload.userId, payload.kind);
      } catch (err) {
        console.error("MS-new-producer consume error", err);
      }
    });

    state.socket.on("FE-user-leave", function (payload) {
      trace("debug", "socket", "FE-user-leave received", payload);
      var resolvedUserId = resolveRemoteUserIdFromPayload(payload);
      if (!resolvedUserId) {
        trace("warn", "socket", "FE-user-leave unresolved user", payload);
        return;
      }

      removeRemoteUser(resolvedUserId, "FE-user-leave");
    });

    state.socket.on("FE-user-disconnected", function (payload) {
      trace("debug", "socket", "FE-user-disconnected received", payload);
      var resolvedUserId = resolveRemoteUserIdFromPayload(payload);
      if (!resolvedUserId) {
        trace(
          "warn",
          "socket",
          "FE-user-disconnected unresolved user",
          payload,
        );
        return;
      }

      removeRemoteUser(resolvedUserId, "FE-user-disconnected");
    });

    state.socket.on("FE-toggle-camera", function (payload) {
      trace("debug", "socket", "FE-toggle-camera received", payload);
      if (Array.isArray(payload) && payload.length > 0) {
        payload = payload[0];
      }

      if (!payload || typeof payload !== "object") return;

      var switchTarget = payload.switchTarget;
      if (switchTarget !== "audio" && switchTarget !== "video") return;

      var socketUserId = payload.userId ? String(payload.userId) : "";
      var mappedUserId = "";

      Object.keys(state.remoteUserMeta).some(function (uid) {
        if (
          state.remoteUserMeta[uid] &&
          state.remoteUserMeta[uid].socketId === socketUserId
        ) {
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

      if (
        !mappedUserId &&
        socketUserId &&
        document.getElementById("remote-" + socketUserId)
      ) {
        mappedUserId = socketUserId;
      }

      if (!mappedUserId || mappedUserId === state.userId) {
        return;
      }

      var meta = state.remoteUserMeta[mappedUserId] || {};
      var enabled;
      if (typeof payload.isEnabled === "boolean") {
        enabled = payload.isEnabled;
      } else if (
        switchTarget === "audio" &&
        typeof payload.audio === "boolean"
      ) {
        enabled = payload.audio;
      } else if (
        switchTarget === "video" &&
        typeof payload.video === "boolean"
      ) {
        enabled = payload.video;
      } else if (typeof payload.enabled === "boolean") {
        enabled = payload.enabled;
      } else {
        enabled =
          switchTarget === "audio"
            ? meta.audio === false
            : meta.video === false;
      }

      if (switchTarget === "audio") {
        meta.audio = enabled;
      } else {
        meta.video = enabled;
      }
      state.remoteUserMeta[mappedUserId] = meta;

      if (switchTarget === "audio") {
        setRemoteAudioBadge(mappedUserId, enabled);
        postToFlutter("remote_audio", {
          userId: mappedUserId,
          enabled: enabled,
        });
      }

      updateRemotePlaceholderText(mappedUserId);
      updateRemoteVisualState(mappedUserId, state.remoteStreams[mappedUserId]);
    });

    state.socket.on("FE-call-ended", function () {
      postToFlutter("ended", {});
    });
  }

  async function joinRoomAndMediasoup() {
    trace("debug", "mediasoup", "joinRoomAndMediasoup start", {
      roomId: state.roomId,
      userId: state.userId,
      callType: state.callType,
    });
    setStatus("joining", "Joining room and preparing SFU transports...");

    await emitAck(state.joinEvent, {
      roomId: state.roomId,
      userName: state.userId,
      fullName: state.fullName,
      callerName: state.callerName || state.fullName,
      groupName: state.groupName,
      groupImage: state.groupImage || "",
      callType: state.callType,
      video: state.localStream.getVideoTracks().length > 0,
      audio: state.localStream.getAudioTracks().length > 0,
      hasRealDevices: state.hasRealDevices,
      constraints: {
        audio: state.isMicEnabled,
        video: state.callType === "video" && state.isCameraEnabled,
      },
    });

    var rtpCapsRes = await emitAck("MS-get-rtp-capabilities", {
      roomId: state.roomId,
    });
    if (!rtpCapsRes || !rtpCapsRes.ok || !rtpCapsRes.rtpCapabilities) {
      throw new Error("rtp-capabilities-failed");
    }

    var DeviceCtor = ensureMediasoupDeviceCtor();
    if (!DeviceCtor) {
      throw new Error("mediasoup-client-not-loaded");
    }

    state.device = new DeviceCtor();
    await state.device.load({
      routerRtpCapabilities: rtpCapsRes.rtpCapabilities,
    });
    trace("debug", "mediasoup", "device loaded", {
      canProduceAudio: state.device.canProduce("audio"),
      canProduceVideo: state.device.canProduce("video"),
    });

    var iceCfg = null;
    try {
      iceCfg = await emitAck("MS-get-ice-servers", null, 15000, {
        noPayload: true,
      });
    } catch (err) {
      trace("warn", "ice", "MS-get-ice-servers failed, using fallback config", {
        error: err && err.message ? err.message : String(err),
      });
    }

    var hasBackendServers = !!(
      iceCfg &&
      iceCfg.ok === true &&
      Array.isArray(iceCfg.iceServers) &&
      iceCfg.iceServers.length > 0
    );

    var fallbackIceServers = normalizeIceServers(state.fallbackIceServers);
    var iceServers = hasBackendServers
      ? normalizeIceServers(iceCfg.iceServers)
      : fallbackIceServers;

    var fallbackPolicy = String(
      state.fallbackIceTransportPolicy || "all",
    ).toLowerCase();
    fallbackPolicy = fallbackPolicy === "relay" ? "relay" : "all";

    var backendPolicy =
      iceCfg &&
      iceCfg.ok === true &&
      typeof iceCfg.iceTransportPolicy === "string"
        ? String(iceCfg.iceTransportPolicy).toLowerCase()
        : "";

    var iceTransportPolicy = backendPolicy || fallbackPolicy;

    trace("debug", "ice", "resolved ICE config", {
      backendAvailable: hasBackendServers,
      backendServerCount: hasBackendServers ? iceCfg.iceServers.length : 0,
      fallbackServerCount: fallbackIceServers.length,
      usingServerCount: iceServers.length,
      policy: iceTransportPolicy,
    });

    var sendInfo = await emitAck("MS-create-transport", {
      roomId: state.roomId,
      userId: state.userId,
      direction: "send",
    });

    if (!sendInfo || !sendInfo.ok) {
      throw new Error("create-send-transport-failed");
    }

    state.sendIceParameters = sendInfo.iceParameters || null;
    state.sendConnectionState = "new";

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
      })
        .then(function (res) {
          if (res && res.ok) callback();
          else errback(new Error("send-connect-failed"));
        })
        .catch(errback);
    });

    state.sendTransport.on("produce", function (_ref2, callback, errback) {
      emitAck("MS-produce", {
        roomId: state.roomId,
        userId: state.userId,
        transportId: state.sendTransport.id,
        kind: _ref2.kind,
        rtpParameters: _ref2.rtpParameters,
      })
        .then(function (res) {
          if (res && res.ok && res.id) callback({ id: res.id });
          else errback(new Error("produce-failed"));
        })
        .catch(errback);
    });

    state.sendTransport.on("connectionstatechange", function (connectionState) {
      onSendTransportStateChanged(connectionState);
    });

    trace("debug", "mediasoup", "send transport created", {
      transportId: sendInfo.id,
    });

    var recvInfo = await emitAck("MS-create-transport", {
      roomId: state.roomId,
      userId: state.userId,
      direction: "recv",
    });

    if (!recvInfo || !recvInfo.ok) {
      throw new Error("create-recv-transport-failed");
    }

    state.recvIceParameters = recvInfo.iceParameters || null;
    state.recvConnectionState = "new";

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
      })
        .then(function (res) {
          if (res && res.ok) callback();
          else errback(new Error("recv-connect-failed"));
        })
        .catch(errback);
    });

    state.recvTransport.on("connectionstatechange", function (connectionState) {
      onRecvTransportStateChanged(connectionState);
    });

    trace("debug", "mediasoup", "recv transport created", {
      transportId: recvInfo.id,
    });

    // Produce local tracks
    var audioTrack = state.localStream.getAudioTracks()[0];
    if (audioTrack) {
      state.audioProducer = await state.sendTransport.produce({
        track: audioTrack,
      });
      trace("debug", "mediasoup", "audio producer created", {
        producerId: state.audioProducer && state.audioProducer.id,
      });
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
        trace("debug", "mediasoup", "video producer created", {
          producerId: state.videoProducer && state.videoProducer.id,
        });
      }
    }

    // Consume existing producers
    var producersRes = await emitAck("MS-get-producers", {
      roomId: state.roomId,
      userId: state.userId,
    });
    var producers =
      producersRes && producersRes.ok && producersRes.producers
        ? producersRes.producers
        : [];

    for (var i = 0; i < producers.length; i += 1) {
      var p = producers[i];
      await consumeProducer(p.producerId, p.userId, p.kind);
    }

    trace("debug", "mediasoup", "joinRoomAndMediasoup complete", {
      existingProducerCount: producers.length,
    });
    setStatus("in_call", "Connected with mediasoup SFU.");
  }

  async function consumeProducer(producerId, remoteUserId, kindHint) {
    trace("debug", "mediasoup", "consumeProducer start", {
      producerId: producerId,
      remoteUserId: remoteUserId,
      kindHint: kindHint,
    });
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

      if (consumer && consumer.track) {
        consumer.track.onended = function () {
          scheduleIceRestart("both", 500);
        };
      }

      state.consumers[consumer.id] = consumer;
      trace("debug", "mediasoup", "consumer created", {
        consumerId: consumer.id,
        producerId: consumeRes.producerId,
        kind: consumeRes.kind,
      });

      var userId = String(remoteUserId || "unknown");
      var stream = state.remoteStreams[userId];
      if (!stream) {
        stream = new MediaStream();
        state.remoteStreams[userId] = stream;
      }

      var kind = consumeRes.kind || kindHint || consumer.kind;
      removeTracksOfKind(stream, kind);
      stream.addTrack(consumer.track);

      var meta = state.remoteUserMeta[userId] || {};
      if (kind === "video") {
        meta.video = true;
      }
      if (kind === "audio") {
        meta.audio = true;
      }
      state.remoteUserMeta[userId] = meta;

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

      trace("debug", "mediasoup", "consumeProducer complete", {
        producerId: producerId,
        remoteUserId: userId,
        kind: kind,
      });
    } catch (err) {
      delete state.consumedProducerIds[producerId];
      trace("error", "mediasoup", "consumeProducer error", {
        producerId: producerId,
        error: err && err.message ? err.message : String(err),
      });
      console.error("consumeProducer error", err);
    }
  }

  function waitForSocketConnection(timeoutMs) {
    timeoutMs = timeoutMs || 18000;

    return new Promise(function (resolve, reject) {
      if (!state.socket) {
        reject(new Error("socket-not-initialized"));
        return;
      }

      if (state.socket.connected === true) {
        resolve();
        return;
      }

      var done = false;
      var timeout = setTimeout(function () {
        if (done) return;
        done = true;
        cleanup();
        reject(new Error("socket-connect-timeout"));
      }, timeoutMs);

      function cleanup() {
        clearTimeout(timeout);
        state.socket.off("connect", onConnect);
        state.socket.off("connect_error", onConnectError);
      }

      function onConnect() {
        if (done) return;
        done = true;
        cleanup();
        resolve();
      }

      function onConnectError(err) {
        if (done) return;
        done = true;
        cleanup();
        reject(err || new Error("socket-connect-error"));
      }

      state.socket.on("connect", onConnect);
      state.socket.on("connect_error", onConnectError);
    });
  }

  async function startCall(payload, options) {
    options = options || {};
    trace("debug", "call", "startCall invoked", {
      roomId: payload && payload.roomId,
      userId: payload && payload.userId,
      callType: payload && payload.callType,
      skipCleanup: options.skipCleanup === true,
      isRecovery: options.isRecovery === true,
      reason: options.reason || "",
    });

    var startToken = state.startToken + 1;
    state.startToken = startToken;
    state.isStopping = false;

    if (!options.skipCleanup) {
      await stopCall({
        emitLeave: false,
        notifyFlutterEnded: false,
        preserveViewMode: true,
        clearBootstrap: false,
        invalidateStartToken: false,
      });
    }

    if (startToken !== state.startToken) {
      return;
    }

    state.socketUrl = payload.socketUrl || state.socketUrl || "";
    state.roomId = payload.roomId;
    state.userId = payload.userId;
    state.fullName = payload.fullName || payload.userId;
    state.groupName = payload.groupName || "Group Call";
    state.callerName = payload.callerName || state.fullName;
    state.groupImage = payload.groupImage || "";
    state.callType = payload.callType || "video";
    state.joinEvent = payload.joinEvent || "BE-join-room";
    state.leaveEvent = payload.leaveEvent || "BE-leave-room";
    state.participantDirectory = {};
    state.remoteUserMeta = {};
    state.socketToUserMap = {};
    state.userToSocketMap = {};
    state.remoteRenderReady = {};
    state.localRenderReady = false;

    state.fallbackIceServers = normalizeIceServers(
      payload.fallbackIceServers || state.fallbackIceServers || [],
    );
    var fallbackPolicy = String(
      payload.fallbackIceTransportPolicy ||
        state.fallbackIceTransportPolicy ||
        "all",
    ).toLowerCase();
    state.fallbackIceTransportPolicy =
      fallbackPolicy === "relay" ? "relay" : "all";

    state.bootstrapPayload = Object.assign({}, payload, {
      socketUrl: state.socketUrl,
      viewMode: payload.viewMode === "pip" ? "pip" : state.viewMode || "normal",
    });

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

    setViewMode(state.bootstrapPayload.viewMode || "normal");
    $("#roomTitle").text(state.groupName);

    // Update local badge with user name
    var localBadge = document.getElementById("localBadge");
    if (localBadge) {
      localBadge.textContent = state.fullName || "You";
    }
    // Update local avatar with initials
    var localAvatar = document.querySelector(".local-avatar");
    if (localAvatar) {
      localAvatar.textContent = getInitials(state.fullName || "You");
    }

    if (!state.socketUrl) {
      throw new Error("missing-socket-url");
    }

    clearRecoveryTimers();

    await waitForMediasoupReady();
    if (startToken !== state.startToken) {
      return;
    }

    await connectSocket(state.socketUrl);
    await waitForSocketConnection(18000);
    if (startToken !== state.startToken) {
      return;
    }

    await initializeMedia();
    if (startToken !== state.startToken) {
      return;
    }

    await joinRoomAndMediasoup();
    if (startToken !== state.startToken) {
      return;
    }

    trace("debug", "call", "startCall completed", {
      roomId: state.roomId,
      callType: state.callType,
    });
  }

  async function stopCall(options) {
    options = options || {};
    trace("warn", "call", "stopCall invoked", {
      emitLeave: options.emitLeave !== false,
      notifyFlutterEnded: options.notifyFlutterEnded !== false,
      preserveViewMode: options.preserveViewMode === true,
      clearBootstrap: options.clearBootstrap,
      invalidateStartToken: options.invalidateStartToken,
    });

    // Invalidate any in-flight start sequence so stale async steps do not
    // reopen transports after a user-initiated leave.
    var invalidateStartToken = options.invalidateStartToken !== false;
    if (invalidateStartToken) {
      state.startToken += 1;
    }

    var emitLeave = options.emitLeave !== false;
    var notifyFlutterEnded = options.notifyFlutterEnded !== false;
    var preserveViewMode = options.preserveViewMode === true;
    var clearBootstrap =
      typeof options.clearBootstrap === "boolean"
        ? options.clearBootstrap
        : notifyFlutterEnded;

    clearRecoveryTimers();
    state.isStopping = true;

    try {
      if (emitLeave && state.socket) {
        try {
          state.socket.emit(state.leaveEvent || "BE-leave-room", {
            roomId: state.roomId,
            leaver: state.userId,
          });
        } catch (_) {}

        try {
          state.socket.emit("call_disconnect", {
            roomId: state.roomId,
            userId: state.socket.id,
          });
        } catch (_) {}
      }

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
        state.localStream.getTracks().forEach(function (track) {
          try {
            track.stop();
          } catch (_) {}
        });
      }

      if (state.socket) {
        try {
          state.socket.off("connect");
          state.socket.off("reconnect");
          state.socket.off("disconnect");
          state.socket.off("connect_error");
          state.socket.off("FE-user-join");
          state.socket.off("MS-new-producer");
          state.socket.off("FE-user-leave");
          state.socket.off("FE-user-disconnected");
          state.socket.off("FE-toggle-camera");
          state.socket.off("FE-call-ended");
          state.socket.disconnect();
        } catch (_) {}
      }
    } finally {
      state.localStream = null;
      state.socket = null;
      state.sendTransport = null;
      state.recvTransport = null;
      state.sendIceParameters = null;
      state.recvIceParameters = null;
      state.sendConnectionState = "closed";
      state.recvConnectionState = "closed";
      state.device = null;
      state.audioProducer = null;
      state.videoProducer = null;
      state.callerName = "";
      state.groupImage = "";
      state.remoteStreams = {};
      state.remoteUserMeta = {};
      state.socketToUserMap = {};
      state.userToSocketMap = {};
      state.remoteRenderReady = {};
      state.localRenderReady = false;
      state.participantDirectory = {};
      state.consumedProducerIds = {};
      state.lastIceRestartAt = 0;
      state.iceRestartWindowStart = 0;
      state.iceRestartBurstCount = 0;
      state.isRestartingIce = false;
      state.isRecovering = false;

      if (clearBootstrap) {
        state.bootstrapPayload = null;
        state.socketUrl = "";
      }

      var localVideo = document.getElementById("localVideo");
      if (localVideo) {
        try {
          localVideo.srcObject = null;
        } catch (_) {}
        localVideo.classList.remove("is-ready");
      }

      var localPlaceholder = document.getElementById("localPlaceholder");
      if (localPlaceholder) {
        localPlaceholder.classList.remove("hidden");
      }
      setLocalPlaceholderText("Preparing camera...");

      var tiles = document.querySelectorAll(".tile[id^='remote-']");
      tiles.forEach(function (el) {
        el.remove();
      });

      if (!preserveViewMode) {
        setViewMode("normal");
      } else {
        updateGridLayout();
      }

      if (notifyFlutterEnded) {
        setStatus("left", "You left the call.");
        postToFlutter("ended", {});
      } else {
        setStatus("idle", "Preparing media...");
      }

      state.isStopping = false;
      trace("debug", "call", "stopCall completed", {
        notifyFlutterEnded: notifyFlutterEnded,
      });
    }
  }

  async function toggleMic(enabled) {
    trace("debug", "media", "toggleMic", { enabled: enabled });
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
    trace("debug", "media", "toggleCamera", { enabled: enabled });
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

    if (enabled) {
      // Re-trigger play to fire loadeddata/playing events for render readiness
      var localVideo = document.getElementById("localVideo");
      if (localVideo && localVideo.srcObject) {
        state.localRenderReady = false;
        localVideo
          .play()
          .then(function () {
            markLocalRenderReady(true, "camera-re-enabled");
          })
          .catch(function () {
            markLocalRenderReady(true, "camera-re-enabled-fallback");
          });
      } else {
        setLocalPlaceholderText("Starting camera...");
        state.localRenderReady = false;
        updateLocalVisualState(state.localStream);
      }
    } else {
      setLocalPlaceholderText("Camera is off");
      state.localRenderReady = false;
      updateLocalVisualState(state.localStream);
    }

    if (state.socket && state.roomId) {
      state.socket.emit("BE-toggle-camera-audio", {
        roomId: state.roomId,
        switchTarget: "video",
      });
    }

    postToFlutter("camera", { enabled: enabled });
  }

  async function switchCamera() {
    trace("debug", "media", "switchCamera requested", {
      currentFacing: state.facingMode,
    });
    if (state.callType !== "video") return;

    var nextFacing = state.facingMode === "user" ? "environment" : "user";
    var videoConstraints = {
      width: { ideal: 640, max: 960 },
      height: { ideal: 360, max: 540 },
      frameRate: { ideal: 15, max: 20 },
    };

    var newStream;
    try {
      // Use exact facingMode to ensure the correct camera is selected on real devices
      var exactConstraints = Object.assign({}, videoConstraints, {
        facingMode: { exact: nextFacing },
      });
      newStream = await navigator.mediaDevices.getUserMedia({
        audio: false,
        video: exactConstraints,
      });
    } catch (exactErr) {
      trace(
        "warn",
        "media",
        "switchCamera exact facingMode failed, trying ideal",
        {
          error:
            exactErr && exactErr.message ? exactErr.message : String(exactErr),
          nextFacing: nextFacing,
        },
      );
      // Fallback: try with ideal facingMode (for emulators or devices with limited cameras)
      try {
        var idealConstraints = Object.assign({}, videoConstraints, {
          facingMode: { ideal: nextFacing },
        });
        newStream = await navigator.mediaDevices.getUserMedia({
          audio: false,
          video: idealConstraints,
        });
      } catch (_) {
        // Keep existing track if alternate camera is unavailable.
        return;
      }
    }

    var newTrack = newStream.getVideoTracks()[0];
    if (!newTrack) return;

    var oldTrack =
      state.localStream && state.localStream.getVideoTracks().length
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
    configureVideoElement(localVideo, {
      isLocal: true,
      userId: state.userId,
      muted: true,
    });
    state.localRenderReady = false;
    localVideo.srcObject = state.localStream;
    localVideo.play().catch(function (err) {
      trace("warn", "local-video", "switchCamera play() rejected", {
        error: err && err.message ? err.message : String(err),
      });
    });

    state.facingMode = nextFacing;
    updateLocalVisualState(state.localStream);
    trace("debug", "media", "switchCamera completed", {
      facingMode: state.facingMode,
    });
  }

  function toggleSpeaker(enabled) {
    state.isSpeakerEnabled = enabled;
    trace("debug", "media", "toggleSpeaker", { enabled: enabled });
    postToFlutter("speaker", { enabled: enabled });
  }

  function receiveFromFlutter(raw) {
    try {
      var parsed = JSON.parse(raw);
      var action = parsed.action;
      var payload = parsed.payload || {};
      trace("debug", "bridge", "receiveFromFlutter action", {
        action: action,
      });

      if (action === "bootstrap") {
        setStatus("bootstrapping", "Connecting to call service...");
        startCall(payload, { skipCleanup: false }).catch(function (err) {
          console.error("bootstrap failed", err);
          setStatus("error", "Failed to initialize call.");
          postToFlutter("error", {
            message:
              (err && err.name ? err.name + ": " : "") +
              (err && err.message ? err.message : String(err)),
          });
        });
      } else if (action === "rejectCall") {
        if (state.socket && payload.roomId) {
          state.socket.emit("BE-reject-call", {
            roomId: payload.roomId,
          });
        }
        stopCall({
          emitLeave: true,
          notifyFlutterEnded: true,
          preserveViewMode: false,
          clearBootstrap: true,
        });
      } else if (action === "leaveCall") {
        stopCall({
          emitLeave: true,
          notifyFlutterEnded: true,
          preserveViewMode: false,
          clearBootstrap: true,
        });
      } else if (action === "toggleMic") {
        toggleMic(!!payload.enabled);
      } else if (action === "toggleCamera") {
        toggleCamera(!!payload.enabled);
      } else if (action === "switchCamera") {
        switchCamera().catch(function (err) {
          postToFlutter("error", {
            message:
              "switch-camera-failed: " +
              (err && err.message ? err.message : String(err)),
          });
        });
      } else if (action === "toggleSpeaker") {
        toggleSpeaker(!!payload.enabled);
      } else if (action === "reconnect") {
        if (state.socket && state.socket.connected) {
          scheduleIceRestart("both", 300);
        } else if (state.socket && !state.socket.connected) {
          try {
            state.socket.connect();
          } catch (_) {}
          scheduleFullRecover("manual-reconnect", 900);
        } else {
          scheduleFullRecover("manual-reconnect", 0);
        }
      } else if (action === "setViewMode") {
        setViewMode(payload.mode === "pip" ? "pip" : "normal");
      }
    } catch (err) {
      trace("error", "bridge", "receiveFromFlutter parse error", {
        error: err && err.message ? err.message : String(err),
        raw: raw,
      });
      postToFlutter("error", { message: "bridge-parse-error" });
    }
  }

  window.CU_EMBEDDED = {
    receiveFromFlutter: receiveFromFlutter,
  };

  window.addEventListener("error", function (event) {
    trace("error", "window", "uncaught error", {
      message: event && event.message ? event.message : "unknown",
      filename: event && event.filename ? event.filename : "",
      lineno: event && event.lineno ? event.lineno : 0,
      colno: event && event.colno ? event.colno : 0,
      stack: event && event.error && event.error.stack ? event.error.stack : "",
    });
  });

  window.addEventListener("unhandledrejection", function (event) {
    trace("error", "window", "unhandled promise rejection", {
      reason: event && event.reason ? safeStringify(event.reason) : "unknown",
    });
  });

  trace("debug", "startup", "embedded group call web app initialized");

  // Start loading mediasoup immediately to reduce bootstrap latency.
  loadMediasoupClient().catch(function (err) {
    trace("error", "mediasoup", "initial mediasoup load failed", {
      error: err && err.message ? err.message : String(err),
    });
    postToFlutter("error", {
      message:
        (err && err.name ? err.name + ": " : "") +
        (err && err.message ? err.message : "mediasoup-load-failed"),
    });
  });

  updateGridLayout();

  // Ready signal for Flutter side.
  trace("debug", "startup", "sending ready signal to Flutter");
  postToFlutter("ready", {});
})();
