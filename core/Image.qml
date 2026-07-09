//item for image displaying
Item {
	property int paintedWidth;								///< actually painted image width
	property int paintedHeight;								///< actually painted image height
	property int sourceWidth; 								///< actual width of loaded image
	property int sourceHeight; 								///< actual height of loaded image
	property string source;									///< image URL
	property enum status { Null, Ready, Loading, Error };	///< image status
	property enum fillMode { Stretch, PreserveAspectFit, PreserveAspectCrop, Tile, TileVertically, TileHorizontally, Pad };	///< setup mode how image must fill it's content
	property enum verticalAlignment { AlignVCenter, AlignTop, AlignBottom };
	property enum horizontalAlignment { AlignHCenter, AlignLeft, AlignRight };
	property bool smooth: true;								///< if false, image will be pixelated
	property bool preload: false;							///< image will be loaded even if it's not visible
	property bool useOptimizedDomImage: false;				///< if true tries to render with <img>, falls back to background-image when unsupported

	width: sourceWidth;
	height: sourceHeight;

	///@private
	constructor: {
		this._context.backend.initImage(this)
		this._scheduleLoad()
	}

	function getClass() { return 'core-image' }

	///@private
	function _scheduleLoad() {
		if (this.preload || this.recursiveVisible)
			this._context.delayedAction('image.load', this, this._load)
	}

	///@private
	function _onError() {
		this.status = this.Error;
	}

	///@private
	function _load() {
		if (this.status === this.Ready) {
			this._updatePaintedSize()
			return
		}

		if (!this.preload && !this.recursiveVisible)
			return

		if (!this.source) {
			this._resetImage()
			return
		}

		this.status = this.Loading
		var ctx = this._context
		var callback = this._imageLoaded.bind(this)
		ctx.backend.loadImage(this, ctx.wrapNativeCallback(callback))
	}

	onPreloadChanged,
	onRecursiveVisibleChanged,
	onWidthChanged,
	onHeightChanged,
	onFillModeChanged: {
		if (this.status === ImageComponent.Ready) {
			this._applyReadyStyle({ width: this.sourceWidth, height: this.sourceHeight })
			this._updatePaintedSize()
			return
		}
		this._scheduleLoad()
	}

	onSourceChanged: {
		this.status = this.Null
		this._scheduleLoad()
	}

	///@private
	function _resetImage() {
		this.style('background-image', '')
		this._setDomImageSource('')
	}

	///@private
	function _setDomImageSource(source) {
		var element = this._domImageElement
		if (!element)
			return
		element.setAttribute('src', source || '')
	}

	///@private
	function _ensureDomImageElement() {
		if (this._domImageElement)
			return true
		if (!this.element || !this.element.dom || typeof document === 'undefined' || !document.createElement)
			return false

		var domImage = document.createElement('img')
		var imageElement = this._context.createElement(domImage)
		this.element.append(imageElement)
		this._domImageElement = imageElement
		return true
	}

	///@private
	function _setDomImageVisible(value) {
		var element = this._domImageElement
		if (!element)
			return
		element.style({
			'display': value ? 'block' : 'none'
		})
	}

	///@private
	function _isOptimizedFillMode() {
		switch(this.fillMode) {
			case ImageComponent.Stretch:
				return true
			default:
				return false
		}
	}

	///@private
	function _shouldUseDomImage() {
		if (!this.useOptimizedDomImage || !this._isOptimizedFillMode())
			return false;
		// ImageMixin paints into parent element, so keep background-image there
		if (this.parent && this.element === this.parent.element)
			return false
		return this._ensureDomImageElement()
	}

	///@private
	function _objectPosition() {
		var x = '50%'
		var y = '50%'

		switch(this.horizontalAlignment) {
			case ImageComponent.AlignLeft:
				x = '0%'
				break
			case ImageComponent.AlignRight:
				x = '100%'
				break
		}

		switch(this.verticalAlignment) {
			case ImageComponent.AlignTop:
				y = '0%'
				break
			case ImageComponent.AlignBottom:
				y = '100%'
				break
		}

		return x + ' ' + y
	}

	///@private
	function _objectFit() {
		switch(this.fillMode) {
			case ImageComponent.Stretch:
			default:
				return 'fill'
		}
	}

	///@private
	function _applyDomImageStyle() {
		var element = this._domImageElement
		if (!element)
			return

		element.style({
			'position': 'absolute',
			'left': 0,
			'top': 0,
			'width': '100%',
			'height': '100%',
			'border': 0,
			'padding': 0,
			'margin': 0,
			'pointer-events': 'none',
			'object-fit': this._objectFit(),
			'object-position': this._objectPosition(),
			'image-rendering': this.smooth? 'auto': 'pixelated'
		})
	}

	///@private
	function _applyBackgroundImageStyle(metrics) {
		var style = { 'background-image': 'url("' + this.source + '")' }
		var natW = metrics.width, natH = metrics.height

		switch(this.horizontalAlignment) {
			case ImageComponent.AlignHCenter:
				style['background-position-x'] = 'center'
				break;
			case ImageComponent.AlignLeft:
				style['background-position-x'] = 'left'
				break;
			case ImageComponent.AlignRight:
				style['background-position-x'] = 'right'
				break;
		}

		switch(this.verticalAlignment) {
			case ImageComponent.AlignVCenter:
				style['background-position-y'] = 'center'
				break;
			case ImageComponent.AlignTop:
				style['background-position-y'] = 'top'
				break;
			case ImageComponent.AlignBottom:
				style['background-position-y'] = 'bottom'
				break;
		}

		switch(this.fillMode) {
			case ImageComponent.Stretch:
				style['background-repeat'] = 'no-repeat'
				style['background-size'] = '100% 100%'
				break;
			case ImageComponent.TileVertically:
				style['background-repeat'] = 'repeat-y'
				style['background-size'] = '100% ' + natH + 'px'
				break;
			case ImageComponent.TileHorizontally:
				style['background-repeat'] = 'repeat-x'
				style['background-size'] = natW + 'px 100%'
				break;
			case ImageComponent.Tile:
				style['background-repeat'] = 'repeat'
				style['background-size'] = 'auto'
				break;
			case ImageComponent.PreserveAspectCrop:
				style['background-repeat'] = 'no-repeat'
				style['background-size'] = 'cover'
				break;
			case ImageComponent.Pad:
				style['background-repeat'] = 'no-repeat'
				style['background-position'] = '0% 0%'
				style['background-size'] = 'auto'
				break;
			case ImageComponent.PreserveAspectFit:
				style['background-repeat'] = 'no-repeat'
				style['background-size'] = 'contain'
				break;
		}
		style['image-rendering'] = this.smooth? 'auto': 'pixelated'
		this.style(style)
	}

	///@private
	function _applyReadyStyle(metrics) {
		if (this._shouldUseDomImage()) {
			this._setDomImageVisible(true)
			this._applyDomImageStyle()
			this._setDomImageSource(this.source)
			this.style('background-image', '')
			return
		}

		this._setDomImageVisible(false)
		this._setDomImageSource('')
		this._applyBackgroundImageStyle(metrics)
	}

	function _updatePaintedSize() {
		var natW = this.sourceWidth, natH = this.sourceHeight
		var w = this.width, h = this.height

		if (natW <= 0 || natH <= 0 || w <= 0 || h <= 0) {
			this.paintedWidth = 0
			this.paintedHeight = 0
			return
		}

		var crop
		switch(this.fillMode) {
			case ImageComponent.PreserveAspectFit:
				crop = false
				break
			case ImageComponent.PreserveAspectCrop:
				crop = true
				break
			default:
				this.paintedWidth = w
				this.paintedHeight = h
				return
		}

		var targetRatio = w / h, srcRatio = natW / natH

		var useWidth = crop? srcRatio < targetRatio: srcRatio > targetRatio
		if (useWidth) { // img width aligned with target width
			this.paintedWidth = w;
			this.paintedHeight = w / srcRatio;
		} else {
			this.paintedHeight = h;
			this.paintedWidth = h * srcRatio;
		}
	}

	///@private
	function _imageLoaded(metrics) {
		if (!metrics) {
			this.status = ImageComponent.Error
			return
		}

		var natW = metrics.width, natH = metrics.height
		this.sourceWidth = natW
		this.sourceHeight = natH
		this._applyReadyStyle(metrics)

		this.status = ImageComponent.Ready
		this._updatePaintedSize()
	}

	onHorizontalAlignmentChanged,
	onVerticalAlignmentChanged,
	onSmoothChanged,
	onUseOptimizedDomImageChanged: {
		if (this.status === ImageComponent.Ready) {
			this._applyReadyStyle({ width: this.sourceWidth, height: this.sourceHeight })
			this._updatePaintedSize()
		}
	}
}
