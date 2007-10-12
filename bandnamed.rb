#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__) + "/../../lib"
$:.unshift File.dirname(__FILE__)
%w|rubygems mongrel camping mongrel/camping camping/session openid redcloth open-uri|.each{|lib| require lib}

Camping.goes :Bandnamed

# ActiveRecord::Base.logger = Logger.new(STDOUT)

module Bandnamed
  include Camping::Session
end

module Bandnamed::Helpers
  def HURL(*args)
    url = URL(*args)
    url.scheme = "http"
    if `hostname`.match(/i-am-a-Mac/)
      url.host = "bandnamed.com"
      url.port = nil
    end
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
      # # raise @state.to_s
      # @user = User.find(@state.user_id) if @state.user_id
      render :index
    end
  end
  
  class Login
    def open_id_consumer
      OpenID::Consumer.new(@state, OpenID::FilesystemStore.new("/tmp/openids"))
    end

    def normalize_url(url)
      url = url.downcase

      case url
      when %r{^https?://[^/]+/[^/]*}
        url # already normalized
      when %r{^https?://[^/]+$}
        url + "/"
      when %r{^[.\d\w]+/.*$}
        "http://" + url
      when %r{^[.\d\w]+$}
        "http://" + url + "/"
      else
        raise "Unable to normalize: #{url}"
      end
    end

    def get
      response = open_id_consumer.complete(input)
      identity_url = normalize_url(response.identity_url) if response.identity_url

      case response.status
      when OpenID::CANCEL
        @a = "Canceled"
      when OpenID::FAILURE
        @a = "OpenID authentication failed: #{response.msg}"
      when OpenID::SUCCESS
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

    def post
      openid_url = normalize_url(input.openid_url)
      response = open_id_consumer.begin(openid_url)

      case response.status
      when OpenID::FAILURE
        @a = "Failure with that OpenID url. Check it and try again please."
      when OpenID::SUCCESS
        redirect response.redirect_url(self.HURL.to_s, self.HURL(Login).to_s)
      end      
    end
  end

  class Logout
    def get
      @state.keys.each{|key| @state.delete(key)}
      @message = "You have been logged out"
      render :index
    end
  end
  
  class Static < R '/static/(.+)'
    MIME_TYPES = {'.css' => 'text/css', '.js' => 'text/javascript', 
                  '.jpg' => 'image/jpeg'}
    PATH = File.expand_path(File.dirname(__FILE__))

    def get(path)
      @headers['Content-Type'] = MIME_TYPES[path[/\.\w+$/, 0]] || "text/plain"
      unless path.include? ".." # prevent directory traversal attacks
        @headers['X-Sendfile'] = "#{PATH}/static/#{path}"
      else
        @status = "403"
        "403 - Invalid path"
      end
    end
  end
end

module Bandnamed::Views
  def amp
    span.amp "&"
  end
  
  def textalize(str)
    text RedCloth.new(str).to_html
  end
  
  def layout
    xhtml_strict do
      head do
        title "Band Named | Socially Unacceptable Band Names (now with Ajax)"
        link :rel => 'stylesheet', :type => 'text/css', :href => '/static/style.css'
        script :type => 'text/javascript', :src => '/static/jquery.js'
        # script :type => 'text/javascript', :src => 'http://gridlayouts.com/_assets/_js/jquery.js'
        script :type => 'text/javascript', :src => 'http://gridlayouts.com/_assets/_js/gridlayout.js'
      end
      body :id => (@body_id || "home") do
        div.page! do
          div.header! do
            div.wrap do
              text %Q{<a href="/" title='Bandnamed'>Band Named.com</a>}
            end
            hr
            form :action => R(Login), :method => :post do
              div do
                p { text %Q{Sign in with your <img src="/static/openid-icon.gif">OpenID!} }
                p '(eg: http://openid.aol.com/<AOL IM>)'
                # label , :for => 'login_openid', :id => 'login_openid_label'
                input :name => 'openid_url', :type => 'text', :id => 'login_openid'
                input :type => 'submit', :value => 'go', :id => 'submit_button'
              end
            end
            
            #   if !@new_user
            #     _login
            #   end
            #   hr
            #   ul.nav! do
            #     li.home { text %Q{<a href="/">Home #{amp} Peg list</a>} }
            #     li.what { a "What is a Peg list?", :href => R(What) }
            #   end
            # end
          end
          div.content! do
            div.GridLayout! do
              text %Q!<div id="GridLayout-params">{
                          column_width:60,
                          column_count:11,
                          subcolumn_count:2,
                          column_gutter:12,
                          align:'center'
                      }</div>!
            end
            self << yield  
          end
        end
        div.footer! do
          p { text %Q{Site design and development by <a href="mailto:kastner@gmail.com">Erik Kastner</a>}}
        end          
      end
    end
  end
  
  def index
    h1 "Coming soon!"
    # if @state.username
    #   _logged_in_home
    # else
    #   _new_home
    # end
  end
  
  def signup
    h1 "Pick your username and an avatar if you have one"
    h2 "You will use the OpenID #{@state.openid} to log in"
    
    errors_for @new_user
    
    form :action => R(Signup), :method => :post do
      p do
        label 'Username:', :for => 'signup_username'
        input :name => 'username', :type => 'text', :id => 'signup_username', :value => @new_user.username
        text <<-HTML
          <script type="text/javascript" charset="utf-8">
          Event.observe('signup_username', 'keyup', function() {
            $('flickr_username').value = $('signup_username').value
            $('twitter_username').value = $('signup_username').value
          })            
          </script>
        HTML
      end
      
      fieldset do
        legend "Find my avatar:"
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
        text <<-HTML
        <script type="text/javascript" charset="utf-8">
          document.getElementsByClassName('avatar_button').forEach(function(button) {
            button.onclick = function() {
              var type = button.id.split("_")[0]
              var url = '/avatar/' + type + '/' + $(type+'_username').value
              new Ajax.Request(url, {
                method: 'get',
                onSuccess: function(req) {
                  $('signup_avatar').value = req.responseText;
                  $('avatar_preview').src = req.responseText;
                }
              })
            }
          })
        </script>
        HTML
      end
      
      p do
        label 'Avatar url:', :for => 'signup_avatar'
        input :name => 'avatar_url', :type => 'text', :id => 'signup_avatar', :value => @new_user.avatar_url
        img :id => 'avatar_preview', :width => 45, :src => @avatar_url
      end
      
      p do
        input :type => 'submit', :value => "Sign up"
      end
    end
  end
end

def Bandnamed.create
  Camping::Models::Session.create_schema
  Bandnamed::Models.create_schema :assume => (Bandnamed::Models::Band.table_exists? ? 1.0 : 0.0)
end

if __FILE__ == $0
  Bandnamed::Models::Base.establish_connection :adapter => "sqlite3", :database => "/Users/kastner/.camping.db"
  Bandnamed::Models::Base.threaded_connections = false
  Mongrel::Camping::start("0.0.0.0",3302,"/",Bandnamed).run.join
end
