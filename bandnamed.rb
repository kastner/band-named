#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__) + "/../../lib"
$:.unshift File.dirname(__FILE__)
%w|rubygems mongrel camping mongrel/camping camping/session openid redcloth open-uri|.each{|lib| require lib}

Camping.goes :Bandnamed

# ActiveRecord::Base.logger = Logger.new(STDOUT)

module Bandnamed
  include Camping::Session
end

# module Peglist::Helpers
#   def HURL(*args)
#     url = URL(*args)
#     url.scheme = "http"
#     if `hostname`.match(/i-am-a-Mac/)
#       url.host = "peglist.metaatem.net"
#       url.port = nil
#     end
#     url
#   end
#   
#   def escape_javascript(javascript)
#     (javascript || '').gsub('\\','\0\0').gsub(/\r\n|\n|\r/, "\\n").gsub(/["']/) { |m| "\\#{m}" }
#   end
# end

# module Peglist::Models
#   class Peg < Base
#     belongs_to :user
#     validates_format_of :number, :with => /^[0-9]+$/
#     validates_uniqueness_of :number, :scope => :user_id
#   end
#   
#   class User < Base
#     validates_uniqueness_of :username
#     has_many :pegs
#     
#     def ordered_pegs
#       zeros, rest = pegs.find(:all).partition {|i| i.number.match(/^0/)}
#       zeros.sort! {|a,b| a.number <=> b.number}
#       rest.sort! {|a,b| a.number.to_i <=> b.number.to_i}
#       [zeros, rest].flatten
#     end
#   end
#   
#   class CreateTheBasics < V 1.0
#     def self.up
#       create_table :peglist_pegs do |t|
#         t.column :id, :integer, :null => false
#         t.column :user_id, :integer, :null => false
#         t.column :number, :string, :null => false
#         t.column :phrase, :string
#         t.column :image_url, :string
#         t.column :image_link, :string
#         t.column :notes, :text
#         t.column :created_at, :datetime
#       end
#       
#       create_table :peglist_users do |t|
#         t.column :id, :integer, :null => false
#         t.column :username, :string, :null => false
#         t.column :openid, :string
#         t.column :avatar_url, :string
#         t.column :created_at, :datetime
#       end
#     end
#   end
# end

module Bandnamed::Controllers
  class Index < R '/'
    def get
      # # raise @state.to_s
      # @user = User.find(@state.user_id) if @state.user_id
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
        title "Bandnamed | Socially Unacceptable"
        # link :rel => 'stylesheet', :type => 'text/css', :href => '/static/style.css'
        # link :rel => 'stylesheet', :type => 'text/css', :href => '/static/lightbox.css'
        # link :rel => 'shortcut icon', :type => 'image/png', :href => '/static/favicon.png'
        # link :rel => 'icon', :type => 'image/png', :href => '/static/favicon.png'
        # script :type => 'text/javascript', :src => '/static/prototype.js'
        # script :type => 'text/javascript', :src => '/static/lightbox.js'
        # script :type => 'text/javascript', :src => '/static/image_panel.js'
      end
      body :id => (@body_id || "home") do
        div.page! do
          div.header! do
            # h2.logo! do
            #   text %Q{<a href="/" title='Peg list at Meta | ateM'><img src="/static/logo.png" alt="Peg list at Meta | ateM"/></a>}
            # end
            # div.wrap do
            #   hr
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
            self << yield  
          end
          div.footer! do

          end          
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

# def Peglist.create
#   Camping::Models::Session.create_schema
#   Peglist::Models.create_schema :assume => (Peglist::Models::Peg.table_exists? ? 1.0 : 0.0)
# end

if __FILE__ == $0
  Bandnamed::Models::Base.establish_connection :adapter => "sqlite3", :database => "/Users/kastner/.camping.db"
  Bandnamed::Models::Base.threaded_connections = false
  Mongrel::Camping::start("0.0.0.0",3302,"/",Bandnamed).run.join
end
