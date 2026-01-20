var Player = function(ui) {
	var player = ui._context.createElement('video')
	player.dom.preload = "metadata"

	player.setAttribute('preload', 'auto')
	player.setAttribute('data-setup', '{}')
	player.setAttribute('class', 'video-js')

	this.element = player
	this.ui = ui
	this.setEventListeners()

	var uniqueId = 'videojs' + this.element._uniqueId
	player.setAttribute('id', uniqueId)

	if (ui.element)
		ui.element.remove()
	ui.element = player
	ui.parent.element.append(ui.element)

	this.videojs = window.videojs(uniqueId, { "textTrackSettings": false })

	this.videojs.width = 'auto'
	this.videojs.height = 'auto'

	var errorDisplay = document.getElementsByClassName("vjs-error-display")
	if (errorDisplay && errorDisplay.length) {
		for (var index = 0; index < errorDisplay.length; ++index) {
			errorDisplay[index].style.display = 'none'
		}
	}

	var videojsSpinner = document.getElementsByClassName("vjs-loading-spinner")
	if (videojsSpinner && videojsSpinner.length) {
		for (var index = 0; index < videojsSpinner.length; ++index) {
			videojsSpinner[index].style.display = 'none'
		}
	}

	var videojsControllButton = document.getElementsByClassName("vjs-control-bar")
	if (videojsControllButton && videojsControllButton.length) {
		for (var index = 0; index < videojsControllButton.length; ++index) {
			videojsControllButton[index].style.display = 'none'
		}
	}

	var videojsBigPlayButton = document.getElementsByClassName("vjs-big-play-button")
	if (videojsBigPlayButton && videojsBigPlayButton.length) {
		for (var index = 0; index < videojsBigPlayButton.length; ++index) {
			videojsBigPlayButton[index].style.display = 'none'
		}
	}

	this.videojsContaner = document.getElementById(uniqueId)
	this.videojsContaner.style.zIndex = -1
}

Player.prototype = Object.create(_globals.video.html5.backend.Player.prototype)

// Helper to register and remember listeners so they can be removed in dispose()
Player.prototype._addListener = function(target, type, fn, opts) {
	if (!target || !target.addEventListener) return;
	target.addEventListener(type, fn, opts || false);
	this._eventListeners = this._eventListeners || [];
	this._eventListeners.push({ target: target, type: type, fn: fn, opts: opts || false });
};

// Remove listeners and dispose videojs properly
Player.prototype.dispose = function() {
	if (this._eventListeners) {
		for (var i = 0; i < this._eventListeners.length; ++i) {
			var rec = this._eventListeners[i];
			if (!rec) continue;
			rec.target.removeEventListener(rec.type, rec.fn, rec.opts || false);
		}
		this._eventListeners = [];
	}

	if (this.videojsContaner) {
		window.videojs(this.videojsContaner).dispose();
	}

	if (this.videojs && this.videojs.dispose) {
		this.videojs.dispose();
	}
	this.videojs = null;

	_globals.video.html5.backend.Player.prototype.dispose.apply(this);
};

Player.prototype._syncState = function() {
	var video = this.element && this.element.dom;
	if (!video || !this.ui) return;

	try {
		var paused = !!video.paused;
		var ended = !!video.ended;
		var readyState = typeof video.readyState === 'number' ? video.readyState : 0;
		var currentTime = isFinite(video.currentTime) ? video.currentTime : 0;
		var duration = isFinite(video.duration) ? video.duration : (this.ui.duration || 0);
		this.ui.paused = (paused || ended || !video.src);
		this.ui.waiting = (readyState < 3);
		this.ui.seeking = !!this._seekingFlag || !!video.seeking;
		this.ui.progress = currentTime;
		this.ui.duration = duration;
		this.ui.ready = (readyState >= 3);
	} catch (e) {
		log('syncState error', e);
	}
};

// Attach DOM events to <video> element
Player.prototype.setEventListeners = function() {
	var video = this.element && this.element.dom;
	var self = this;
	if (!video) return;

	var _syncTimer = null;
	function scheduleSync() {
		if (_syncTimer) {
			clearTimeout(_syncTimer);
			_syncTimer = null;
		}
		_syncTimer = setTimeout(function() {
			self._syncState();
			_syncTimer = null;
		}, 50);
	}
	this._addListener(video, 'loadedmetadata', function() {
		self.ui.duration = video.duration || self.ui.duration;
		scheduleSync();
	});
	this._addListener(video, 'canplay', function() {
		self.ui.waiting = false;
		scheduleSync();
	});
	this._addListener(video, 'canplaythrough', function() {
		scheduleSync();
	});
	this._addListener(video, 'play', function() {
		self.ui.paused = false;
		scheduleSync();
	});
	this._addListener(video, 'playing', function() {
		self.ui.waiting = false;
		scheduleSync();
	});
	this._addListener(video, 'pause', function() {
		self.ui.paused = true;
		scheduleSync();
	});
	this._addListener(video, 'ended', function() {
		self.ui.paused = true;
		if (self.ui.finished) self.ui.finished();
		scheduleSync();
	});
	this._addListener(video, 'waiting', function() {
		self.ui.waiting = true;
		scheduleSync();
	});
	this._addListener(video, 'stalled', function() {
		self.ui.waiting = true;
		scheduleSync();
	});
	this._addListener(video, 'seeking', function() {
		self._seekingFlag = true;
		self.ui.seeking = true;
		scheduleSync();
	});
	this._addListener(video, 'seeked', function() {
		self._seekingFlag = false;
		self.ui.seeking = false;
		scheduleSync();
	});
	this._addListener(video, 'timeupdate', function() {
		self.ui.progress = video.currentTime;
		scheduleSync();
	});
	this._addListener(video, 'error', function(e) {
		log('video error', e, video.error);
		self.ui.ready = false;
		if (self.ui.error) self.ui.error({ type: 'MEDIA_ERROR', message: String(video.error) });
		scheduleSync();
	});
	this._addListener(video, 'loadeddata', function() {
		scheduleSync();
	});
	this._addListener(video, 'emptied', function() {
		self.ui.paused = true;
		self.ui.waiting = false;
		self.ui.seeking = false;
		self.ui.progress = 0;
		scheduleSync();
	});
	this._addListener(video, 'loadstart', function() {
		self.ui.waiting = true;
		scheduleSync();
	});
};

Player.prototype.setSource = function(url) {
	var media = { 'src': url };
	log("SetSource", url);

	if (this.element && this.element.dom) {
		try {
			if (typeof this.element.dom.pause === 'function') {
				this.element.dom.pause();
			}
		} catch (e_pause) {
			log("pause before setSource failed", e_pause);
		}
		this.ui.paused = true
		this.ui.waiting = true
		this.ui.seeking = false
		this.ui.ready = false
	}

	if (url) {
		var urlLower = url.toLowerCase();
		var querryIndex = url.indexOf("?");
		if (querryIndex >= 0)
			urlLower = urlLower.substring(0, querryIndex);
		var extIndex = urlLower.lastIndexOf(".");
		var extension = urlLower.substring(extIndex, urlLower.length);
		if (extension === ".m3u8" || extension === ".m3u")
			media.type = 'application/x-mpegURL';
		else if (extension === ".mpd")
			media.type = 'application/dash+xml';
	}

	try {
		this.videojs.src(media, { html5: { hls: { withCredentials: true } }, fluid: true, preload: 'none', techOrder: ["html5"] });
	} catch (e_src) {
		log("videojs.src failed", e_src);
	}

	var self = this;
	// give video/videojs small time to update state, then sync
	setTimeout(function(){ self._syncState(); }, 80);

	if (this.ui.autoPlay) this.play();
};

Player.prototype.getSubtitles = function() {
	var tracks = this.videojs.textTracks();
	var subsTracks = [];
	subsTracks.push({ id: "off", label: "Выкл", active: true });

	if (tracks && tracks.tracks_) {
		for (var i = 0; i < tracks.tracks_.length; ++i) {
			var track = tracks.tracks_[i];
			log(track.label);
			if (track.kind == "subtitles") {
				subsTracks.push({
					id: track.id,
					active: (track.mode == 'showing'),
					language: track.language,
					label: track.label
				});
			}
		}
	}
	return subsTracks;
};

Player.prototype.setSubtitles = function(trackId) {
	var tracks = this.videojs.textTracks().tracks_;
	var subTrack = null;
	var i;
	for (i = 0; i < tracks.length; ++i) {
		if (tracks[i].id === trackId) {
			subTrack = tracks[i];
			break;
		}
	}

	for (i = 0; i < tracks.length; ++i) {
		if (subTrack && tracks[i].id === subTrack.id) {
			tracks[i].mode = 'showing';
		} else {
			tracks[i].mode = 'disabled';
		}
	}
};

Player.prototype.play = function() {
	this.ui.paused = false;

	try {
		this.element.dom.play();
	} catch (e_play) {
		log('play() DOM call threw', e_play);
	}

	var self = this;
	setTimeout(function() {
		self._syncState();
	}, 80);

	setTimeout(function() {
		self._syncState()
	}, 80);
};

Player.prototype.setRect = function(l, t, r, b) {
	this.videojsContaner.style.width = (r - l) + "px"
	this.videojsContaner.style.height = (b - t) + "px"
}

exports.createPlayer = function(ui) {
	return new Player(ui)
}

exports.probeUrl = function(url) {
	return window.videojs ? 60 : 0
}
