_ = require('underscore')._
{Rest} = require 'sphere-node-connect'
Sync = require '../sync/sync'
ProductUtils = require '../utils/product-utils'

###
Product Sync class
###
class ProductSync extends Sync
  constructor: (opts = {}) ->
    super(opts)
    # Override base utils
    @_utils = new ProductUtils

  buildActions: (new_obj, old_obj, sameForAllAttributeNames = []) ->
    @sameForAllAttributeNames = sameForAllAttributeNames
    super new_obj, old_obj

  _doMapActions: (diff, new_obj, old_obj) ->
    actions = @_utils.actionsMap(diff, old_obj)
    actionsVariants = @_utils.actionsMapVariants(diff, old_obj, new_obj)
    actionsReferences = @_utils.actionsMapReferences(diff, old_obj, new_obj)
    actionsPrices = @_utils.actionsMapPrices(diff, old_obj, new_obj)
    actionsAttributes = @_utils.actionsMapAttributes(diff, new_obj, @sameForAllAttributeNames)
    actionsImages = @_utils.actionsMapImages(diff, old_obj, new_obj)
    actions = _.union actions, actionsVariants, actionsReferences, actionsPrices, actionsAttributes, actionsImages
    actions

  _doUpdate: (callback) ->
    payload = JSON.stringify @_data.update
    @_rest.POST "/products/#{@_data.updateId}", payload, callback


###
Exports object
###
module.exports = ProductSync
