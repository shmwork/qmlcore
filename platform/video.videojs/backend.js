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
	try {
		var i;
		if (this._eventListeners) {
			for (i = 0; i < this._eventListeners.length; ++i) {
				var rec = this._eventListeners[i];
				if (!rec) continue;
				try {
					rec.target.removeEventListener(rec.type, rec.fn, rec.opts || false);
				} catch (e) {}
			}
			this._eventListeners = [];
		}
	} catch (e) {}

	try {
		if (this.videojsContaner) {
			window.videojs(this.videojsContaner).dispose();
		}
	} catch (e) {}

	try {
		if (this.videojs && this.videojs.dispose) {
			this.videojs.dispose();
		}
	} catch (e) { }
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

		// Map paused: include ended and no-src as paused-like states per your requirement
		this.ui.paused = (paused || ended || !video.src);

		// waiting when not enough data (readyState < HAVE_FUTURE_DATA)
		this.ui.waiting = (readyState < 3);

		// seeking: prefer internal flag or DOM seeking
		this.ui.seeking = !!this._seekingFlag || !!video.seeking;

		// progress / duration
		this.ui.progress = currentTime;
		this.ui.duration = duration;

		// ready: consider ready when HAVE_FUTURE_DATA or higher (3 or 4)
		this.ui.ready = (readyState >= 3);

		log('syncState -> paused:', this.ui.paused, 'waiting:', this.ui.waiting, 'seeking:', this.ui.seeking,
			'readyState:', readyState, 'currentTime:', currentTime, 'duration:', duration);
	} catch (e) {
		log('syncState error', e);
	}
};

// Attach DOM events to <video> element (ES5)
Player.prototype.setEventListeners = function() {
	var video = this.element && this.element.dom;
	var self = this;
	if (!video) return;

	var _syncTimer = null;
	function scheduleSync(delay) {
		delay = typeof delay === 'number' ? delay : 50;
		if (_syncTimer) {
			clearTimeout(_syncTimer);
			_syncTimer = null;
		}
		_syncTimer = setTimeout(function() {
			try { self._syncState(); } catch (e) {}
			_syncTimer = null;
		}, delay);
	}

	// loadedmetadata
	this._addListener(video, 'loadedmetadata', function() {
		try { self.ui.duration = video.duration || self.ui.duration; } catch (e) {}
		scheduleSync(0);
	});

	// canplay / canplaythrough
	this._addListener(video, 'canplay', function() {
		try { self.ui.waiting = false; } catch (e) {}
		scheduleSync(0);
	});
	this._addListener(video, 'canplaythrough', function() {
		scheduleSync(0);
	});

	// play / playing
	this._addListener(video, 'play', function() {
		try { self.ui.paused = false; } catch (e) {}
		scheduleSync(150);
	});
	this._addListener(video, 'playing', function() {
		try { self.ui.waiting = false; } catch (e) {}
		scheduleSync(0);
	});

	// pause
	this._addListener(video, 'pause', function() {
		try { self.ui.paused = true; } catch (e) {}
		scheduleSync(0);
	});

	// ended
	this._addListener(video, 'ended', function() {
		try { self.ui.paused = true; } catch (e) {}
		try { if (self.ui.finished) self.ui.finished(); } catch (e) {}
		scheduleSync(0);
	});

	// waiting / stalled (buffering)
	this._addListener(video, 'waiting', function() {
		try { self.ui.waiting = true; } catch (e) {}
		scheduleSync(0);
	});
	this._addListener(video, 'stalled', function() {
		try { self.ui.waiting = true; } catch (e) {}
		scheduleSync(0);
	});

	// seeking / seeked
	this._addListener(video, 'seeking', function() {
		self._seekingFlag = true;
		try { self.ui.seeking = true; } catch (e) {}
		scheduleSync(0);
	});
	this._addListener(video, 'seeked', function() {
		self._seekingFlag = false;
		try { self.ui.seeking = false; } catch (e) {}
		scheduleSync(0);
	});

	// timeupdate
	this._addListener(video, 'timeupdate', function() {
		try { self.ui.progress = video.currentTime; } catch (e) {}
		scheduleSync(400);
	});

	// error
	this._addListener(video, 'error', function(e) {
		log('video error', e, video.error);
		try {
			self.ui.ready = false;
			if (self.ui.error) self.ui.error({ type: 'MEDIA_ERROR', message: String(video.error) });
		} catch (ex) {}
		scheduleSync(0);
	});

	// loadeddata to ensure sync after initial data
	this._addListener(video, 'loadeddata', function() {
		scheduleSync(0);
	});

	// emptied: fired when the media element has been emptied (e.g., src removed or set to empty)
	this._addListener(video, 'emptied', function() {
		try {
			// consider emptied as paused-like state (matches your mapping)
			self.ui.paused = true;
			self.ui.waiting = false;
			self.ui.seeking = false;
			// progress may reset to 0
			try { self.ui.progress = 0; } catch (e) {}
		} catch (e) {}
		scheduleSync(0);
	});

	// loadstart: useful to mark waiting when a new src is assigned
	this._addListener(video, 'loadstart', function() {
		try { self.ui.waiting = true; } catch (e) {}
		scheduleSync(0);
	});
};

// setSource: keep behaviour, but pause current video and set ui.paused so it doesn't "stick"
Player.prototype.setSource = function(url) {
	var media = { 'src': url };
	log("SetSource", url);

	// ensure current playback is paused and UI reflects it before switching src
	try {
		if (this.element && this.element.dom) {
			try {
				// pause existing playback (may be a no-op if already paused)
				if (typeof this.element.dom.pause === 'function') {
					this.element.dom.pause();
				}
			} catch (e_pause) {
				log("pause before setSource failed", e_pause);
			}
			// set paused-like flags immediately so UI won't remain in playing state
			try { this.ui.paused = true; } catch (e) {}
			try { this.ui.waiting = true; } catch (e) {}
			try { this.ui.seeking = false; } catch (e) {}
			try { this.ui.ready = false; } catch (e) {}
		}
	} catch (e) {
		log("pre-setSource guard failed", e);
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
	// give video/videojs small time to update DOM/state, then sync
	setTimeout(function(){ try { self._syncState(); } catch (e) {} }, 120);

	if (this.ui.autoPlay) this.play();
};

// getSubtitles: ES5-safe iteration
Player.prototype.getSubtitles = function() {
	var tracks = this.videojs.textTracks();
	var subsTracks = [];
	subsTracks.push({ id: "off", label: "Выкл", active: true });

	var i;
	if (tracks && tracks.tracks_) {
		for (i = 0; i < tracks.tracks_.length; ++i) {
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

// setSubtitles: ES5-compatible, no Array.find / map used for side effects
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
		try {
			if (subTrack && tracks[i].id === subTrack.id) {
				tracks[i].mode = 'showing';
			} else {
				tracks[i].mode = 'disabled';
			}
		} catch (e) {}
	}
};

Player.prototype.play = function() {
	try {
		// optimistic update so UI doesn't remain in "paused" when switching sources quickly
		try { this.ui.paused = false; } catch (e) {}

		// attempt to play (may or may not return a Promise on the platform; we don't rely on it)
		try {
			this.element.dom.play();
		} catch (e_play) {
			log('play() DOM call threw', e_play);
		}

		// schedule confirmations — rely on events and state sync (_syncState)
		var self = this;
		setTimeout(function() {
			try { self._syncState(); } catch (e) {}
		}, 200);

		setTimeout(function() {
			try { self._syncState(); } catch (e) {}
		}, 800);

	} catch (e) {
		log('play() outer error', e);
		try { this._syncState(); } catch (ex) {}
	}
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
