
Constants = require 'Constants'
Dispatcher = require('Util').Dispatcher
SubredditPlaylist = require 'collections/SubredditPlaylist'
Store = require 'Store'



Reddit = Backbone.Model.extend
	defaults:
		sortMethod: 'hot'
		topMethod: 'month'

	vote: (id, dir) ->
		data =
			id: id
			dir: dir
		$.ajax
			type: 'POST'
			dataType: 'json'
			url: '/api/vote'
			data: data
			success: (resp) ->
				console.log resp if FLAG_DEBUG

	subreddits: () ->
		if SubredditPlaylist.length is 0
			return 'listentothis'
		else
			return SubredditPlaylist.toString()

	getMusic: (callback, after, limit) ->
		data = {}
		data.sort = @get('sortMethod')
		data.t = @get('topMethod') if @get('sortMethod') is 'top'
		data.after = after if after?
		data.limit = limit or 100

		if Store.search?
			return @getSearch callback, data

		if Store.multi?
			return @getMulti callback, data

		subs = @subreddits()
		if subs is null
			return
		console.log 'Reddit :: GetMusic :: ', subs if FLAG_DEBUG

		if Store.firstRequest
			$.ajax
				dataType: 'json'
				url: "/api/get/r/#{subs}/#{@get('sortMethod')}.json?jsonp=?"
				data: data
				success: (r) ->
					throw new Error "Reddit :: #{r.error.type} :: #{r.error.message}" if r.error?
					callback r.data.children
			Store.firstRequest = false
		else
			$.ajax
				dataType: 'json'
				url: "#{API.Reddit.base}/r/#{subs}/#{@get('sortMethod')}.json?jsonp=?"
				data: data
				success: (r) ->
					throw new Error "Reddit :: #{r.error.type} :: #{r.error.message}" if r.error?
					console.log 'Reddit :: Music Received :: ', r.data.children.length if FLAG_DEBUG
					callback r.data.children
				error: (xhr, status, err) ->
					console.error "Reddit :: #{status} :: #{err}", arguments
					Dispatcher.trigger Constants.MESSAGE, new MessageFailedToGetMusic()

	getSearch: (callback, data) ->
		@set 'search', Store.search
		console.log 'Reddit :: GetSearch ::', @get('search') if FLAG_DEBUG
		$.ajax
			dataType: 'json'
			url: "#{API.Reddit.base}/search.json?q=#{@get('search')}&jsonp=?"
			data: data
			success: (r) ->
				throw console.error "Reddit :: #{r.error.type} :: #{r.error.message}" if r.error?
				callback r.data.children

	getMulti: (callback, data) ->
		if not @has('multi')
			@set 'multi', Store.multi
		console.log 'Reddit :: GetMulti ::', @get('multi') if FLAG_DEBUG
		$.ajax
			dataType: 'json'
			url: "#{API.Reddit.base}/user/#{@get('multi')}/#{@get('sortMethod')}.json?jsonp=?"
			data: data
			success: (r) ->
				throw new Error "Reddit :: #{r.error.type} :: #{r.error.message}" if r.error?
				callback r.data.children

	getMore: (last, callback) ->
		@getMusic callback, last, 20

	getComments: (permalink, callback) ->
		data = {}
		data.sort = @get('sortMethod')
		data.t = @get('topMethod') if @get('sortMethod') is 'top'
		url = "#{API.Reddit.base}#{permalink}.json?jsonp=?"
		url = '/api/comments' if Store.authentication?
		data.permalink = permalink if Store.authentication?
		$.ajax
			dataType: 'json'
			url: url
			data: data
			success: (r) ->
				throw new Error "Reddit :: #{r.error.type} :: #{r.error.message}" if r.error?
				callback r[1].data.children

	addComment: (params) ->
		data =
			text: params.text
			thing_id: params.thing_id
		$.ajax
			type: 'POST'
			dataType: 'json'
			url: '/api/add_comment'
			data: data
			success: (r) ->
				throw new Error "Reddit :: #{r.error.type} :: #{r.error.message}" if r.error?
				params.callback(r)

	changeSortMethod: (sortMethod, topMethod) ->
		@set 'sortMethod', sortMethod
		@set 'topMethod', topMethod

	save: () ->
		try
			localStorage['sortMethod'] = @get 'sortMethod'
			localStorage['topMethod'] = @get 'topMethod'
		catch e
			console.error e

	initialize: () ->
		@set 'sortMethod', localStorage['sortMethod'] if localStorage['sortMethod']?
		@set 'topMethod', localStorage['topMethod'] if localStorage['topMethod']?
		if (not (@get('sortMethod') is 'top' or @get('sortMethod') is 'hot' or @get('sortMethod') is 'new'))
			@changeSortMethod('hot', 'week')
			@save()
		@listenTo @, 'change', @save



module.exports = new Reddit()
