Object {
	property real radius;			///< radius for all corners
	property real topLeft;			///< top left corner radius
	property real topRight;			///< top right corner radius
	property real bottomLeft;		///< bottom left corner radius
	property real bottomRight;		///< bottom right corner radius

	prototypeConstructor: {
		RadiusPrototype.defaultProperty = 'radius';
	}

	function _number(value) {
		var n = +value
		if (n !== n || n < 0)
			return 0
		return n
	}

	function _corner(own, fallback) {
		var n = this._number(own)
		return n > 0 ? n : fallback
	}

	_updateValue: {
		var parent = this.parent
		var fallback = this._number(this.radius)
		var tl = this._corner(this.topLeft, fallback)
		var tr = this._corner(this.topRight, fallback)
		var bl = this._corner(this.bottomLeft, fallback)
		var br = this._corner(this.bottomRight, fallback)

		if (parent.cssRoundGeometry) {
			var dpr = parent._devicePixelRatio ? parent._devicePixelRatio() : 1
			tl = Math.round(tl * dpr) / dpr
			tr = Math.round(tr * dpr) / dpr
			bl = Math.round(bl * dpr) / dpr
			br = Math.round(br * dpr) / dpr
		}
		if (tl == tr && bl == br && tl == bl)
			this.parent.style('border-radius', tl)
		else
			this.parent.style('border-radius', tl + 'px ' + tr + 'px ' + br + 'px ' + bl + 'px')
	}

	onRadiusChanged,
	onTopLeftChanged,
	onTopRightChanged,
	onBottomLeftChanged,
	onBottomRightChanged: {
		this._updateValue()
	}
}
