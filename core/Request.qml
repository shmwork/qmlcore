///object for handling XML/HTTP requests
Object {
	property bool loading: false;	///< loading flag, is true when request was send and false when answer was recieved or error occured
	property int timeout: 59000;	///< default timeout in ms

	/**@param request:Object request object
	send request using 'XMLHttpRequest' object
	@returns handle with cancel() — cancelled requests do not invoke done/error */
	function ajax(request) {
		var self = this;

		var origDone = request.done;
		var origError = request.error;

		if (origDone)
			origDone = self._context.wrapNativeCallback(origDone);
		if (origError)
			origError = self._context.wrapNativeCallback(origError);

		var timeout = (typeof request.timeout !== 'undefined') ? request.timeout : self.timeout;
		var closed = false;
		var timer = null;
		var xhr = null;
		var handle = null;

		function close() {
			if (closed)
				return false;
			closed = true;
			if (timer) {
				clearTimeout(timer);
				timer = null;
			}
			self.loading = false;
			var xhrs = self._activeXhrs;
			if (xhrs && handle) {
				var idx = xhrs.indexOf(handle);
				if (idx >= 0)
					xhrs.splice(idx, 1);
			}
			return true;
		}

		self.loading = true;

		if (timeout && timeout > 0) {
			timer = setTimeout(function() {
				if (!close())
					return;
				try { if (xhr && xhr.abort) xhr.abort(); } catch (e) {}
				if (origError) {
					try {
						origError({
							type: "timeout",
							message: "request timeout",
							timeout: timeout,
							target: { status: 504, response: "" }
						});
					} catch (e) {
						console.log("Error in timeout error-callback:", e);
					}
				}
			}, timeout);
		}

		request.done = function(res) {
			if (!close())
				return;
			if (origDone) {
				try {
					origDone(res);
				} catch (e) {
					log("Error in done callback:", e);
				}
			}
		};

		request.error = function(res) {
			if (!close())
				return;
			if (origError) {
				try {
					origError(res)
				} catch (e) {
					log("Error in error callback:", e)
				}
			}
		};

		xhr = self._context.backend.ajax(self, request);

		handle = {
			cancel: function() {
				if (!close())
					return;
				try { if (xhr && xhr.abort) xhr.abort(); } catch (e) {}
			}
		};

		(self._activeXhrs || (self._activeXhrs = [])).push(handle);
		return handle;
	}

	/**cancel all in-flight requests created by this Request instance*/
	function abortAll() {
		var xhrs = this._activeXhrs
		if (!xhrs) return
		this._activeXhrs = []
		for (var i = 0; i < xhrs.length; i++) {
			try { xhrs[i].cancel() } catch (e) {}
		}
	}
}
