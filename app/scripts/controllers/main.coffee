'use strict'

###
The JoinCtrl is responsible for collecting the username and calling the PubNub.init() method
when the "Join" button is clicked.
###
angular.module('PubNubAngularApp')
  .controller 'JoinCtrl', ($rootScope, $scope, $location, PubNub) ->
    $scope.data = {username:'Action ' + Math.floor(Math.random() * 1000)}

    $scope.join = ->
      $rootScope.data ||= {}
      $rootScope.data.username = $scope.data?.username
      $rootScope.data.super    = $scope.data?.super
      $rootScope.data.uuid     = Math.floor(Math.random() * 1000000) + '__' + $scope.data.username

      #
      # NOTE! We include the secret & auth keys here only for demo purposes!
      #
      # In a real app, the secret key should be protected by server-only access, and
      # different/separate auth keys should be distributed by the server and used
      # for user authentication.
      #
      $rootScope.secretKey = if $scope.data.super then 'sec-c-MWM2ZjQ5NGQtNjZlYy00NmI4LWJlYjktMWNlNzEyNmQ0ZjU2' else null
      $rootScope.authKey   = if $scope.data.super then 'ChooseABetterSecret' else null

      PubNub.init({
        subscribe_key : 'sub-c-8554d4a4-3118-11e4-adbf-02ee2ddab7fe'
        publish_key   : 'pub-c-7dbd292e-2730-47cb-a568-b30f9efe2065'
        # WARNING: DEMO purposes only, never provide secret key in a real web application!
        secret_key    : $rootScope.secretKey
        auth_key      : $rootScope.authKey
        uuid          : $rootScope.data.uuid
        ssl           : true
      })
      
      if $scope.data.super
        ### Grant access to the SuperHeroes room for supers only! ###
        PubNub.ngGrant({channel:'SuperHeroes',auth_key:$rootScope.authKey,read:true,write:true,callback:->console.log('SuperHeroes! all set', arguments)})
        PubNub.ngGrant({channel:"SuperHeroes-pnpres",auth_key:$rootScope.authKey,read:true,write:false,callback:->console.log('SuperHeroes! presence all set', arguments)})
        # Let everyone see the control channel so they can retrieve the rooms list
        PubNub.ngGrant({channel:'__controlchannel',read:true,write:true,callback:->console.log('control channel all set', arguments)})
        PubNub.ngGrant({channel:'__controlchannel-pnpres',read:true,write:false,callback:->console.log('control channel presence all set', arguments)})

      $location.path '/action'
      
    $(".prettyprint")


###
The ActionCtrl is responsible for creating, displaying, subscribing to, and
chatting in channels
###
angular.module('PubNubAngularApp')
  .controller 'ActionCtrl', ($rootScope, $scope, $location, PubNub) ->
    $location.path '/join' unless PubNub.initialized()
    
    ### Use a "control channel" to collect channel creation messages ###
    $scope.controlChannel = '__controlchannel'
    $scope.channels = []
    $scope.shapes = []
    $scope.shape_container = $(".move-area")
    $scope.me_shape = $("#me-shape")
    $scope.me_pos = new Object();
    $scope.message = ""

    $scope.me_pos.x = Math.floor(Math.random() * $($scope.shape_container).width() );
    $scope.me_pos.y = Math.floor(Math.random() * $($scope.shape_container).height() );

    $scope.me_color = "rgb(" + Math.floor(Math.random() * 255) + "," + Math.floor(Math.random() * 255) + "," + Math.floor(Math.random() * 255) + ")"

    ### Publish Shape Position ###
    $scope.publish_shape = (type)->
      content = ""
      if type == "message"
        content = $scope.newMessage
        $scope.newMessage = ""
        $scope.message = content
      me_text_width = $(".width_for_text").html($scope.message).width()
      console.log 'publish shape position', $scope
      move_area_width = $(".move-area").width()
      tmp_text_left = 0
      if parseInt($scope.me_pos_left) < ( move_area_width / 2 )
        $scope.me_text_left = $("#me-shape").width()
        tmp_text_left = $("#me-shape").width() - 12
      else
        $scope.me_text_left = 0 - me_text_width - 12
        tmp_text_left =  0 - me_text_width - 12
      tmp_text_left = tmp_text_left + "px"
      $scope.me_text_left = $scope.me_text_left + "px"
      $scope.me_text_top = $scope.me_text_top + "px"
      return unless $scope.selectedChannel
      PubNub.ngPublish { channel: $scope.selectedChannel, message: {type:type, content: $scope.message, text_left: tmp_text_left, pos_left:$scope.me_pos_left , pos_top:$scope.me_pos_top, shape_color:$scope.me_color, user:$scope.data.username} }


    $scope.change_shape_position = (ele, pos) ->
      width = $(ele).width()
      height = $(ele).height()
      pos_left = pos.x - width / 2
      pos_top = pos.y - height / 2
      $scope.me_pos_left = pos_left + "px";
      $scope.me_pos_top = pos_top + "px";
      $scope.publish_shape("shape")
      return

    $scope.change_shape_position $scope.me_shape, $scope.me_pos

    ### Change Shape Position ###
    $scope.change_shape = (ev) -> 
      $scope.me_pos.x = ev.layerX
      $scope.me_pos.y = ev.layerY
      $scope.change_shape_position $scope.me_shape, $scope.me_pos
      return

    ### Create a new channel ###
    $scope.createChannel = ->
      console.log 'createChannel', $scope
      return unless $scope.data.super && $scope.newChannel
      channel = $scope.newChannel
      $scope.newChannel = ''

      # grant anonymous access to channel and presence
      PubNub.ngGrant({channel:channel,read:true,write:true,callback:->console.log("#{channel} all set", arguments)})
      PubNub.ngGrant({channel:"#{channel}-pnpres",read:true,write:false,callback:->console.log("#{channel} presence all set", arguments)})

      # publish the channel creation message to the control channel
      PubNub.ngPublish { channel: $scope.controlChannel, message: channel }

      # wait a tiny bit before selecting the channel to allow time for the presence
      # handlers to register
      setTimeout ->
        $scope.subscribe_shape channel
        $scope.showCreate = false
      , 100

    $scope.is_exists_user = (username) ->
      if !$scope.users
        return false
      tmp_flag = false;
      i = 0
      while i < $scope.users.length
        if $scope.users[i] == username
          tmp_flag = true;
          break;
        i = i + 1
      return tmp_flag

    $scope.refresh_shapes = ->
      i = 0
      while i < $scope.shapes.length
        tmp_user_flag = $scope.is_exists_user $scope.shapes[i].user
        if tmp_user_flag == false
          $scope.shapes.splice i, 1
        i = i + 1
      return

    ### select a channel to display the shape position of users ###
    $scope.subscribe_shape = (channel) ->
      console.log 'subscribe shape position of users', channel
      return if channel == $scope.selectedChannel
      PubNub.ngUnsubscribe {channel: $scope.selectedChannel} if $scope.selectedChannel
      $scope.selectedChannel = channel

      PubNub.ngSubscribe {
        channel: $scope.selectedChannel
        auth_key: $scope.authKey
        error: -> console.log arguments
      }
      $rootScope.$on PubNub.ngPrsEv($scope.selectedChannel), (ngEvent, payload) ->
        $scope.publish_shape("shape")
        $scope.$apply ->
          userData = PubNub.ngPresenceData $scope.selectedChannel
          newData = {}
          $scope.users    = PubNub.map PubNub.ngListPresence($scope.selectedChannel), (x) ->
            newX = x
            if x.replace
              newX = x.replace(/\w+__/, "")
            if x.uuid
              newX = x.uuid.replace(/\w+__/, "")
            newData[newX] = userData[x] || {}
            newX
          $scope.refresh_shapes()
          $scope.userData = newData

      $rootScope.$on PubNub.ngMsgEv($scope.selectedChannel), (ngEvent, payload) ->
        if payload.message.user == $rootScope.data.username
          return
        is_exists = $scope.is_exists_user payload.message.user
        console.log payload.message.user, is_exists
        if is_exists == false
          return
        if payload.message.user
          new_obj = new Object()
          new_obj.type = payload.message.type
          new_obj.user = payload.message.user
          new_obj.pos_left = payload.message.pos_left
          new_obj.pos_top = payload.message.pos_top
          new_obj.shape_color = payload.message.shape_color
          new_obj.message = payload.message.content
          new_obj.text_left = payload.message.text_left
        $scope.$apply ->
          shape_flag = false
          i = 0
          while i < $scope.shapes.length
            if new_obj.user == $scope.shapes[i].user    
              $scope.shapes[i].pos_left = new_obj.pos_left
              $scope.shapes[i].pos_top = new_obj.pos_top
              $scope.shapes[i].shape_color = new_obj.shape_color
              $scope.shapes[i].message = new_obj.message
              $scope.shapes[i].text_left = new_obj.text_left
              shape_flag = true
              break
            i = i + 1
          if shape_flag == false
            $scope.shapes.push new_obj


      ###PubNub.ngHistory { channel: $scope.selectedChannel, auth_key: $scope.authKey, count:0 }###

    ### When controller initializes, subscribe to retrieve channels from "control channel" ###
    PubNub.ngSubscribe { channel: $scope.controlChannel }

    ### Register for channel creation message events ###
    $rootScope.$on PubNub.ngMsgEv($scope.controlChannel), (ngEvent, payload) ->
      $scope.$apply -> $scope.channels.push payload.message if $scope.channels.indexOf(payload.message) < 0

    ### Get a reasonable historical backlog of messages to populate the channels list ###
    ###PubNub.ngHistory { channel: $scope.controlChannel, count:100 }###


    ### and finally, create and/or enter the 'WaitingRoom' channel ###
    if $scope.data?.super
      $scope.newChannel = 'WaitingRoom'
      $scope.createChannel()
    else
      $scope.subscribe_shape 'WaitingRoom'
