require 'sinatra'
require 'json'
require 'pp'
require 'erb'
require 'yaml'
require 'rubygems'
require 'active_support/inflector'
require 'set'
require 'version'
require 'hooks'
require 'client'
require 'bundler/setup'
require 'base64'
require 'openssl'

class TrelloHookListener < Sinatra::Base

  ############################################################
  ## Trello Webhook registration
  ############################################################

  # returns the registration page
  #
  get '/register' do
    erb :register
  end

  get '/version' do
    "version: #{TrelloWebhookListener::VERSION}"
  end

  ############################################################
  ## Trello Webhook
  ############################################################

  head '/hook' do
    return 200
  end

  post '/hook' do
    request.body.rewind
    payload_body = request.body.read
    verify_signature payload_body, request.url, request.env['HTTP_X_TRELLO_WEBHOOK']

    if params[:payload]
      push = JSON.parse(params[:payload])
    else
      push = JSON.parse payload_body
    end

    unless push.nil?
      puts push.to_json
    end

    return 200
  end

  ############################################################
  ## auto assign
  ############################################################

  head '/auto-assign' do
    return 200
  end

  post '/auto-assign' do
    request.body.rewind
    payload_body = request.body.read
    #verify_signature(payload_body)
    
    if params[:payload]
      push = JSON.parse(params[:payload])
    else
      push = JSON.parse payload_body
    end

    Hooks::AutoAssign.new(push['action']).execute
  end

  ############################################################
  ## auto version
  ############################################################

  head '/auto-version' do
    return 200
  end

  post '/auto-version' do
    request.body.rewind
    payload_body = request.body.read
    #verify_signature(payload_body)
    
    if params[:payload]
      push = JSON.parse(params[:payload])
    else
      push = JSON.parse payload_body
    end

    Hooks::AutoVersion.new(push['action']).execute
  end

  def base64Digest subject, times=1
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['TRELLO_KEY'], subject)
  end

  def verify_signature payload_body, callbackURL, hash
    content = payload_body + callbackURL
    double_hash = base64Digest(base64Digest(content))
    header_hash = base64Digest hash

    return halt 500, "Signatures didn't match!" unless Rack::Utils.secure_compare(double_hash, header_hash)
  end

end
