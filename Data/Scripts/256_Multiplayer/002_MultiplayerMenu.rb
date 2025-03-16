class PokemonSystem
  # Remove the direct attribute accessor and alias
  def mp_show_indicator
    @mp_show_indicator ||= 0
    return @mp_show_indicator
  end

  def mp_show_indicator=(value)
    @mp_show_indicator = value
  end

  # Handle missing methods safely
  def method_missing(method, *args)
    if method.to_s == "mp_show_indicator" && args.empty?
      return mp_show_indicator
    elsif method.to_s == "mp_show_indicator=" && args.length == 1
      return self.mp_show_indicator = args[0]
    else
      super
    end
  end

  def respond_to_missing?(method, include_private = false)
    ["mp_show_indicator", "mp_show_indicator="].include?(method.to_s) || super
  end
end

# Getting Started scene class
class MultiplayerGuideScene
  def initialize
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
  end

  def pbStartScene
    # Create background
    @sprites["background"] = IconSprite.new(0, 0, @viewport)
    @sprites["background"].bitmap = Bitmap.new(Graphics.width, Graphics.height)
    @sprites["background"].bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
    @sprites["background"].opacity = 255
    
    # Create text window with more height to accommodate all text
    @sprites["text"] = Window_UnformattedTextPokemon.newWithSize(
      "", 32, 32, Graphics.width - 64, Graphics.height * 2, @viewport)
    @sprites["text"].opacity = 255
    @sprites["text"].z = @viewport.z + 1
    
    guide_text = [
      "Welcome to Infinite Fusion Multiplayer!\n",
      "\n",
      "Use Up/Down arrows to scroll\n",
      "Press C or Enter to close",
      "\n",
      "To get started, you'll need a Redis database.\n",
      "You can get a free one at redis.io/try-free\n",
      "\n",
      "Once you have your Redis credentials:\n",
      "1. Click 'Connect UI' below\n",
      "2. Enter your host, port, and password\n",
      "3. Click Connect\n",
      "**Make sure all of your devices are connected with the same credentials!**\n",
      "\n",
      "That's it! You're ready to play with others!\n",
      "\n"
    ].join("")
    
    @sprites["text"].text = guide_text
    @sprites["text"].visible = true
    
    # Initialize position
    @window_y = 32  # Starting Y position
    @sprites["text"].y = @window_y
    
    pbFadeInAndShow(@sprites)
  end

  def pbUpdate
    scroll_speed = 16  # Increased scroll speed
    min_y = -(Graphics.height)  # Allow scrolling up to hide the top portion
    max_y = 32  # Original starting position
    
    loop do
      Graphics.update
      Input.update
      if Input.repeat?(Input::UP)
        @window_y = [@window_y + scroll_speed, max_y].min
        @sprites["text"].y = @window_y
      elsif Input.repeat?(Input::DOWN)
        @window_y = [@window_y - scroll_speed, min_y].max
        @sprites["text"].y = @window_y
      elsif Input.trigger?(Input::USE) || Input.trigger?(Input::BACK)
        break
      end
    end
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

class MultiplayerGuideScreen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen
    @scene.pbStartScene
    @scene.pbUpdate
    @scene.pbEndScene
  end
end

# Multiplayer menu scene class
class MultiplayerMenuScene < PokemonOption_Scene
  def initialize
    @changedColor = false
  end

  def pbStartScene(inloadscreen = false)
    super
    @sprites["option"].nameBaseColor = Color.new(35, 200, 35)  # Green theme
    @sprites["option"].nameShadowColor = Color.new(20, 115, 20)
    @changedColor = true
    for i in 0...@PokemonOptions.length
      @sprites["option"][i] = (@PokemonOptions[i].get || 0)
    end
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Multiplayer Menu"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["textbox"].text = _INTL("Configure multiplayer settings")

    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def pbFadeInAndShow(sprites, visiblesprites = nil)
    return if !@changedColor
    super
  end

  def pbConnectWithStoredCredentials
    begin
      credentials = File.open("Multiplayer/credentials.json", "r") { |f| JSON.load(f) }
      if credentials && credentials["host"] && credentials["port"] && credentials["password"]
        begin
          ConnectionHandler.bind(
            credentials["host"],
            credentials["port"],
            credentials["password"]
          )
          MultiplayerLoader.enabled = true
          pbMessage(_INTL("Successfully connected to Redis!"))
          return true
        rescue => e
          pbMessage(_INTL("Connection failed: {1}", e.message))
        end
      else
        pbMessage(_INTL("Incomplete credentials in credentials.json"))
      end
    rescue Errno::ENOENT
      pbMessage(_INTL("No stored credentials found."))
    rescue JSON::ParserError
      pbMessage(_INTL("Invalid credentials.json format."))
    rescue => e
      pbMessage(_INTL("Error: {1}", e.message))
    end
    return false
  end

  def pbGetOptions(inloadscreen = false)
    options = []
    
    # Getting Started section
    options << ButtonOption.new(_INTL("Getting Started"),
      proc {
        pbFadeOutIn {
          scene = MultiplayerGuideScene.new
          screen = MultiplayerGuideScreen.new(scene)
          screen.pbStartScreen
        }
      }, "Learn how to set up multiplayer"
    )

    # Settings section
    options << ButtonOption.new(_INTL("Settings"),
      proc {
        @settings_menu = true
        openMultiplayerSettings()
      }, "Configure multiplayer settings"
    )

    # Connect UI section
    options << ButtonOption.new(_INTL("Connect UI"),
      proc {
        pbShowRedisConnectionUI
      }, "Open the Redis connection interface"
    )

    # Quick Connect/Disconnect
    connect_text = MultiplayerLoader.enabled? ? _INTL("Disconnect") : _INTL("Connect")
    connect_proc = proc {
      if MultiplayerLoader.enabled?
        MultiplayerLoader.enabled = false
        ConnectionHandler.connection&.quit rescue nil
        pbMessage(_INTL("Successfully disconnected from Redis!"))
        @scene&.pbEndScene if @scene
      else
        success = pbConnectWithStoredCredentials
        if success
          @scene&.pbEndScene if @scene
        end
      end
    }
    options << ButtonOption.new(connect_text, connect_proc,
      MultiplayerLoader.enabled? ? "Disconnect from multiplayer" : "Connect using stored credentials"
    )

    return options
  end

  def openMultiplayerSettings
    return if !@settings_menu
    pbFadeOutIn {
      scene = MultiplayerSettingsScene.new
      screen = PokemonOptionScreen.new(scene)
      screen.pbStartScreen
    }
    @settings_menu = false
  end

  def pbEndScene
    super
    # Only dispose if we're not in a submenu
    if !@settings_menu
      pbDisposeSpriteHash(@sprites)
      @viewport.dispose
    end
  end
end

# Multiplayer settings scene class
class MultiplayerSettingsScene < PokemonOption_Scene
  def initialize
    @changedColor = false
  end

  def pbStartScene(inloadscreen = false)
    super
    @sprites["option"].nameBaseColor = Color.new(35, 200, 35)  # Green theme
    @sprites["option"].nameShadowColor = Color.new(20, 115, 20)
    @changedColor = true
    for i in 0...@PokemonOptions.length
      @sprites["option"][i] = (@PokemonOptions[i].get || 0)
    end
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Multiplayer Settings"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["textbox"].text = _INTL("Configure multiplayer settings")

    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def pbFadeInAndShow(sprites, visiblesprites = nil)
    return if !@changedColor
    super
  end

  def pbGetOptions(inloadscreen = false)
    options = []
    
    # Show connection indicator option
    options << EnumOption.new(_INTL("Connection Indicator"), [_INTL("Show"), _INTL("Hide")],
      proc { $PokemonSystem.mp_show_indicator },
      proc { |value| $PokemonSystem.mp_show_indicator = value },
      "Show or hide the multiplayer connection indicator"
    )

    # Add more multiplayer settings here as needed

    return options
  end
end

# Connection indicator overlay
class ConnectionIndicatorSprite < Sprite
  def initialize(viewport=nil)
    super(viewport)
    @indicator = Bitmap.new(32, 32)
    self.bitmap = @indicator
    self.x = 16
    self.y = 16
    self.z = 99999
    @opacity_delta = 2 # Speed of opacity change
    @opacity_increasing = true
    refresh
  end

  def dispose
    @indicator.dispose
    super
  end

  def refresh
    @indicator.clear
    if $PokemonSystem.respond_to?(:mp_show_indicator) && 
       $PokemonSystem.mp_show_indicator == 0 &&
       MultiplayerLoader.enabled?
      @indicator.blt(0, 0, RPG::Cache.picture("recording-multiplayer"), Rect.new(0, 0, 32, 32))
      self.visible = true
      
      # Handle opacity animation
      if @opacity_increasing
        self.opacity += @opacity_delta
        @opacity_increasing = false if self.opacity >= 255
      else
        self.opacity -= @opacity_delta
        @opacity_increasing = true if self.opacity <= 0
      end
    else
      self.visible = false
    end
  end
end

# Add connection indicator to the spriteset
class Spriteset_Map
  alias multiplayer_initialize initialize
  def initialize(map=nil)
    multiplayer_initialize(map)
    @connection_indicator = ConnectionIndicatorSprite.new(@viewport1)
  end

  alias multiplayer_dispose dispose
  def dispose
    @connection_indicator.dispose if @connection_indicator
    multiplayer_dispose
  end

  alias multiplayer_update update
  def update
    multiplayer_update
    @connection_indicator.refresh if @connection_indicator
  end
end