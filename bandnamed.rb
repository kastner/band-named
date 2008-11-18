#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__)
require 'rubygems'
%w|activerecord openid openid/store/filesystem camping camping/session face redcloth open-uri|.each{|lib| require lib}

Camping.goes :Bandnamed

module Bandnamed
  include Camping::Session
end

module Bandnamed::Helpers
  def HURL(*args)
    url = URL(*args)
    url.scheme = "http"
    url
  end
  
  def escape_javascript(javascript)
    (javascript || '').gsub('\\','\0\0').gsub(/\r\n|\n|\r/, "\\n").gsub(/["']/) { |m| "\\#{m}" }
  end
end

module Bandnamed::Models
  class Band < Base
    belongs_to :user
    validates_presence_of :name
    validates_uniqueness_of :name
  end
  
  class User < Base
    validates_presence_of :username
    validates_length_of :username, :minimum => 2
    validates_uniqueness_of :username
    has_many :bands    
  end
  
  class CreateTheBasics < V 1.0
    def self.up
      create_table :bandnamed_bands do |t|
        t.column :id, :integer, :null => false
        t.column :user_id, :integer, :null => false
        t.column :name, :string, :null => false
        t.column :created_at, :datetime
        t.column :updated_at, :datetime
      end
      
      create_table :bandnamed_users do |t|
        t.column :id, :integer, :null => false
        t.column :username, :string, :null => false
        t.column :openid, :string
        t.column :avatar_url, :string
        t.column :created_at, :datetime
      end
    end
  end
end

module Bandnamed::Controllers
  class Index < R '/'
    def get
      # raise HURL(Index).to_s
      # # raise @state.to_s
      @user = User.find(@state.user_id) if @state.user_id
      @new_bands = Band.find(:all, :order => "bandnamed_bands.created_at DESC", :limit => 50, :include => :user)
      render :index
    end
  end
  
  class AvatarSearch < R '/avatar/(.+)/(.+)'
    def get(service, username)
      case service
      when "twitter"
        TwitterFace.url(username)
      when "flickr"
        FlickrFace.url(username)
      end
    end
  end
  
  class ABand < R '/band/(\d+)'
    def get(id)
      @user = User.find(@state.user_id) if @state.user_id
      @band = Band.find(id, :include => :user)
      if (@band)
        @title = @band.name
        render :band
      end
    end
  end
  
  class NewBand
    def post
      @user = User.find(@state.user_id) if @state.user_id
      @band = @user.bands.build(:name => input.band_name)
      @band.save!
      redirect HURL(Index).to_s
    end
  end
  
  class Signup
    def get
      if !@state.openid
        @error = "You must sign in with OpenID before you sign up"
        @new_bands = []
        render :index
      else
        @new_user = User.new
        render :signup
      end
    end
    
    def post
      puts "Posting #{input.username}."
      @username = input.username
      @avatar_url = input.avatar_url
      
      @new_user = User.new(:openid => @state.openid, :username => @username, :avatar_url => @avatar_url)
      if @new_user.valid?
        # puts "Saved"
        @new_user.save
        @state.user_id = @new_user.id
        @state.username = @new_user.username
        redirect HURL(Index).to_s
      else
        # puts "FAIL!"
        @avatar_url = "/static/blank.jpg"
        render :signup
      end
    end
  end
  
  class Login
    def open_id_consumer
      OpenID::Consumer.new(@state, OpenID::Store::Filesystem.new("/tmp/openids"))
    end

    def normalize_url(url)
      url = url.downcase

      case url
      when %r{^https?://[^/]+/[^/]*}
        url # already normalized
      when %r{^https?://[^/]+$}
        url + "/"
      when %r{^[.\d\w]+\.[.\d\w]+/.*$} # must have a period
        "http://" + url
      when %r{^[.\d\w]+$}
        "http://openid.aol.com/" + url.gsub(/\s/, '')
      else
        raise "Unable to normalize: #{url}"
      end
    end
    
    def get
      response = open_id_consumer.complete(input, self.HURL(env["REQUEST_PATH"] || env["REQUEST_URI"]).to_s)
      identity_url = normalize_url(response.identity_url) if response.identity_url
      
      case response.status
      when OpenID::Consumer::CANCEL
        @a = "Canceled"
      when OpenID::Consumer::FAILURE
        # debugger
        @a = "OpenID authentication failed: #{response.message}"
      when OpenID::Consumer::SUCCESS
        @state.openid = identity_url
        @user = User.find_by_openid(identity_url)
        if @user
          @state.user_id = @user.id
          @state.username = @user.username
          redirect HURL(Index).to_s
        else
          redirect HURL(Signup).to_s
        end
      end
    end

    # Begin the openid auth process
    def post
      openid_url = normalize_url(input.openid_url)
      response = open_id_consumer.begin(openid_url)

      begin
        redirect response.redirect_url(self.HURL.to_s, self.HURL(Login).to_s)
      rescue OpenID::OpenIDError, Timeout::Error => e
        @a = "Failure with that OpenID url."
      end        
    end
  end

  class Logout
    def get
      @state.keys.each{|key| @state.delete(key)}
      @message = "You have been logged out"
      redirect HURL(Index).to_s
    end
  end  
end

module Bandnamed::Views
  def js(str)
    text <<-JAVASCRIPT
      <script type="text/javascript" charset="utf-8">
      #{str}
      </script>
    JAVASCRIPT
  end
  
  def textalize(str)
    text RedCloth.new(str).to_html
  end
  
  def band
    h1 { text @band.name }
    h2 "Created by: #{@band.user.username}"
    h3 @band.created_at.strftime("%m/%d/%Y at %l:%M %p")
  end
  
  def signup
    h1 "Pick your username and picture"
    h2 { text "You will use the OpenID <em class='openid_url'>#{@state.openid}</em> to log in" }
    
    errors_for @new_user
    
    form :action => R(Signup), :method => :post, :class => "signup" do
      p do
        label 'Username:', :for => 'signup_username'
        input :name => 'username', :type => 'text', :id => 'signup_username', :value => @new_user.username
      end

      p do
        label 'Picture URL:', :for => 'signup_avatar'
        input :name => 'avatar_url', :type => 'text', :id => 'signup_avatar', :value => @new_user.avatar_url
        js <<-HTML
          $("#signup_avatar").change(function() {
            var url = $("#signup_avatar").val();
            if (url) {
              $('#avatar_preview').attr("src", url);
            }
          });
          $(document).ready(function() { $("#signup_avatar").change(); });
        HTML
      end
      
      p do
        label 'Picture Preview:'
        img :id => 'avatar_preview', :width => 45, :height => 45, :src => (@avatar_url || "/static/blank.jpg")
        div.text_box
      end
      
      p do
        a "Click here to use a picture from flickr or twitter", :href => "#", :id => "avatar_trigger"
        js <<-HTML
        $("#avatar_trigger").click(function(){$("#external_avatars").toggle();});
        HTML
      end
      
      fieldset.online_avatar! :style => "display: none;", :id => "external_avatars" do
        legend "Use a Picture from another service:"
        p do
          label 'Flickr username:', :for => 'flickr_username'
          input :name => 'flickr_username', :type => 'text', :class => 'avatar_search', :id => 'flickr_username'
          input :type => 'button', :value => "Lookup", :id => 'flickr_button', :class => 'avatar_button'
        end
        p do
          label 'Twitter username:', :for => 'twitter_username'
          input :name => 'twitter_username', :type => 'text', :class => 'avatar_search', :id => 'twitter_username'
          input :type => 'button', :value => "Lookup", :id => 'twitter_button', :class => 'avatar_button'
        end
        js <<-HTML
          $('.avatar_button').click(function(event) {
            var type = event.target.id.split("_")[0]
            var url = '/avatar/' + type + '/' + $('#'+type+'_username').val()
            $.get(url, function(data) {
              $('#signup_avatar').val(data);
              $('#avatar_preview').attr("src", data);
            })
          });
        HTML
      end
      
      p do
        input :type => 'submit', :value => "Sign up"
      end
    end
  end
  
  def index
    if @state.username
      h3 "Add a Band"
      form :action => R(NewBand), :method => :post, :class => "new_band" do
        label 'Band name:', :for => 'band_name'
        input :name => 'band_name', :id => 'band_name', :type => 'text'
        input :type => 'submit', :value => 'add'
      end
    else
      h2 "Sign in above to add bands"
    end
    ul.new_bands! do
      @new_bands.each do |band|
        li { text "<a href='#{R(ABand, band.id)}'>#{band.name}</a> <em>by: #{band.user.username}</em>"}
      end
    end
  end  
  
  def layout
    xhtml_strict do
      head do
        title "Band Named | #{@title || "Socially Unacceptable Band Names (now with Ajax)"}"
        link :rel => 'stylesheet', :type => 'text/css', :href => '/static/style.css'
        script :type => 'text/javascript', :src => '/static/jquery.js'
      end
      body :id => (@body_id || "home") do
        div.page! do
          div.header! do
            div.wrap do
              text %Q{<a href="/" title='Bandnamed'>Band Named.com</a>}
            end
            hr
            if !@new_user
              if !@state.username or @state.username.empty?
                form :action => R(Login), :method => :post, :class => "sign_in_form" do
                  div do
                    p { text 'type in your AOL IM (or <img src="/static/openid-icon.gif">OpenID)'}
                    # p '(eg: http://openid.aol.com/<AOL IM>)'
                    # label , :for => 'login_openid', :id => 'login_openid_label'
                    input :name => 'openid_url', :type => 'text', :id => 'login_openid'
                    input :type => 'submit', :value => 'go', :id => 'submit_button'
                  end
                end
              else
                form :action => R(Logout), :method => :get, :class => "logged_in_form" do
                  div do
                    div { text "Logged in as <em class='username'>#{@state.username}</em> (<em class='openid_url'>#{@state.openid}</em>)" }
                    a "click here to log out", :href => R(Logout)
                  end
                end
              end
            else
            end            
          end
          div.content! do
            self << yield  
          end
        end
        div.footer! do
          p { text %Q{Site design and development by <a href="mailto:kastner@gmail.com">Erik Kastner</a>}}
        end          
      end
    end
  end
  
end

def Bandnamed.create
  Camping::Models::Session.create_schema
  Bandnamed::Models.create_schema :assume => (Bandnamed::Models::Band.table_exists? ? 1.0 : 0.0)
end

Bandnamed::Models::Base.establish_connection :adapter => "sqlite3", :database => "./bandnamed.sqlite3"
Bandnamed::Models::Base.logger = Logger.new('./log/camping.log')
Bandnamed.create
