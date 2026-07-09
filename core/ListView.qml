///single direction (vertical or horizontal) oriented view
BaseView {
	property enum orientation { Vertical, Horizontal };	///< orientation direction
	property int overflowLeft: 0;
	property bool useNativeList: false;					///< use Android RecyclerView renderer (channel-style rows)
	property int nativeItemHeight: 0;					///< row height in pixels, 0 = delegate.height
	signal itemActivated;

	constructor: {
		this._sizes = []
		this._scrollDelta = 0
		this._syncingNativeIndex = false
		this._nativeListReady = false
		this._nativeSyncedCount = -1
	}

	function getTag() {
		if (this.useNativeList && this._nativeListAvailable())
			return 'native-list'
		return 'div'
	}

	function _nativeListAvailable() {
		var ctx = this._context
		if (!ctx || !ctx.system || !ctx.system.os)
			return false
		if (this.orientation !== this.Vertical)
			return false
		return ctx.system.os.toLowerCase() === 'android'
	}

	function _nativeListActive() {
		return this.useNativeList && this._nativeListAvailable() && this.element && this.element.setItems
	}

	function _ensureNativeElement() {
		if (!this.useNativeList || !this._nativeListAvailable())
			return false
		if (this.element && this.element.setItems)
			return true
		this._nativeListReady = false
		this._createElement('native-list', this.getClass())
		return this.element && this.element.setItems
	}

	function _scheduleLayout(skipPositioning) {
		if (!this.recursiveVisible && !this.offlineLayout && !(this.useNativeList && this._nativeListAvailable()))
			return
		$core.BaseLayout.prototype._scheduleLayout.call(this, skipPositioning)
	}

	function _setupNativeList() {
		if (this._nativeListReady || !this._ensureNativeElement())
			return
		this._nativeListReady = true
		this.content.visible = false
		var self = this
		this.element.on('currentIndexChanged', function(index) {
			if (self._syncingNativeIndex)
				return
			self._syncingNativeIndex = true
			self.currentIndex = index
			self._syncingNativeIndex = false
		})
		this.element.on('activated', function(index) {
			if (self._syncingNativeIndex)
				return
			self._syncingNativeIndex = true
			self.currentIndex = index
			self._syncingNativeIndex = false
			self.itemActivated(index)
		})
		if (this.element.setSelectionFocused)
			this.element.setSelectionFocused(this.activeFocus)
	}

	function _syncNativeListMetrics() {
		var model = this._modelAttached
		if (!model || !this._ensureNativeElement())
			return

		this.element.setItemHeight(this._nativeItemHeight())
		this.element.setItemSpacing(this.spacing || 0)

		this.count = model.count
		var itemHeight = this._nativeItemHeight()
		var spacing = this.spacing || 0
		var total = model.count > 0? model.count * itemHeight + (model.count - 1) * spacing: 0
		this.contentHeight = total
		this.contentWidth = this.width

		if (this.width > 0)
			this.style({ width: this.width })
	}

	function _processUpdates() {
		if (this._nativeListActive()) {
			this._processNativeModelUpdates()
			return
		}
		$core.BaseView.prototype._processUpdates.call(this)
	}

	function _processNativeModelUpdates() {
		var model = this._modelAttached
		if (!model || !this._ensureNativeElement())
			return

		var rows = this._modelUpdate.rows
		if (!rows || rows.length === 0)
			return

		this._setupNativeList()
		this._syncNativeListMetrics()

		if (this._nativeSyncedCount !== model.count)
			return

		var changed = []
		for (var i = 0; i < rows.length; ++i) {
			if (rows[i][1])
				changed.push(i)
			rows[i][0] = i
			rows[i][1] = false
		}
		if (changed.length === 0)
			return

		if (changed.length === rows.length && this.element.refreshContent)
			this.element.refreshContent(model._rows)
		else if (this.element.updateRow) {
			for (var j = 0; j < changed.length; ++j)
				this.element.updateRow(changed[j], model.get(changed[j]))
		}
	}

	function _nativeItemHeight() {
		if (this.nativeItemHeight > 0)
			return this.nativeItemHeight
		if (this.delegate && this.delegate.height > 0)
			return this.delegate.height
		return 143
	}

	function _syncNativeList() {
		var model = this._modelAttached
		if (!model || !this._ensureNativeElement())
			return

		this._setupNativeList()
		this._syncNativeListMetrics()

		var rows = model._rows
		if (!rows || rows.length !== model.count) {
			rows = []
			for (var i = 0; i < model.count; ++i)
				rows.push(model.get(i))
		}
		this.element.setItems(rows)

		if (this.currentIndex >= 0 && !this._syncingNativeIndex) {
			this._syncingNativeIndex = true
			this.element.setCurrentIndex(this.currentIndex)
			this._syncingNativeIndex = false
		}
	}

	function _layoutNativeList() {
		var model = this._modelAttached
		if (!model) {
			this.layoutFinished()
			return
		}
		if (this._nativeSyncedCount !== model.count) {
			this._syncNativeList()
			this._nativeSyncedCount = model.count
			var rows = this._modelUpdate.rows
			if (rows) {
				for (var i = 0; i < rows.length; ++i) {
					rows[i][0] = i
					rows[i][1] = false
				}
			}
		} else {
			this._setupNativeList()
			this._syncNativeListMetrics()
			if (this.currentIndex >= 0 && !this._syncingNativeIndex) {
				this._syncingNativeIndex = true
				this.element.setCurrentIndex(this.currentIndex)
				this._syncingNativeIndex = false
			}
		}
		if (this.syncNativePosition)
			this.syncNativePosition()
		this.layoutFinished()
	}

	function focusCurrent() {
		if (this.useNativeList && this._nativeListAvailable() && this._ensureNativeElement()) {
			var model = this._modelAttached
			var n = model? model.count: 0
			if (n === 0)
				return

			var idx = this.currentIndex
			if (idx < 0 || idx >= n) {
				if (this.keyNavigationWraps)
					this.currentIndex = (idx + n) % n
				else
					this.currentIndex = idx < 0? 0: n - 1
				return
			}
			if (!this._syncingNativeIndex) {
				this._syncingNativeIndex = true
				this.element.setCurrentIndex(this.currentIndex)
				this._syncingNativeIndex = false
			}
			return
		}
		$core.BaseView.prototype.focusCurrent.apply(this, arguments)
	}

	///@private
	function move(dx, dy) {
		var horizontal = this.orientation === this.Horizontal
		var x, y
		if (horizontal && this.contentWidth > this.width) {
			x = this.contentX + dx
			if (x < 0)
				x = 0
			else if (x > this.contentWidth - this.width)
				x = this.contentWidth - this.width
			this.contentX = x
		} else if (!horizontal && this.contentHeight > this.height) {
			y = this.contentY + dy
			if (y < 0)
				y = 0
			else if (y > this.contentHeight - this.height)
				y = this.contentHeight - this.height
			this.contentY = y
		}
	}

	function positionViewAtIndex(idx) {
		if (this.trace)
			log('positionViewAtIndex ' + idx)

		var horizontal = this.orientation === this.Horizontal
		var itemBox = this.getItemPosition(idx)
		var center = this.positionMode === this.Center

		if (horizontal) {
			this.positionViewAtItemHorizontally(itemBox, center, true)
		} else {
			this.positionViewAtItemVertically(itemBox, center, true)
		}
	}

	function positionViewAtEnd() {
		if (this.orientation === this.Horizontal)
			this.positionViewAtEndHorizontally()
		else
			this.positionViewAtEndVertically()
	}

	///@private
	onKeyPressed: {
		if (!this.handleNavigationKeys) {
			return false;
		}

		var horizontal = this.orientation === this.Horizontal
		if (horizontal) {
			if (key === 'Left') {
				return this.moveCurrentIndex(-1);
			} else if (key === 'Right') {
				return this.moveCurrentIndex(1);
			}
		} else {
			if (key === 'Up') {
				return this.moveCurrentIndex(-1);
			} else if (key === 'Down') {
				return this.moveCurrentIndex(1);
			}
		}
	}

	///@private
	function getItemPosition(idx) {
		var items = this._items
		var item = items[idx]
		var sizes = this._sizes
		var horizontal = this.orientation === this.Horizontal
		var spacing = this.spacing

		if (!item) {
			var refSize
			var x = 0, y = 0, w = 0, h = 0
			for(var i = 0; i < idx; ++i)
			{
				if (!item)
					item = items[i]

				if (item) {
					w = item.width
					h = item.height
				}
				var s = sizes[i]
				if (refSize === undefined || s > 0)
					refSize = s
				if (s === undefined)
					s = refSize
				if (s === undefined)
					 s = 0

				if (horizontal) {
					if (s > 0)
						x += s + spacing
				} else {
					if (s > 0)
						y += s + spacing
				}
			}
			return [x, y, w, h]
		}
		else
			return [item.viewX + item.x, item.viewY + item.y, item.width, item.height]
	}

	///@private
	function indexAt(x, y) {
		var items = this._items
		x += this.contentX
		y += this.contentY
		if (this.orientation === ListView.Horizontal) {
			for (var i = 0; i < items.length; ++i) {
				var item = items[i]
				if (!item)
					continue
				var vx = item.viewX
				if (x >= vx && x < vx + item.width)
					return i
			}
		} else {
			for (var i = 0; i < items.length; ++i) {
				var item = items[i]
				if (!item)
					continue
				var vy = item.viewY
				if (y >= vy && y < vy + item.height)
					return i
			}
		}
		return -1
	}

	///@private
	function _layout(noPrerender) {
		if (this.useNativeList && this._nativeListAvailable()) {
			this._layoutNativeList()
			return
		}

		var model = this._modelAttached
		if (!model) {
			this.layoutFinished()
			return
		}

		this.count = model.count

		if (!this.recursiveVisible && !this.offlineLayout) {
			this.layoutFinished()
			return
		}

		var visibilityProperty = this.visibilityProperty
		var horizontal = this.orientation === this.Horizontal

		var padding = this._padding
		var paddingLeft = padding.left || 0, paddingTop = padding.top || 0
		var items = this._items
		var sizes = this._sizes
		var n = items.length
		var w = this.width - paddingLeft - (padding.right || 0), h = this.height - paddingTop - (padding.bottom || 0)
		var created = false
		var startPos = horizontal? paddingLeft: paddingTop
		var p = startPos
		var c = horizontal? this.content.x: this.content.y
		var size = horizontal? w: h
		var maxW = 0, maxH = 0

		var currentIndex = this.currentIndex
		var discardDelegates = !noPrerender
		var prerender = noPrerender? 0: this.prerender * size
		var leftMargin = -prerender
		var rightMargin = size + prerender

		if (sizes.length > items.length) {
			///fixme: override model update api to make sizes stable
			sizes.splice(items.length, sizes.length - items.length)
		}

		if (this._scrollDelta != 0) {
			if (this.nativeScrolling) {
				if (horizontal)
					this.element.setScrollX(this.element.getScrollX() - this._scrollDelta)
				else
					this.element.setScrollY(this.element.getScrollY() - this._scrollDelta)
			}
			this._scrollDelta = 0
		}

		if (this.trace)
			log("layout " + n + " into " + w + "x" + h + " @ " + this.content.x + "," + this.content.y + ", prerender: " + prerender + ", range: " + leftMargin + ":" + rightMargin)

		var refSize
		for(var i = 0; i < n; ++i) {
			var item = items[i]
			var viewPos = p + c
			var s

			if (item) {
				s = sizes[i] = (horizontal? item.width: item.height)
				if (refSize === undefined || s > 0)
					refSize = s
			} else {
				s = sizes[i]
				if (s !== undefined) {
					if (refSize === undefined)
						refSize = s
				} else
					s = refSize
			}

			var renderable = viewPos + (s !== undefined? s: 0) >= leftMargin && viewPos < rightMargin

			var visibleInModel = true
			if (visibilityProperty) {
				visibleInModel = model.getProperty(i, visibilityProperty)
				if (!visibleInModel) {
					renderable = false
					s = sizes[i] = 0
				}
			}

			if (!item && visibleInModel && (renderable || s === undefined)) {
				item = this._createDelegate(i)
				if (item) {
					s = sizes[i] = (horizontal? item.width: item.height)
					if (refSize === undefined || s > 0)
						refSize = s
					created = true
				}
			}

			if (item) {
				var visible = visibleInModel &&
					(viewPos + s >= -this.overflowLeft &&
					 viewPos < size);

				if (item.x + item.width > maxW)
					maxW = item.width + item.x
				if (item.y + item.height > maxH)
					maxH = item.height + item.y

				if (horizontal)
					item.viewX = p
				else
					item.viewY = p

				if (currentIndex === i && !item.focused) {
					this.focusChild(item)
				}

				item.visibleInView = visible

				if (!renderable && discardDelegates) {
					if (items[i]) {
						if (this.trace)
							log('discarding delegate', i)
						this._discardItem(item)
						items[i] = null
						created = true
					}
				}
			} else {
				var nextP = p + s
				if (horizontal) {
					if (nextP > maxW)
						maxW = nextP
				} else {
					if (nextP > maxH)
						maxH = nextP
				}
			}

			if (s > 0)
				p += s + this.spacing
		}
		if (p > startPos)
			p -= this.spacing;

		if (this.trace)
			log('result: ' + p + ', max: ' + maxW + 'x' + maxH)
		if (horizontal) {
			this.content.width = p
			this.content.height = maxH
			this.contentWidth = p
			this.contentHeight = maxH
		} else {
			this.content.width = maxW
			this.content.height = p
			this.contentWidth = maxW
			this.contentHeight = p
		}
		if (this.positionMode == this.End && !this._skipPositioning) {
			this.positionViewAtEnd()
		}
		this.layoutFinished()
		if (created)
			this._context.scheduleComplete()
	}

	/// @private creates delegate in given item slot
	function _createDelegate(idx) {
		var item = $core.BaseView.prototype._createDelegate.apply(this, arguments)
		if (!item)
			return item
		//connect both dimensions, because we calculate maxWidth/maxHeight in contentWidth/contentHeight
		var update = function(horizontal) {
			this._scheduleLayout()
			var viewHorizontal = this.orientation === this.Horizontal
			if (this.nativeScrolling && viewHorizontal == horizontal) {
				//if delegate updates its width and it's on the left/top of scrolling position
				//it will cause annoying jumps
				var itemPos = viewHorizontal? item.viewX: item.viewY
				var itemSize = viewHorizontal? item.width: item.height
				var scrollPos = viewHorizontal? this.element.getScrollX(): this.element.getScrollY()
				if (itemPos < scrollPos) {
					this._scrollDelta += itemSize - this._sizes[idx]
				}
			}
		}
		item.onChanged('width', update.bind(this, true), true) //skip initial update
		item.onChanged('height', update.bind(this, false), true) //skip initial update
		return item
	}

	///@private
	function _updateOverflow() {
		if (!this.nativeScrolling) {
			$core.Item.prototype._updateOverflow.apply(this, arguments)
			return
		}
		var horizontal = this.orientation === this.Horizontal
		var style = {}
		if (horizontal) {
			style['overflow-x'] = 'auto'
			style['overflow-y'] = 'hidden'
		} else {
			style['overflow-x'] = 'hidden'
			style['overflow-y'] = 'auto'
		}
		this.style(style)
	}

	onOrientationChanged: {
		this._updateOverflow()
		this._scheduleLayout()
		this._sizes = []
	}

	onNativeScrollingChanged: {
		this._updateOverflow()
	}

	onCompleted: {
		this._updateOverflow()
		if (this.useNativeList && this._nativeListAvailable()) {
			this.offlineLayout = true
			this._ensureNativeElement()
			this._scheduleLayout()
		}
	}

	onUseNativeListChanged: {
		if (value && this._nativeListAvailable()) {
			this.offlineLayout = true
			this._nativeSyncedCount = -1
			this._ensureNativeElement()
			this._scheduleLayout()
		}
	}

	onActiveFocusChanged: {
		if (this._nativeListActive() && this.element.setSelectionFocused)
			this.element.setSelectionFocused(this.activeFocus)
	}
}
