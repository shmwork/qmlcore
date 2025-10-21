///object for handling XML/HTTP requests
Object {
	property bool loading: false;	///< loading flag, is true when request was send and false when answer was recieved or error occured
	property int timeout: 10000;	///< default timeout in ms

	/**@param request:Object request object
	send request using 'XMLHttpRequest' object*/
	function ajax(request) {
		var self = this;

		// keep original callbacks
		var origDone = request.done;
		var origError = request.error;

		if (origDone)
			origDone = this._context.wrapNativeCallback(origDone);
		if (origError)
			origError = this._context.wrapNativeCallback(origError);

		// resolve timeout: request.timeout overrides Request.timeout
		var timeout = (typeof request.timeout !== 'undefined') ? request.timeout : this.timeout;
		var timedOut = false;
		var timer = null;

		// set loading flag
		this.loading = true;

		// timeout handler
		if (timeout && timeout > 0) {
			timer = setTimeout(function() {
				timedOut = true;
				self.loading = false;
				// call error callback (if provided) with a synthetic timeout response
				if (origError) {
					try {
						origError({
							type: "timeout",
							message: "request timeout",
							timeout: timeout,
							target: { status: 0, response: "" }
						});
					} catch (e) {
						console.log("Error in timeout error-callback:", e);
					}
				}
			}, timeout);
		}

		// wrap done/error so we ignore late calls after timeout and clear timer
		request.done = function(res) {
			if (timedOut)
				return;
			if (timer) {
				clearTimeout(timer);
				timer = null;
			}
			self.loading = false;
			if (origDone) {
				try { origDone(res); } catch (e) { console.log("Error in done callback:", e); }
			}
		};

		request.error = function(res) {
			if (timedOut)
				return;
			if (timer) {
				clearTimeout(timer);
				timer = null;
			}
			self.loading = false;
			if (origError) {
				try { origError(res); } catch (e) { console.log("Error in error callback:", e); }
			}
		};

		// keep passing along the timeout field so backend.ajax may also use it (optional)
		this._context.backend.ajax(this, request);
	}
 }
