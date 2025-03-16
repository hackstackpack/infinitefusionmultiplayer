class ConnectionHandler
  @@connection = nil

  def self.bind(host=nil, port=nil, password=nil)
    if host.nil? && port.nil? && password.nil?
      begin
        script_path = File.expand_path(__FILE__)
        game_folder = File.expand_path(File.join(script_path, '..'))
        credentials_path = File.join(game_folder, 'Multiplayer', 'credentials.json')
        File.open(credentials_path, 'r') do |file|
          contents = JSON.parse(file.read)
          host = contents['host']
          port = contents['port']
          password = contents['password']
        end
      rescue Exception => e
        raise "[IFM] - An error has occured while trying to get database info.\nMake sure all details are placed correctly"
      end
    end

    begin
      @@connection = Redis.new(host: host, port: port, password: password)
    rescue Exception => e
      raise "Database credentials are not valid, #{e}"
    end
    @@connection
  end

  def self.subscribe()
    sub_cnt = 0

    subscribe_thread = Thread.new do
      @@connection.subscribe('location', 'gifts') do |on|
        on.subscribe { sub_cnt += 1 }
        on.message do |channel, msg|
          begin
            data = JSON.parse(msg)
            case channel
            when 'location' then Invoker.populate('move_packet', data)
              # Running this from a thread causes Segmentation Fault, 
              # data is being sent to an event which is always listening and executing from a safe place.
            when 'gifts' then Invoker.populate('gift_packet', data)
            end
          rescue Exception => e
            puts "[IFM] - WARNING: Malformed message was sent."
          end
        end
      end
    end

    Thread.pass until sub_cnt == 2
    subscribe_thread
  end

  def self.publish(channel, message)
    return false if @@connection.nil?
    @@connection.publish(channel, message)
    true
  end

  def self.connection
    @@connection
  end

  def self.handle_gift(data)
    data.each do |player_ids, gifted_data|
      receiver, sender = player_ids.split('_')
      break if receiver.to_s != $Trainer.id.to_s
      
      pkmn = Pokemon.new(:BULBASAUR, 1)
      pkmn.load_json(eval(gifted_data))

      storedPlace = nil
      unless $Trainer.party_full?
        puts "[IFM] - Party not full, placing pokemon..."
        $Trainer.party[$Trainer.party.length] = pkmn
        storedPlace = "Party"
      else
        puts "[IFM] - Placing pokemon in pc since party is full..."
        $PokemonStorage.pbStoreCaught(pkmn)
        storedPlace = "PC"
      end

      Invoker.populate('msgBox', "#{sender} sent you his #{pkmn.name}!, it's waiting for you in your #{storedPlace}.")
    end
  end

  def self.handle_location(data)
    begin
      return if (data == nil) || (data["player_id"] == $Trainer.id)

      player_id = data["player_id"]

      if data["map_id"] == $game_map.map_id

        if data["x"] == -1 and data["y"] == -1
          puts "[IFM] - player #{player_id} moved into another map, deleting event..."
          ev = Ifm_Event.get_event(player_id)
          ev.delete

        elsif ev = Ifm_Event.get_event(player_id)

          if ev.graphics != data["graphic"]
            ev.refresh_graphics(data["graphic"])
            #Refresh player graphic
          end
          
          old_thr = ev.walk_thread
          if !old_thr.nil? && old_thr.alive?
            old_thr.kill
          end

          walkThread = Thread.new do
            ev.walkto(data["x"], data["y"], data["graphic"]["action"]); sleep 0.2 until [ev.event.x, ev.event.y] == [data["x"], data["y"]]
            ev.rotate(data["direction"])
          end

          ev.walk_thread = walkThread

        else
          # New player -> create a new event

          ev = Ifm_Event.new(player_id, data["graphic"], data["x"], data["y"])
          ev.rotate(data["direction"])

          puts "[IFM] - created event for player #{player_id}"
          # send my location
          ConnectionHandler.publish('location', ThisPlayer.generate_player_data)
        end
      end
    rescue Exception => e
      puts "[IFM] - An error has occured! #{e}"
    end
  end

end

def handle_location(data)
  ConnectionHandler.handle_location(data)
end

def handle_gift(data)
  ConnectionHandler.handle_gift(data)
end

Invoker.add_type('move_packet', :handle_location)
Invoker.add_type('gift_packet', :handle_gift)