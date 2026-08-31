var shakaGetMessage = function(code) {
	for (var k in shaka.util.Error.Code) {
		if (shaka.util.Error.Code[k] == code)
			return k
	}
}

var shakaSignalError = function(ui, err) {
	if (!err.message)
		err.message = shakaGetMessage(err.code)
	ui.error(err)
}

var Player = function(ui) {
	shaka.polyfill.installAll();

	var player = ui._context.createElement('video')
	this._player = player
	player.dom.style.zIndex = -1;
	player.dom.id = "shaka-player-element";

	if (!shaka.Player.isBrowserSupported()) {
		throw new Error("browser is not supported, backend should not have been registered")
	}

	var shakaPlayer = new shaka.Player(player.dom);
	this.shakaPlayer = shakaPlayer;

	this.element = player
	this.ui = ui
	this.setEventListeners()

	// FIX для старых WebOS: если плеер сжимает 16:9 картинку в 5:4 (что часто бывает с SD каналами 720x576),
	// мы принудительно растягиваем его по ширине через CSS transform.
	player.dom.style.width = "100%";
	player.dom.style.height = "100%";
	if (window.webOS) {
		player.dom.style.objectFit = "fill";
		
		player.dom.addEventListener('loadedmetadata', function() {
			var w = player.dom.videoWidth;
			var h = player.dom.videoHeight;
			if (w && h) {
				var ratio = w / h;
				log("Shaka Player loaded video, intrinsic dimensions: " + w + "x" + h + " ratio: " + ratio);
				// Если видео 720x576 (ratio 1.25), а мы хотим 16:9 (ratio 1.777),
				// нужно растянуть его по ширине в 1.422 раза.
				if (ratio > 1.2 && ratio < 1.3) {
					log("Detected anamorphic SD 5:4 (e.g. 720x576). Applying aspect ratio fix (scaleX) for old WebOS.");
					player.dom.style.transform = "scaleX(1.4222)";
				} else {
					player.dom.style.transform = "scaleX(1)";
				}
			}
		});
	}

	if (ui.element && ui.element.remove) {
		try {
			ui.element.remove()
		} catch(e) {
			log("Failed to remove old ui.element", e)
		}
	} else if (ui.element && ui.element.dom && ui.element.dom.parentNode) {
		try {
			ui.element.dom.parentNode.removeChild(ui.element.dom)
		} catch(e) {
			log("Failed to removeChild from parent", e)
		}
	}
	ui.element = player
	ui.parent.element.append(ui.element)
}

Player.prototype = Object.create(_globals.video.html5.backend.Player.prototype)

Player.prototype.setupDrm = function(type, options, callback, error) {
	var laServer = {}
	if (type === "widevine")
		laServer["com.widevine.alpha"] = options.laServer
	else if (type === "playready")
		laServer["com.microsoft.playready"] = options.laServer
	else
		error ? error(new Error("Unknown or not supported DRM type " + type)) : log("Unknown or not supported DRM type " + type)

	var config = { drm: { servers: laServer } }
	var ui = this.ui
	log("DefaultBand", ui.maxBandwidth)
	config.abr = { switchInterval: 1 }
	if (ui.maxBandwidth || ui.minBandwidth) {
		var restrictions = {}
		if (ui.maxBandwidth)
			restrictions.maxBandwidth = ui.maxBandwidth
		if (ui.minBandwidth)
			restrictions.minBandwidth = ui.minBandwidth

		config.abr.restrictions = restrictions
	}

	config.streaming = { bufferingGoal: 1, rebufferingGoal: 1 }

	log("SetupDRM", config)
	this.shakaPlayer.configure(config);
	if (callback)
		callback()
}

Player.prototype.stop = function() {
	log("stop player")
	try {
		if (this.shakaPlayer) {
			this.shakaPlayer.unload()
		}
	} catch(e) {
		log("Error unloading shaka player", e)
	}
}

Player.prototype.setSource = function(url) {
	var ui = this.ui
	this._language = null
	this._videoTrackHeight = null
	this.ui.ready = false
	if (url) {
		var self = this
		this.shakaPlayer.load(url)
			.then(function() {
				console.log('The video has now been loaded!');
				if (ui.autoPlay)
					self.play()
			})
			.catch(ui._context.wrapNativeCallback(function(err) { log("Failed to load manifest", err); shakaSignalError(ui, err) }));
	}
}

Player.prototype.getVideoTracks = function() {
	var video = []
	var tracks = this.shakaPlayer.getVariantTracks()

	var lang = tracks && tracks.length ? tracks[0].language : ""
	for (var i = 0; i < tracks.length; ++i) {
		var track = tracks[i]
		if (track.language == lang) {
			video.push({
				id: track.id,
				width: track.width,
				height: track.height,
				active: track.active,
				framerate: track.frameRate,
				bandwidth: track.videoBandwidth,
				audiocodec: track.audioCodec,
				videocodec: track.codecs
			})
		}
	}
	return video
}

Player.prototype.getAudioTracks = function() {
	var tracks = this.shakaPlayer.getVariantTracks()
	var audioTracks = {}
	for (var i = 0; i < tracks.length; ++i) {
		var track = tracks[i]
		if (audioTracks[track.audioId])
			continue

		audioTracks[track.audioId] = {
			id: track.audioId,
			language: track.language,
			codec: track.audioCodec
		}
	}

	var audio = []
	for (var i in audioTracks) {
		audio.push(audioTracks[i])
	}
	log("Available audio tracks", audio)

	return audio
}

Player.prototype.setAudioTrack = function(trackId) {
	var tracks = this.shakaPlayer.getVariantTracks()

	var found = tracks.filter(function(element) {
		return element.audioId === trackId
	})

	log("Try to set audio track", found)
	if (found && found.length) {
		var video = found[0]
		var height = this._videoTrackHeight
		if (height && height != video.height) {
			var foundHeight = tracks.filter(function(element) {
				return element.language === video.language && element.height === height
			})
			if (foundHeight && foundHeight.length)
				video = foundHeight[0]
		}

		var abr = {
			enabled: false,
			switchInterval: 0,
			restrictions: { }
		}

		var ui = this.ui
		if (ui.defaultBandwidth)
			abr.restrictions.defaultBandwidthEstimate = ui.defaultBandwidth

		if (ui.maxBandwidth)
			abr.restrictions.maxBandwidth = ui.maxBandwidth

		if (ui.minBandwidth)
			abr.restrictions.minBandwidth = ui.minBandwidth

		this.shakaPlayer.configure({
			abr: abr,
			streaming: { bufferingGoal: 1, rebufferingGoal: 1 }
		});
		this._language = found[0].language
		this.shakaPlayer.selectVariantTrack(video, true)
	}
}

Player.prototype.setVideoTrack = function(trackId) {
	var tracks = this.shakaPlayer.getVariantTracks()

	var found = tracks.filter(function(element) {
		return element.id === trackId
	})

	log("Try to set video track", found)
	if (found && found.length) {
		var video = found[0]
		var lang = this._language
		if (lang && lang != video.language) {
			var foundLang = tracks.filter(function(element) {
				return element.height === video.height && element.language === lang
			})
			if (foundLang && foundLang.length)
				video = foundLang[0]
		}

		var abr = {
			enabled: false,
			switchInterval: 0,
			restrictions: { }
		}

		var ui = this.ui

		if (ui.maxBandwidth)
			abr.restrictions.maxBandwidth = ui.maxBandwidth

		if (ui.minBandwidth)
			abr.restrictions.minBandwidth = ui.minBandwidth

		this.shakaPlayer.configure({
			abr: abr,
			streaming: { bufferingGoal: 1, rebufferingGoal: 1 }
		});
		this._videoTrackHeight = video.height
		this.shakaPlayer.selectVariantTrack(video)
	}
}

Player.prototype.getSubtitles = function() {
	var tracks = this.shakaPlayer.getTextTracks()
	var subsTracks = []
	subsTracks.push({
		id: "off",
		label: "Выкл"
	})
	for (var i = 0; i < tracks.length; ++i) {
		var track = tracks[i]
		subsTracks.push({
			id: track.id,
			active: track.active,
			label: "Русский",
			language: track.language
		})
	}
	return subsTracks
}

Player.prototype.setSubtitles = function(trackId) {
	if (trackId == "off") {
		this.shakaPlayer.setTextTrackVisibility(false)
		return
	}

	var tracks = this.shakaPlayer.getTextTracks()

	var found = tracks.filter(function(element) {
		return element.id === trackId
	})

	if (found && found.length) {
		var subtitles = found[0]
		this.shakaPlayer.selectTextTrack(subtitles)
		this.shakaPlayer.setTextTrackVisibility(true)
	}
}

exports.createPlayer = function(ui) {
	return new Player(ui)
}

exports.probeUrl = function(url) {
	return 150
}

Player.prototype.dispose = function() {
	_globals.video.html5.backend.Player.prototype.dispose.apply(this)
	if (this.shakaPlayer) {
		this.shakaPlayer.destroy()
		this.shakaPlayer = null
	}
}

exports.Player = Player
