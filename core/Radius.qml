Object {
	property real radius;			///< radius for all corners
	property real topLeft;			///< top left corner radius
	property real topRight;			///< top right corner radius
	property real bottomLeft;		///< bottom left corner radius
	property real bottomRight;		///< bottom right corner radius

	prototypeConstructor: {
		RadiusPrototype.defaultProperty = 'radius';
	}

	_updateValue: {
		var parent = this.parent
		var radius = this.radius
		var tl = this.topLeft || radius
		var tr = this.topRight || radius
		var bl = this.bottomLeft || radius
		var br = this.bottomRight || radius
		if (parent && parent.cssRoundGeometry) {
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
