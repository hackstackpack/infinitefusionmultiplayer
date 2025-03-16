class RedisConnectionUI
  FADE_SPEED = 8 # Match other UI components fade speed

  def initialize(is_connected = false)
    @disposed = false
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @is_connected = is_connected
    @sprites = {}
    create_background
    create_ui_elements
    load_default_credentials
    @current_selection = 0  # 0 = host, 1 = port, 2 = password, 3 = connect/disconnect
    # Fade in more slowly
    16.times do
      @viewport.color.alpha -= 16
      Graphics.update
    end
  end

  def disposed?
    return @disposed
  end

  def create_background
    @viewport.color = Color.new(0, 0, 0, 255)
    # Add background image
    @sprites["background"] = IconSprite.new(0, 0, @viewport)
    @sprites["background"].setBitmap("Graphics/Pictures/loadbg")
    @sprites["background"].opacity = 255
    
    # Add darkening overlay
    @overlay = ColoredPlane.new(Color.new(0, 0, 0, 120), @viewport)
  end

  def create_ui_elements
    # Title
    @sprites["title"] = Window_UnformattedTextPokemon.new(_INTL("Redis Connection"))
    @sprites["title"].x = (Graphics.width - @sprites["title"].width) / 2
    @sprites["title"].y = 10
    @sprites["title"].viewport = @viewport
    
    # Host input
    @sprites["host_label"] = Window_UnformattedTextPokemon.new(_INTL("Host:"))
    @sprites["host_label"].x = 50
    @sprites["host_label"].y = 80
    @sprites["host_label"].viewport = @viewport
    
    @sprites["host_input"] = Window_UnformattedTextPokemon.new("")
    @sprites["host_input"].x = Graphics.width / 2 - 50
    @sprites["host_input"].y = 80
    @sprites["host_input"].width = 320
    @sprites["host_input"].viewport = @viewport
    
    # Port input
    @sprites["port_label"] = Window_UnformattedTextPokemon.new(_INTL("Port:"))
    @sprites["port_label"].x = 50
    @sprites["port_label"].y = 130
    @sprites["port_label"].viewport = @viewport
    
    @sprites["port_input"] = Window_UnformattedTextPokemon.new("")
    @sprites["port_input"].x = Graphics.width / 2 - 50
    @sprites["port_input"].y = 130
    @sprites["port_input"].width = 100
    @sprites["port_input"].viewport = @viewport
    
    # Password input
    @sprites["password_label"] = Window_UnformattedTextPokemon.new(_INTL("Password:"))
    @sprites["password_label"].x = 50
    @sprites["password_label"].y = 180
    @sprites["password_label"].viewport = @viewport
    
    @sprites["password_input"] = Window_UnformattedTextPokemon.new("")
    @sprites["password_input"].x = Graphics.width / 2 - 50
    @sprites["password_input"].y = 180
    @sprites["password_input"].width = 320
    @sprites["password_input"].viewport = @viewport
    @password = ""  # Store actual password
    
    # Connect/Disconnect button
    button_text = @is_connected ? _INTL("Disconnect") : _INTL("Test Connection")
    @sprites["connect_btn"] = Window_CommandPokemon.new([button_text])
    @sprites["connect_btn"].x = (Graphics.width - @sprites["connect_btn"].width) / 2
    @sprites["connect_btn"].y = Graphics.height - 100
    @sprites["connect_btn"].viewport = @viewport

    # Selection highlight
    @sprites["sel"] = Sprite.new(@viewport)
    @sprites["sel"].bitmap = Bitmap.new(Graphics.width, 64)
    @sprites["sel"].bitmap.fill_rect(0, 0, Graphics.width, 64, Color.new(255, 255, 255, 64))
    @sprites["sel"].visible = true
    @sprites["sel"].z = 99998
    @sprites["sel"].opacity = 0
    update_selection
  end

  def update_selection
    return if disposed?
    # Reset all window colors
    @sprites["host_input"].opacity = 255
    @sprites["port_input"].opacity = 255
    @sprites["password_input"].opacity = 255
    @sprites["connect_btn"].index = -1

    # Update selection highlight position
    case @current_selection
    when 0  # Host
      @sprites["sel"].y = @sprites["host_input"].y
      @sprites["host_input"].opacity = 200
    when 1  # Port
      @sprites["sel"].y = @sprites["port_input"].y
      @sprites["port_input"].opacity = 200
    when 2  # Password
      @sprites["sel"].y = @sprites["password_input"].y
      @sprites["password_input"].opacity = 200
    when 3  # Connect/Disconnect button
      @sprites["sel"].y = @sprites["connect_btn"].y
      @sprites["connect_btn"].index = 0
    end
  end

  def mask_password(password)
    return "" if password.nil? || password.empty?
    return "*" * password.length
  end

  def load_default_credentials
    return if disposed?
    begin
      credentials = File.read("Multiplayer/credentials.json")
      data = JSON.parse(credentials)
      @sprites["host_input"].text = data["host"].to_s
      @sprites["port_input"].text = data["port"].to_s
      @password = data["password"].to_s
      @sprites["password_input"].text = mask_password(@password)
    rescue
      # If file doesn't exist or is invalid, use default values
      @sprites["host_input"].text = "localhost"
      @sprites["port_input"].text = "6379"
      @password = ""
      @sprites["password_input"].text = ""
    end
  end

  def save_credentials
    data = {
      "host" => @sprites["host_input"].text,
      "port" => @sprites["port_input"].text.to_i,
      "password" => @password
    }
    File.write("Multiplayer/credentials.json", JSON.pretty_generate(data))
  end

  def validate_port(port_str)
    return false if port_str.empty?
    # Check if string contains only numbers
    return false unless port_str =~ /^\d+$/
    # Convert to integer and check range
    port = port_str.to_i
    return port >= 1 && port <= 65535
  end

  def fade_out
    return if disposed?
    # Fade out more slowly
    16.times do
      @viewport.color.alpha += 16
      Graphics.update
    end
  end

  def test_connection
    return false if disposed?
    begin
      # Validate port first
      unless validate_port(@sprites["port_input"].text)
        pbMessage(_INTL("Invalid port number. Port must be between 1 and 65535."))
        return false
      end

      # Try to establish connection
      connection = ConnectionHandler.bind(
        @sprites["host_input"].text,
        @sprites["port_input"].text.to_i,
        @password
      )

      # Test the connection with a simple PING
      begin
        connection.ping
      rescue => e
        connection&.quit rescue nil
        pbMessage(_INTL("Connection failed: Unable to ping Redis server."))
        return false
      end

      # If we got here, connection was successful
      connection&.quit rescue nil
      
      # Save credentials
      File.open("Multiplayer/credentials.json", "w") do |f|
        JSON.dump({
          "host" => @sprites["host_input"].text,
          "port" => @sprites["port_input"].text.to_i,
          "password" => @password
        }, f)
      end
      
      pbMessage(_INTL("Connection test successful! Credentials saved."))
      fade_out
      dispose
      return true
    rescue Redis::CannotConnectError, RedisClient::CannotConnectError => e
      pbMessage(_INTL("Connection failed: Could not connect to Redis server."))
      return false
    rescue Redis::ConnectionError => e
      pbMessage(_INTL("Connection failed: {1}", e.message))
      return false
    rescue => e
      pbMessage(_INTL("Connection failed: {1}", e.message))
      return false
    end
  end

  def handle_input
    return false if disposed?
    if Input.trigger?(Input::USE)
      case @current_selection
      when 0  # Host
        @sprites["host_input"].text = pbEnterText(_INTL("Enter host:"), 0, 50, @sprites["host_input"].text || "")
      when 1  # Port
        @sprites["port_input"].text = pbEnterText(_INTL("Enter port:"), 0, 10, @sprites["port_input"].text || "")
      when 2  # Password
        @password = pbEnterText(_INTL("Enter password:"), 0, 50, @password || "")
        @sprites["password_input"].text = mask_password(@password)
      when 3  # Connect/Disconnect button
        test_connection
      end
    elsif Input.trigger?(Input::BACK)
      pbPlayCancelSE
      fade_out
      dispose
      return false
    elsif Input.trigger?(Input::UP)
      pbPlayCursorSE
      @current_selection -= 1
      @current_selection = 3 if @current_selection < 0
      update_selection
    elsif Input.trigger?(Input::DOWN)
      pbPlayCursorSE
      @current_selection += 1
      @current_selection = 0 if @current_selection > 3
      update_selection
    end
    return nil
  end

  def update
    return false if disposed?
    pbUpdateSpriteHash(@sprites)
    
    if Input.trigger?(Input::B)
      fade_out
      dispose
      return false
    end
    
    return handle_input
  end

  def dispose
    return if disposed?
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
    @disposed = true
  end
end

def pbShowRedisConnectionUI
  ret = false
  ui = RedisConnectionUI.new(MultiplayerLoader.enabled?)
  loop do
    Graphics.update
    Input.update
    result = ui.update
    if !result.nil?
      ret = result
      break
    end
  end
  return ret
end