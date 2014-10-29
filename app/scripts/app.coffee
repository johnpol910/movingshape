'use strict'

angular.module('PubNubAngularApp', ["pubnub.angular.service"])
  .config ($routeProvider) ->
    $routeProvider
      .when '/join',
        templateUrl: 'views/join.html'
        controller: 'JoinCtrl'
      .when '/action',
        templateUrl: 'views/action.html'
        controller: 'ActionCtrl'
      .otherwise
        redirectTo: '/join'
