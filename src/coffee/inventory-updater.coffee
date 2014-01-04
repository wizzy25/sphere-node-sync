InventorySync = require('../lib/inventory-sync')
Q = require('q')

###
Inventory Updater class
###
class InventoryUpdater
  constructor: (opts = {})->
    @sync = new InventorySync opts
    @rest = @sync._rest
    @existingInventoryEntries = {}
    @sku2index = {}
    @

  createInventoryEntry: (sku, quantity, expectedDelivery, channelId) ->
    entry =
      sku: sku
      quantityOnStock: parseInt(quantity)
    entry.expectedDelivery = expectedDelivery if expectedDelivery
    if channelId
      entry.supplyChannel =
        typeId: 'channel'
        id: channelId
    entry

  ensureChannelByKey: (rest, channelKey) ->
    deferred = Q.defer()
    query = encodeURIComponent("key=\"#{channelKey}\"")
    rest.GET "/channels?where=#{query}", (error, response, body) ->
      if error
        deferred.reject 'Error on getting channel: ' + error
        return deferred.promise
      if response.statusCode is 200
        channels = JSON.parse(body).results
        if channels.length is 1
          deferred.resolve channels[0]
          return deferred.promise
      # can't find it - let's create the channel
      channel =
        key: channelKey
      rest.POST '/channels', JSON.stringify(channel), (error, response, body) ->
        if error
          deferred.reject 'Error on creating channel: ' + error
        else if response.statusCode is 201
          c = JSON.parse body
          deferred.resolve c
        else
          deferred.reject 'Problem on creating channel: ' + body
    deferred.promise


  returnResult: (positiveFeedback, msg, callback) ->
    @bar.terminate() if @bar
    retVal =
      component: this.constructor.name
      status: positiveFeedback
      message: msg
    if @log
      logLevel = if positiveFeedback then 'info' else 'err'
      @log.log logLevel, d
    callback retVal

  allInventoryEntries: (rest) ->
    deferred = Q.defer()
    rest.GET '/inventory?limit=0', (error, response, body) ->
      if error
        deferred.reject 'Error on getting all inventory entries: ' + error
      else if response.statusCode isnt 200
        deferred.reject 'Problem on getting all inventory entries: ' + body
      else
        stocks = JSON.parse(body).results
        deferred.resolve stocks
    deferred.promise

  initMatcher: () ->
    deferred = Q.defer()
    @allInventoryEntries(@rest).then (existingEntries) =>
      @existingInventoryEntries = existingEntries
      for existingEntry, i in @existingInventoryEntries
        @sku2index[existingEntry.sku] = i
      deferred.resolve true
    .fail (msg) ->
      deferred.reject msg
    deferred.promise

  match: (s) ->
    if @sku2index[s.sku] isnt -1
      @existingInventoryEntries[@sku2index[s.sku]]

  createOrUpdate: (inventoryEntries, callback) ->
    if inventoryEntries.length is 0
      return @returnResult true, 'Nothing to do.', callback
    posts = []
    for entry in inventoryEntries
      existingEntry = @match(entry)
      if existingEntry
        posts.push @update(entry, existingEntry)
      else
        posts.push @create(entry)
    Q.all(posts).then (messages) =>
      if messages.length is 1
        messages = messages[0]
      @returnResult true, messages, callback
    .fail (msg) =>
      @returnResult false, msg, callback

  update: (entry, existingEntry) ->
    deferred = Q.defer()
    @sync.buildActions(entry, existingEntry).update (error, response, body) =>
      @bar.tick() if @bar
      if error
        deferred.reject 'Error on updating inventory entry: ' + error
      else
        if response.statusCode is 200
          deferred.resolve 'Inventory entry updated.'
        else if response.statusCode is 304
          deferred.resolve 'Inventory entry update not neccessary.'
        else
          deferred.reject 'Problem on updating existing inventory entry: ' + body
    deferred.promise

  create: (stock) ->
    deferred = Q.defer()
    @rest.POST '/inventory', JSON.stringify(stock), (error, response, body) =>
      @bar.tick() if @bar
      if error
        deferred.reject 'Error on creating new inventory entry: ' + error
      else
        if response.statusCode is 201
          deferred.resolve 'New inventory entry created.'
        else
          deferred.reject 'Problem on creating new inventory entry: ' + body
    deferred.promise

###
Exports object
###
module.exports = InventoryUpdater