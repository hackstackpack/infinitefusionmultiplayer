class Ifm_Event
  # {player_id: class instance} 
  @@instances = {}
  @@events_map = 0

  attr_accessor :walk_thread
  attr_reader :map_id
  attr_reader :graphics
  attr_reader :event

  # @param player: int
  # @param graphics: {}
  def initialize(player_id, graphics, x=-1, y=-1)
      unless @@instances.key?(player_id)
          rf_event = EventManager.create_event(
            "Multiplayer_#{player_id}",
            # ^^ not a valid file name, but inside '003_Sprite_Character.rb' (the file that handles creating the bitmap for the event)
            #   we added custom functionality that generated a new bitmap for the given event.
            x, y, nil,
            # passing location & map_id as $game_map.map_id
            "ifmClient_#{player_id}",
            # event name, not really used anywhere but here for more clarity
            player_id,
            "PlayerInterractMenu.call(#{player_id})",
            # passing the script that will get invoked upon interraction.
            false
          )
          @event = rf_event
          @player_id = player_id
          @graphics = graphics
          @map_id = $game_map.map_id
          @walk_thread = nil
      else
          # if @@instances[player_id].map_id == $game_map.map_id
          raise "[IFM] - tried initializing an already existing event"
          nil
      end
      @@instances[player_id] = self
      @@events_map = $game_map.map_id
  end

  def self.get_event(player_id)
    if @@instances.key?(player_id)
      return @@instances[player_id]
    end
    nil
  end

  # Deletes all *references* to events (for wiping out events from old maps)
  def self.cleanEventList
    @@instances.each do |player_id, _|
      @@instances.delete(player_id)
    end
  end

  def self.mapChangeThread
    map_id = $game_map.map_id
    thread = Thread.new do
      while true
        if map_id != $game_map.map_id
          cleanEventList
          last_msg = ThisPlayer.generate_player_data_hash
          last_msg.merge!({ x: -1, y: -1, map_id: map_id })
          ConnectionHandler.publish('location', JSON.dump(last_msg))
          map_id = $game_map.map_id
        end
        sleep 0.2
      end
    end
    thread
  end

  def self.delete_all
    @@instances.each do |player_id, event|
      Rf.delete_event(event.event, $game_map.map_id)
      @@instances.delete(player_id)
    end
  end

  def refresh_graphics(new_graphics = nil)
      new_graphics ||= @graphics
      @graphics = new_graphics
      @event.character_name = "Multiplayer_#{@player_id}_#{rand(1000..9999)}"
  end

  def walkto(x, y, state = "walk", direction = 2)
      # If we're already moving to a position, force complete that movement first
      if @walk_thread && @walk_thread.alive?
        old_dest = @walk_thread[:destination]
        if old_dest
          @event.moveto(old_dest[:x], old_dest[:y])
          rotate(old_dest[:direction])
        end
        @walk_thread.kill
      end

      # Create new thread to track the movement
      @walk_thread = Thread.new do
        Thread.current[:destination] = { x: x, y: y, direction: direction }
        # Execute movement on main thread
        EventManager.walkto(@event, x, y, state, direction)
        # Keep thread alive until movement completes
        sleep 0.1 while @event.moving?
        # Thread will naturally end when movement is done
      end
  end

  def rotate(direction)
      EventManager.rotate_direction(@event, direction)
  end

  def delete
      Rf.delete_event(@event, @map_id)
      @@instances.delete(@player_id)
  end
end