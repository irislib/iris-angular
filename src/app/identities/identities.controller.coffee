'use strict'
# Identities controller
angular.module('identifiAngular').controller 'IdentitiesController', [
  '$scope'
  '$state'
  '$rootScope'
  '$window'
  '$stateParams'
  '$location'
  '$http'
  # 'Authentication'
  'Identities'
  'config'
  ($scope, $state, $rootScope, $window, $stateParams, $location, $http, Identities, config) -> #, Authentication
    $scope.activeTab = 0
    $scope.activateTab = (tabId) -> $scope.activeTab = tabId
    $scope.info = {}
    $scope.stats = {}
    $scope.sent = []
    $scope.received = []
    $scope.thumbsUp = []
    $scope.thumbsDown = []
    $scope.distance = null
    $scope.query.term = $stateParams.search if $stateParams.search
    $scope.newAttribute =
      type: ''
      value: $stateParams.value
    angular.extend $scope.filters,
      receivedOffset: 0
      sentOffset: 0
      offset: 0
      type: null

    $scope.collapseLevel = {}
    $scope.collapseFilters = $window.innerWidth < 992
    $scope.slider =
      value: 0
      options:
        floor: -3
        ceil: 3
        hidePointerLabels: true
        hideLimitLabels: true

    messagesAdded = false
    $scope.$on 'MessageAdded', (event, args) ->
      return unless $state.is 'identities.show'
      if args.message.signedData.type == 'verify_identity' and not args.id.confirmed
        args.id.confirmed = true
        args.id.confirmations += 1
        if $scope.connections && $scope.connections.indexOf(args.id) == -1
          $scope.connections.push args.id
      else if args.message.signedData.type == 'unverify_identity' and not args.id.refuted
        args.id.refuted = true
        args.id.refutations += 1
        if $scope.connections.indexOf(args.id) == -1
          $scope.connections.push args.id
      else if args.message.signedData.type == 'rating'
        if messagesAdded
          $scope.received.shift()
        $scope.processMessages [args.message]
        $scope.received.unshift args.message
        messagesAdded = true

    $scope.addEntry = (event, entry) ->
      recipient = []
      if entry.name
        recipient.push ['name', entry.name]
      if entry.email
        recipient.push ['email', entry.email]
      if entry.url
        recipient.push ['url', entry.url]
      if entry.phone
        recipient.push ['phone', entry.phone]
      params =
        type: 'verify_identity'
        recipient: recipient
      $scope.create(event, params).then (success) ->
        $state.go 'messages.show', { id: success.data.hash }
      , (error) ->
        console.log "error", error

    $scope.getConnections = ->
      $scope.connections = Identities.connections({
        idType: $scope.idType
        idValue: $scope.idValue
      }, ->
        mostConfirmations = if $scope.connections.length > 0 then $scope.connections[0].confirmations else 1
        $scope.connections.unshift
          name: $scope.idType
          value: $scope.idValue
          confirmations: 1
          refutations: 0
          isCurrent: true
        for key of $scope.connections
          conn = $scope.connections[key]
          switch conn.name
            when 'email'
              conn.iconStyle = 'glyphicon glyphicon-envelope'
              conn.btnStyle = 'btn-success'
              conn.link = 'mailto:' + conn.value
              conn.quickContact = true
              $scope.info.email = $scope.info.email or conn.value
            when 'bitcoin_address', 'bitcoin'
              conn.iconStyle = 'fa fa-bitcoin'
              conn.btnStyle = 'btn-primary'
              conn.link = 'https://blockchain.info/address/' + conn.value
              conn.quickContact = true
            when 'gpg_fingerprint', 'gpg_keyid'
              conn.iconStyle = 'fa fa-key'
              conn.btnStyle = 'btn-default'
              conn.link = 'https://pgp.mit.edu/pks/lookup?op=get&search=0x' + conn.value
            when 'account'
              conn.iconStyle = 'fa fa-at'
            when 'nickname'
              $scope.info.nickname = $scope.info.nickname or conn.value
              conn.iconStyle = 'glyphicon glyphicon-font'
            when 'name'
              $scope.info.name = $scope.info.name or conn.value
              conn.iconStyle = 'glyphicon glyphicon-font'
            when 'tel', 'phone'
              conn.iconStyle = 'glyphicon glyphicon-earphone'
              conn.btnStyle = 'btn-success'
              conn.link = 'tel:' + conn.value
              conn.quickContact = true
            when 'coverPhoto'
              if conn.value.match /^\/ipfs\/[1-9A-Za-z]{40,60}$/
                $scope.coverPhoto = $scope.coverPhoto or { 'background-image': 'url(' + conn.value + ')' }
            when 'profilePhoto'
              if conn.value.match /^\/ipfs\/[1-9A-Za-z]{40,60}$/
                $scope.profilePhoto = $scope.profilePhoto or conn.value
            when 'url'
              conn.link = conn.value
              if conn.value.indexOf('facebook.com/') > -1
                conn.iconStyle = 'fa fa-facebook'
                conn.btnStyle = 'btn-facebook'
                conn.link = conn.value
                conn.linkName = conn.value.split('facebook.com/')[1]
                conn.quickContact = true
              else if conn.value.indexOf('twitter.com/') > -1
                conn.iconStyle = 'fa fa-twitter'
                conn.btnStyle = 'btn-twitter'
                conn.link = conn.value
                conn.linkName = conn.value.split('twitter.com/')[1]
                conn.quickContact = true
              else if conn.value.indexOf('plus.google.com/') > -1
                conn.iconStyle = 'fa fa-google-plus'
                conn.btnStyle = 'btn-google-plus'
                conn.link = conn.value
                conn.linkName = conn.value.split('plus.google.com/')[1]
                conn.quickContact = true
              else if conn.value.indexOf('linkedin.com/') > -1
                conn.iconStyle = 'fa fa-linkedin'
                conn.btnStyle = 'btn-linkedin'
                conn.link = conn.value
                conn.linkName = conn.value.split('linkedin.com/')[1]
                conn.quickContact = true
              else if conn.value.indexOf('github.com/') > -1
                conn.iconStyle = 'fa fa-github'
                conn.btnStyle = 'btn-github'
                conn.link = conn.value
                conn.linkName = conn.value.split('github.com/')[1]
                conn.quickContact = true
              else
                conn.iconStyle = 'glyphicon glyphicon-link'
                conn.btnStyle = 'btn-default'
          if conn.confirmations + conn.refutations > 0
            percentage = conn.confirmations * 100 / (conn.confirmations + conn.refutations)
            if percentage >= 80
              alpha = conn.confirmations / mostConfirmations * 0.7 + 0.3
              # conn.rowStyle = 'background-color: rgba(223,240,216,' + alpha + ')'
            else if percentage >= 60
              conn.rowClass = 'warning'
            else
              conn.rowClass = 'danger'
          $scope.hasQuickContacts = $scope.hasQuickContacts or conn.quickContact
        $scope.getPhotosFromGravatar()
        $scope.setPageTitle ($scope.info.name || $scope.info.nickname || $scope.idValue)

        $scope.connectionClicked = (event, id) ->
          if id.connecting_msgs
            id.collapse = !id.collapse
          else
            id.connecting_msgs = Identities.connecting_msgs(angular.extend({
              idType: $scope.idType
              idValue: $scope.idValue
              target_name: id.name
              target_value: id.value
            }, $scope.filters), ->
              for key of id.connecting_msgs
                if isNaN(key)
                  i++
                  continue
                msg = id.connecting_msgs[key]
                msg.data = KJUR.jws.JWS.parse(msg.jws).payloadObj
                msg.gravatar = CryptoJS.MD5(msg.authorEmail or msg.data.author[0][1]).toString()
                msg.linkToAuthor = msg.data.author[0]
                i = undefined
                i = 0
                while i < msg.data.author.length
                  if true # ApplicationConfiguration.uniqueAttributeTypes.indexOf(msg.data.author[i][0] > -1)
                    msg.linkToAuthor = msg.data.author[i]
                    break
                  i++
              id.collapse = !id.collapse
            )

        $scope.getStats()
        $scope.getReceivedMsgs 0
        $scope.getSentMsgs 0
      )

    $scope.getStats = ->
      Identities.stats(angular.extend({}, $scope.filters, {
        idType: $scope.idType
        idValue: $scope.idValue
      }), (res) ->
        angular.extend($scope.stats, res)
        $scope.info.email = $scope.info.email or $scope.stats.email
      )

    $scope.getSentMsgs = (offset) ->
      if !isNaN(offset)
        $scope.filters.sentOffset = offset
      sent = Identities.sent(angular.extend({}, $scope.filters, {
        idType: $scope.idType
        idValue: $scope.idValue
        type: $scope.filters.type
        offset: $scope.filters.sentOffset
        limit: $scope.filters.limit
        max_distance: -1
      }, if $scope.filters.max_distance == -1 then { viewpoint_name: null, viewpoint_value: null }), ->
        $scope.processMessages sent, { authorIsSelf: true }
        if $scope.filters.sentOffset == 0
          $scope.sent = sent
        else
          for key of sent
            if isNaN(key)
              continue
            $scope.sent.push sent[key]
        $scope.sent.$resolved = sent.$resolved
        $scope.filters.sentOffset = $scope.filters.sentOffset + sent.length
        if sent.length < $scope.filters.limit
          $scope.sent.finished = true
      , (error) ->
        $scope.sent.finished = true
      )
      if offset == 0
        $scope.sent = []
      $scope.sent.$resolved = sent.$resolved

    $scope.getReceivedMsgs = (offset) ->
      if !isNaN(offset)
        $scope.filters.receivedOffset = offset
      received = Identities.received(angular.extend({}, $scope.filters, {
        idType: $scope.idType
        idValue: $scope.idValue
        type: $scope.filters.type
        offset: $scope.filters.receivedOffset
        limit: $scope.filters.limit
      }, if $scope.filters.max_distance == -1 then { viewpoint_name: null, viewpoint_value: null }), ->
        $scope.processMessages received, { recipientIsSelf: true }
        if $scope.filters.receivedOffset == 0
          $scope.received = received
        else
          for key of received
            if isNaN(key)
              continue
            $scope.received.push received[key]
        $scope.received.$resolved = received.$resolved
        $scope.filters.receivedOffset = $scope.filters.receivedOffset + received.length
        if received.length < $scope.filters.limit
          $scope.received.finished = true
      , (error) ->
        $scope.sent.finished = true
      )
      if offset == 0
        $scope.received = []
      $scope.received.$resolved = received.$resolved

    $scope.getPhotosFromGravatar = ->
      email = $scope.info.email or $scope.idValue
      $scope.gravatar = CryptoJS.MD5(email).toString()

    $scope.setFilters = (filters) ->
      angular.extend $scope.filters, filters
      angular.extend $scope.filters,
        offset: 0
        receivedOffset: 0
        sentOffset: 0
      $scope.getReceivedMsgs 0
      $scope.getSentMsgs 0
      if filters.max_distance != undefined
        $scope.getStats()

    $scope.findOne = ->
      $scope.idType = $stateParams.type
      $scope.idValue = $stateParams.value
      $scope.isUniqueType = config.uniqueAttributeTypes.indexOf($scope.idType) > -1
      if !$scope.isUniqueType
        $state.go 'identities.list', { search: $scope.idValue }
        $scope.tabs[2].active = true
      $scope.setPageTitle $scope.idValue
      $scope.getConnections()
      if $scope.idType == $scope.filters.viewpoint_name and $scope.idValue == $scope.filters.viewpoint_value
        $scope.distance = 0

      $scope.thumbsUp = Identities.received(angular.extend({}, $scope.filters, {
        idType: $scope.idType
        idValue: $scope.idValue
        order_by: 'distance'
        max_distance: 0
        direction: 'asc'
        type: 'rating:positive'
        offset: $scope.filters.receivedOffset
        limit: 12
      }), ->
        $scope.processMessages $scope.thumbsUp, { recipientIsSelf: true }
        if isNaN(parseInt($scope.distance)) and $scope.thumbsUp.length
          $scope.distance = $scope.thumbsUp[0].distance + 1
      )

      $scope.thumbsDown = Identities.received(angular.extend({}, $scope.filters, {
        idType: $scope.idType
        idValue: $scope.idValue
        order_by: 'distance'
        max_distance: 0
        direction: 'asc'
        type: 'rating:negative'
        offset: $scope.filters.receivedOffset
        limit: 12
      }), ->
        $scope.processMessages $scope.thumbsDown, { recipientIsSelf: true }
      )

    if $state.is 'identities.list'
      $scope.search()
    else if $state.is 'identities.show'
      $scope.findOne()
]
